import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Android notification channel ID for showup reminders.
const _kChannelId = 'showup_reminders';

/// Android notification channel display name.
const _kChannelName = 'Showup reminders';

/// Production [NotificationService] backed by [FlutterLocalNotificationsPlugin].
///
/// Schedule notifications using [zonedSchedule] with [TZDateTime] to ensure
/// correct DST-safe scheduling. Both the reminder (at `scheduledAt - reminderOffset`)
/// and the replacement deadline notification (at `scheduledAt + duration`) share
/// the same integer notification ID, derived from:
/// ```
/// showup.scheduledAt.millisecondsSinceEpoch ~/ 1000
/// ```
/// This makes the ID deterministic and fits within a 32-bit integer.
///
/// An in-memory `_pactNotificationIds` registry maps pact ID → set of
/// notification IDs so [cancelAllRemindersForPact] can cancel all pending
/// notifications for a stopped pact without iterating the OS-managed list.
/// On app restart the registry is empty; cancellation falls back to fetching
/// pending notifications and filtering by the `pactId` in their payload JSON.
///
/// **No-throw contract:** all methods are wrapped in try/catch. Failures are
/// logged via [debugPrint] in debug mode and silently swallowed in release.
final class FlutterLocalNotificationService implements NotificationService {
  FlutterLocalNotificationService();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// In-memory registry: pact ID → set of notification IDs.
  ///
  /// Populated on [scheduleShowupReminder] and [scheduleDeadlineNotification].
  /// Cleared on cancellation. Not persisted — rebuilt via [getPendingNotifications]
  /// after an app restart if needed.
  final Map<String, Set<int>> _pactNotificationIds = {};

  /// Callback invoked when the user taps a notification or an action button.
  ///
  /// WU4 wires this to the navigator for deep-link routing.
  // ignore: unused_field
  void Function(NotificationResponse)? _onDidReceiveNotificationResponse;

  @override
  Future<void> initialize() async {
    try {
      // Initialise timezone database (loads all IANA timezone data into memory).
      tz_data.initializeTimeZones();
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

      _onDidReceiveNotificationResponse = (NotificationResponse response) {
        // WU4 will wire this to the navigator.
        debugPrint('[Notifications] response received: ${response.payload}');
      };

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );

      // Create Android notification channel.
      const androidChannel = AndroidNotificationChannel(
        _kChannelId,
        _kChannelName,
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    } catch (e) {
      debugPrint('[Notifications] initialize() failed: $e');
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
    } catch (e) {
      debugPrint('[Notifications] requestPermission() failed: $e');
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
      final notifId = _notificationId(showup.scheduledAt);
      final fireAt = showup.scheduledAt.subtract(pact.reminderOffset!);
      final tzFireAt = tz.TZDateTime.from(fireAt, tz.local);

      final payload = jsonEncode({'showupId': showup.id, 'pactId': pact.id});

      await _plugin.zonedSchedule(
        notifId,
        titleText,
        bodyText,
        tzFireAt,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId,
            _kChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      _registerNotificationId(pact.id, notifId);
    } catch (e) {
      debugPrint('[Notifications] scheduleShowupReminder() failed: $e');
    }
  }

  @override
  Future<void> scheduleDeadlineNotification({
    required Showup showup,
    required String titleText,
    required String bodyText,
  }) async {
    try {
      final notifId = _notificationId(showup.scheduledAt);
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      _registerNotificationId(showup.pactId, notifId);
    } catch (e) {
      debugPrint('[Notifications] scheduleDeadlineNotification() failed: $e');
    }
  }

  @override
  Future<void> cancelShowupReminder(String showupId, DateTime scheduledAt) async {
    try {
      final notifId = _notificationId(scheduledAt);
      await _plugin.cancel(notifId);
      // Remove from all pact registries (we don't know the pactId here).
      for (final ids in _pactNotificationIds.values) {
        ids.remove(notifId);
      }
    } catch (e) {
      debugPrint('[Notifications] cancelShowupReminder() failed: $e');
    }
  }

  @override
  Future<void> cancelAllRemindersForPact(String pactId) async {
    try {
      final idsFromRegistry = _pactNotificationIds[pactId];
      if (idsFromRegistry != null && idsFromRegistry.isNotEmpty) {
        // Use the in-memory registry (fast path — no OS call needed).
        for (final id in idsFromRegistry) {
          await _plugin.cancel(id);
        }
        _pactNotificationIds.remove(pactId);
        return;
      }

      // Fallback: query OS pending notifications and filter by pactId in payload.
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
    } catch (e) {
      debugPrint('[Notifications] cancelAllRemindersForPact() failed: $e');
    }
  }

  @override
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('[Notifications] getPendingNotifications() failed: $e');
      return const [];
    }
  }

  @override
  Future<NotificationAppLaunchDetails?> getAppLaunchDetails() async {
    try {
      return await _plugin.getNotificationAppLaunchDetails();
    } catch (e) {
      debugPrint('[Notifications] getAppLaunchDetails() failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Derives a deterministic 32-bit notification ID from a [DateTime].
  ///
  /// Divides epoch milliseconds by 1000 to fit within a 32-bit signed integer
  /// (safe until year 2038 for timestamps within normal pact durations).
  int _notificationId(DateTime scheduledAt) => scheduledAt.millisecondsSinceEpoch ~/ 1000;

  void _registerNotificationId(String pactId, int notifId) {
    _pactNotificationIds.putIfAbsent(pactId, () => {}).add(notifId);
  }
}
