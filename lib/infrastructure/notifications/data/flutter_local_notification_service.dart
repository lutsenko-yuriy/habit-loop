import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/infrastructure/crashlytics/contracts/crashlytics_service.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_constants.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Android notification channel ID for showup reminders.
const _kChannelId = 'showup_reminders';

/// Android notification channel display name.
const _kChannelName = 'Showup reminders';

/// Production [NotificationService] backed by [FlutterLocalNotificationsPlugin].
///
/// Notification ID scheme (FNV-1a 32-bit, disjoint ranges):
/// - Reminder: `[0x0, 0x3FFFFFFF]`
/// - Deadline: `[0x40000000, 0x7FFFFFFE]`
///
/// `_pactNotificationIds` maps pact ID → notification IDs for fast cancellation.
/// On restart the registry is empty; fallback queries the OS-managed pending list.
///
/// Android 14+: `_canScheduleExact` is resolved during [initialize]; if exact
/// alarms are unavailable, falls back to inexact (notification still delivered).
///
/// No-throw contract: all methods catch and record via [CrashlyticsService].
final class FlutterLocalNotificationService implements NotificationService {
  FlutterLocalNotificationService(this._crashlytics);

  final CrashlyticsService _crashlytics;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  // `true` on iOS always; resolved during initialize() on Android 14+.
  bool _canScheduleExact = true;

  // Pact ID → notification IDs. Rebuilt from OS-pending list after a restart.
  final Map<String, Set<int>> _pactNotificationIds = {};

  // Must be called before initialize() — the plugin wires it during setup and
  // provides no way to replace it afterwards.
  void Function(NotificationResponse)? _onDidReceiveNotificationResponse;

  void setNotificationResponseCallback(void Function(NotificationResponse) callback) {
    _onDidReceiveNotificationResponse = callback;
  }

  @override
  Future<void> initialize() async {
    try {
      tz_data.initializeTimeZones();
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz.identifier));

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

      _onDidReceiveNotificationResponse ??= (NotificationResponse response) {
        debugPrint('[Notifications] response received: ${response.payload}');
      };

