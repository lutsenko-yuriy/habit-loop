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

/// Action ID for the "Mark done" notification action.
///
/// Used by both Android ([AndroidNotificationAction]) and iOS
/// ([DarwinNotificationAction]) to identify the action in the
/// [NotificationResponse.actionId] field.
///
/// Sourced from [NotificationConstants.markDoneActionId] — defined there as
/// the single canonical value shared with `main.dart` background handler.
const _kMarkDoneActionId = NotificationConstants.markDoneActionId;

/// iOS notification category ID for showup reminder notifications with a
/// "Mark done" action.
///
/// Registered once during [initialize]. All showup reminder notifications
/// reference this category so the OS attaches the action button automatically.
const _kShowupReminderCategoryId = 'showup_reminder';

/// Label for the "Mark done" action button.
///
/// **iOS limitation:** notification category action labels are registered once
/// at [initialize] time and cannot change per-notification. Using the English
/// label as a hardcoded constant is the standard practice for local
/// notifications on iOS. On Android the label is set at scheduling time and
/// could in principle use a locale-aware string, but we also use the English
/// constant here for simplicity and parity with iOS.
const _kMarkDoneActionLabel = 'Mark done';

/// Production [NotificationService] backed by [FlutterLocalNotificationsPlugin].
///
/// Schedule notifications using [zonedSchedule] with [TZDateTime] to ensure
/// correct DST-safe scheduling.
///
/// **Notification ID scheme** — each (showup, notificationType) pair gets a
/// unique deterministic 32-bit signed integer ID:
/// - Reminder ID: FNV-1a 32-bit hash of `showup.id` modulo `0x40000000`, range `[0x0, 0x3FFFFFFF]`
/// - Deadline ID: FNV-1a 32-bit hash of `showup.id` modulo `0x3FFFFFFF` plus `0x40000000`, range `[0x40000000, 0x7FFFFFFE]`
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

  /// Callback invoked when the user taps a notification or an action button
  /// while the app is in the foreground or warm-started from background.
  ///
  /// Set by calling [setNotificationResponseCallback] **before** [initialize],
  /// then forwarded to [FlutterLocalNotificationsPlugin.initialize].
  ///
  /// `main.dart` wires this to [NotificationRouter.navigateToShowup] for
  /// deep-link routing (WU4). When null, [initialize] falls back to a debug log.
  void Function(NotificationResponse)? _onDidReceiveNotificationResponse;

  /// Callback invoked on a **background isolate** (Android only) when the user
  /// acts on a notification action button while the app is not in the foreground.
  ///
  /// Set by calling [setBackgroundNotificationHandler] **before** [initialize].
  /// The function must be annotated with `@pragma('vm:entry-point')` — this is
  /// enforced at the call site in `main.dart`. When null, background actions
  /// are silently ignored.
  void Function(NotificationResponse)? _onDidReceiveBackgroundNotificationResponse;

  /// Sets the callback that is forwarded to [FlutterLocalNotificationsPlugin.initialize].
  ///
  /// Must be called **before** [initialize]. The [FlutterLocalNotificationsPlugin]
  /// does not expose a way to replace the callback after initialisation, so
  /// main.dart must set this before awaiting [initialize].
  void setNotificationResponseCallback(void Function(NotificationResponse) callback) {
    _onDidReceiveNotificationResponse = callback;
  }

  /// Sets the background handler that is forwarded to [FlutterLocalNotificationsPlugin.initialize].
  ///
  /// Must be called **before** [initialize]. The [callback] function must be a
  /// top-level function annotated with `@pragma('vm:entry-point')` — Android
  /// requires this for background isolate entry points.
  ///
  /// On iOS, notification action responses always use the
  /// [onDidReceiveNotificationResponse] path regardless of app state, so this
  /// callback is Android-specific.
  void setBackgroundNotificationHandler(void Function(NotificationResponse) callback) {
    _onDidReceiveBackgroundNotificationResponse = callback;
  }

  @override
  Future<void> initialize() async {
    try {
      // Initialise timezone database (loads all IANA timezone data into memory).
      tz_data.initializeTimeZones();
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz.identifier));

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      // Register the iOS notification category for showup reminders with the
      // "Mark done" action button. The label is hardcoded to the English string
      // because iOS category labels are fixed at registration time — they cannot
      // be localised per-notification. This is a known iOS platform limitation.
      //
      // DarwinNotificationAction.plain() is a non-const factory so the settings
      // object cannot be const. This is fine — it's only constructed once during
      // initialization.
      final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [
          DarwinNotificationCategory(
            _kShowupReminderCategoryId,
            actions: [
              DarwinNotificationAction.plain(
                _kMarkDoneActionId,
                _kMarkDoneActionLabel,
              ),
            ],
          ),
        ],
      );
      final initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

      // Use the externally-set callback (from main.dart for deep-link routing)
      // or fall back to a debug-only log for builds that do not wire navigation.
      _onDidReceiveNotificationResponse ??= (NotificationResponse response) {
        debugPrint('[Notifications] response received: ${response.payload}');
      };

      debugPrint('[Notif] calling _plugin.initialize()...');
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: _onDidReceiveBackgroundNotificationResponse,
      );
      debugPrint('[Notif] _plugin.initialize() returned — callback wired');

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
    bool includeMarkDoneAction = true,
  }) async {
    if (pact.reminderOffset == null) return;
    try {
      final notifId = _reminderNotificationId(showup.id);
      final fireAt = showup.scheduledAt.subtract(pact.reminderOffset!);
      final tzFireAt = tz.TZDateTime.from(fireAt, tz.local);

      final payload = jsonEncode({'showupId': showup.id, 'pactId': pact.id});

      // Build platform-specific notification details. When includeMarkDoneAction
      // is true, attach the "Mark done" action button so users can mark a showup
      // done directly from the notification tray without opening the app.
      // Deadline notifications must never include action buttons — the showup
      // window has passed, so marking done is no longer valid.
      final androidDetails = includeMarkDoneAction
          ? const AndroidNotificationDetails(
              _kChannelId,
              _kChannelName,
              importance: Importance.high,
              priority: Priority.high,
              actions: [
                AndroidNotificationAction(
                  _kMarkDoneActionId,
                  // Android supports per-notification labels; we still use the
                  // English constant for parity with iOS (see _kMarkDoneActionLabel).
                  _kMarkDoneActionLabel,
                  // Handle in background without launching the app UI.
                  showsUserInterface: false,
                ),
              ],
            )
          : const AndroidNotificationDetails(
              _kChannelId,
              _kChannelName,
              importance: Importance.high,
              priority: Priority.high,
            );

      // iOS: reference the registered category so the "Mark done" action button
      // is attached automatically. When includeMarkDoneAction is false, omit the
      // category identifier so no action buttons appear.
      final iosDetails = includeMarkDoneAction
          ? const DarwinNotificationDetails(categoryIdentifier: _kShowupReminderCategoryId)
          : const DarwinNotificationDetails();

      await _plugin.zonedSchedule(
        notifId,
        titleText,
        bodyText,
        tzFireAt,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
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

  /// Reminder notification ID derived from the showup UUID.
  ///
  /// Delegates to [NotificationConstants.reminderNotificationId] — the single
  /// canonical formula shared with `main.dart` background/foreground handlers.
  int _reminderNotificationId(String showupId) => NotificationConstants.reminderNotificationId(showupId);

  /// Deadline notification ID derived from the showup UUID.
  ///
  /// Delegates to [NotificationConstants.deadlineNotificationId] — the single
  /// canonical formula shared with `main.dart` background/foreground handlers.
  int _deadlineNotificationId(String showupId) => NotificationConstants.deadlineNotificationId(showupId);

  void _registerNotificationId(String pactId, int notifId) {
    _pactNotificationIds.putIfAbsent(pactId, () => {}).add(notifId);
  }
}
