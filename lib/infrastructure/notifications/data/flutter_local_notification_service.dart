import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/infrastructure/crashlytics/contracts/crashlytics_service.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Android notification channel ID for showup reminders.
const _kChannelId = 'showup_reminders';

/// Android notification channel display name.
const _kChannelName = 'Showup reminders';

/// Upper bound for reminder notification IDs (exclusive), equal to
/// `2^31 - 1` — the maximum value for a 32-bit signed integer.
const _kReminderIdBound = 2147483647;

/// Upper bound for the modulo applied to deadline IDs before the offset.
/// Combined with [_kDeadlineIdOffset] the result is always within 32-bit
/// signed integer range: `[1073741824, 2147483646]`.
const _kDeadlineIdModBound = 1073741823;

/// Offset added to deadline IDs so they never collide with reminder IDs.
const _kDeadlineIdOffset = 1073741824;

/// Production [NotificationService] backed by [FlutterLocalNotificationsPlugin].
///
/// Schedule notifications using [zonedSchedule] with [TZDateTime] to ensure
/// correct DST-safe scheduling.
///
/// **Notification ID scheme** — each (showup, notificationType) pair gets a
/// unique deterministic 32-bit signed integer ID:
/// - Reminder ID: `showup.id.hashCode.abs() % 2147483647`
/// - Deadline ID: `(showup.id.hashCode.abs() % 1073741823) + 1073741824`
///
/// The two ranges are disjoint so reminder and deadline notifications can
/// coexist in the notification tray simultaneously. Using the showup UUID
/// as the hash source means two pacts that schedule showups at the same
/// clock second produce different IDs.
///
/// An in-memory `_pactNotificationIds` registry maps pact ID → set of
/// notification IDs so [cancelAllRemindersForPact] can cancel all pending
/// notifications for a stopped pact without iterating the OS-managed list.
/// On app restart the registry is empty; cancellation falls back to fetching
/// pending notifications and filtering by the `pactId` in their payload JSON.
///
/// **Android 14+ SCHEDULE_EXACT_ALARM** — on Android the implementation
/// checks `canScheduleExactNotifications()` during [initialize] and caches the
/// result in [_canScheduleExact]. If exact alarms are unavailable it falls back
/// to [AndroidScheduleMode.inexactAllowWhileIdle] so the notification is still
/// delivered (albeit within a short OS-determined window) rather than crashing.
///
/// **No-throw contract:** all methods are wrapped in try/catch. Failures are
/// recorded via [CrashlyticsService] in all builds.
final class FlutterLocalNotificationService implements NotificationService {
  FlutterLocalNotificationService(this._crashlytics);

  final CrashlyticsService _crashlytics;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Cached result of `canScheduleExactNotifications()` on Android.
  ///
  /// Set to `true` on iOS (exact alarms are always available) and resolved
  /// at runtime during [initialize] on Android.
  bool _canScheduleExact = true;

  /// In-memory registry: pact ID → set of notification IDs.
  ///
  /// Populated on [scheduleShowupReminder] and [scheduleDeadlineNotification].
  /// Cleared on cancellation. Not persisted — rebuilt via [getPendingNotifications]
  /// after an app restart if needed.
  final Map<String, Set<int>> _pactNotificationIds = {};

  /// Callback invoked when the user taps a notification or an action button.
  ///
  /// Set by calling [setNotificationResponseCallback] **before** [initialize],
  /// then forwarded to [FlutterLocalNotificationsPlugin.initialize].
  ///
  /// `main.dart` wires this to [NotificationRouter.navigateToShowup] for
  /// deep-link routing (WU4). When null, [initialize] falls back to a debug log.
  void Function(NotificationResponse)? _onDidReceiveNotificationResponse;

  /// Sets the callback that is forwarded to [FlutterLocalNotificationsPlugin.initialize].
  ///
  /// Must be called **before** [initialize]. The [FlutterLocalNotificationsPlugin]
  /// does not expose a way to replace the callback after initialisation, so
  /// main.dart must set this before awaiting [initialize].
  void setNotificationResponseCallback(void Function(NotificationResponse) callback) {
    _onDidReceiveNotificationResponse = callback;
  }

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

      // Use the externally-set callback (from main.dart for deep-link routing)
      // or fall back to a debug-only log for builds that do not wire navigation.
      _onDidReceiveNotificationResponse ??= (NotificationResponse response) {
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

      // Android 14+: resolve whether exact alarm permission has been granted.
      // On iOS _canScheduleExact stays true (no permission required).
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        _canScheduleExact = await android.canScheduleExactNotifications() ?? false;
      }
    } catch (e, s) {
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

  /// Reminder notification ID derived from the showup UUID.
  ///
  /// Range: `[0, 2147483646]` — fits within a 32-bit signed integer.
  int _reminderNotificationId(String showupId) => showupId.hashCode.abs() % _kReminderIdBound;

  /// Deadline notification ID derived from the showup UUID.
  ///
  /// Range: `[1073741824, 2147483646]` — disjoint from [_reminderNotificationId]
  /// so both notifications can coexist in the notification tray simultaneously.
  int _deadlineNotificationId(String showupId) => (showupId.hashCode.abs() % _kDeadlineIdModBound) + _kDeadlineIdOffset;

  void _registerNotificationId(String pactId, int notifId) {
    _pactNotificationIds.putIfAbsent(pactId, () => {}).add(notifId);
  }
}