      debugPrint('[Notif] calling _plugin.initialize()...');
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );
      debugPrint('[Notif] _plugin.initialize() returned — callback wired');

      const androidChannel = AndroidNotificationChannel(
        _kChannelId,
        _kChannelName,
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // Android 14+: exact alarm permission may not be granted.
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        _canScheduleExact = await android.canScheduleExactNotifications() ?? false;
      }
    } catch (e, s) {
      debugPrint('[Notif] initialize() CAUGHT EXCEPTION: $e');
      await _crashlytics.recordError(e, s, information: ['NotificationService.initialize']);
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
      // Android handles permissions via the system channel — no explicit request needed.
      return true;
    } catch (e, s) {
      await _crashlytics.recordError(e, s, information: ['NotificationService.requestPermission']);
      return false;
    }
  }

  @override
  Future<void> scheduleShowupReminder({
    required Showup showup,
    required Pact pact,
    required String titleText,
    required String bodyText,
  }) async {
    if (pact.reminderOffset == null) return;
    try {
      final notifId = _reminderNotificationId(showup.id);
      final fireAt = showup.scheduledAt.subtract(pact.reminderOffset!);
      final tzFireAt = tz.TZDateTime.from(fireAt, tz.local);

      final payload = jsonEncode({'showupId': showup.id, 'pactId': pact.id});

      const androidDetails = AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();

      await _plugin.zonedSchedule(
        notifId,
        titleText,
        bodyText,
        tzFireAt,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode:
            _canScheduleExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );

      _registerNotificationId(pact.id, notifId);
    } catch (e, s) {
      await _crashlytics.recordError(e, s, information: ['NotificationService.scheduleShowupReminder']);
    }
  }

  @override
  Future<void> scheduleDeadlineNotification({
    required Showup showup,
    required String titleText,
    required String bodyText,
  }) async {
    try {
      final notifId = _deadlineNotificationId(showup.id);
      final fireAt = showup.scheduledAt.add(showup.duration);
      final tzFireAt = tz.TZDateTime.from(fireAt, tz.local);

      final payload = jsonEncode({'showupId': showup.id, 'pactId': showup.pactId});

      await _plugin.zonedSchedule(
        notifId,
        titleText,
        bodyText,
        tzFireAt,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId,
            _kChannelName,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode:
            _canScheduleExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );

      _registerNotificationId(showup.pactId, notifId);
    } catch (e, s) {
      await _crashlytics.recordError(e, s, information: ['NotificationService.scheduleDeadlineNotification']);
    }
  }

  @override
  Future<void> cancelShowupReminder(String showupId) async {
    try {
      final reminderId = _reminderNotificationId(showupId);
      final deadlineId = _deadlineNotificationId(showupId);
      await _plugin.cancel(reminderId);
      await _plugin.cancel(deadlineId);
      // Remove from all pact registries (we don't know the pactId here).
      for (final ids in _pactNotificationIds.values) {
        ids
          ..remove(reminderId)
          ..remove(deadlineId);
      }
    } catch (e, s) {
      await _crashlytics.recordError(e, s, information: ['NotificationService.cancelShowupReminder']);
    }
  }

  @override
  Future<void> cancelAllRemindersForPact(
    String pactId, {
    List<String> showupIds = const [],
  }) async {
    try {
      if (showupIds.isNotEmpty) {
        // Deterministic path: compute IDs from showup UUIDs directly.
        // Works even after a cold restart when the in-memory registry is empty,
        // and on iOS where pendingNotificationRequests() only returns notifications
        // scheduled in the current app session.
        for (final showupId in showupIds) {
          await _plugin.cancel(_reminderNotificationId(showupId));
          await _plugin.cancel(_deadlineNotificationId(showupId));
        }
        _pactNotificationIds.remove(pactId);
        return;
      }

      final idsFromRegistry = _pactNotificationIds[pactId];
      if (idsFromRegistry != null && idsFromRegistry.isNotEmpty) {
        for (final id in idsFromRegistry) {
          await _plugin.cancel(id);
        }
        _pactNotificationIds.remove(pactId);
        return;
      }

      // Last-resort fallback: query OS pending notifications and filter by pactId.
      // Unreliable on iOS for notifications scheduled in a previous session.
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        final payload = request.payload;
        if (payload == null) continue;
        try {
          final map = jsonDecode(payload) as Map<String, dynamic>;
          if (map['pactId'] == pactId) {
            await _plugin.cancel(request.id);
          }
        } catch (_) {
          // Malformed payload — skip.
        }
      }
    } catch (e, s) {
      await _crashlytics.recordError(e, s, information: ['NotificationService.cancelAllRemindersForPact']);
    }
  }

  @override
  Future<List<PendingNotificationInfo>> getPendingNotifications() async {
    try {
      final requests = await _plugin.pendingNotificationRequests();
      return requests
          .map((r) => PendingNotificationInfo(id: r.id, title: r.title, body: r.body, payload: r.payload))
          .toList();
    } catch (e, s) {
      await _crashlytics.recordError(e, s, information: ['NotificationService.getPendingNotifications']);
      return const [];
    }
  }

  @override
  Future<NotificationLaunchInfo?> getAppLaunchDetails() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null) return null;
      return NotificationLaunchInfo(
        didNotificationLaunchApp: details.didNotificationLaunchApp,
        payload: details.notificationResponse?.payload,
      );
    } catch (e, s) {
      await _crashlytics.recordError(e, s, information: ['NotificationService.getAppLaunchDetails']);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  int _reminderNotificationId(String showupId) => NotificationConstants.reminderNotificationId(showupId);
  int _deadlineNotificationId(String showupId) => NotificationConstants.deadlineNotificationId(showupId);

  void _registerNotificationId(String pactId, int notifId) {
    _pactNotificationIds.putIfAbsent(pactId, () => {}).add(notifId);
  }
}
