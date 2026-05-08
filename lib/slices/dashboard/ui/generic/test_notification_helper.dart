import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show
        AndroidScheduleMode,
        DarwinNotificationDetails,
        FlutterLocalNotificationsPlugin,
        NotificationDetails;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules a local notification to fire in 15 seconds with a fake payload.
///
/// Background the app after calling this, wait 15 s, then tap the notification
/// — the console should show `[Notif]` log lines and the showup detail screen
/// should open (showing "showup not found" because the ID is fake, but that
/// confirms the full navigation stack is wired correctly).
///
/// **Important:** do NOT call [FlutterLocalNotificationsPlugin.initialize] here.
/// The plugin is a singleton and re-initialising it overwrites the response
/// callback that [main.dart] registered, silently breaking notification tap
/// navigation for the rest of the session.
///
/// Only referenced from debug/profile-mode UI — not compiled into release
/// builds via tree-shaking once the call sites are guarded by [kDebugMode] /
/// [kProfileMode].
Future<void> scheduleTestNotification() async {
  // timezone is initialised by FlutterLocalNotificationService.initialize() at
  // app start. Re-initialise here as a safety net in case it hasn't run yet.
  try {
    tz_data.initializeTimeZones();
    final localTzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTzName));
  } catch (e) {
    debugPrint('[TestNotif] timezone init failed: $e');
  }

  try {
    final fireAt = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 15));
    debugPrint('[TestNotif] scheduling for $fireAt');
    await FlutterLocalNotificationsPlugin().zonedSchedule(
      9999,
      '🔔 Test notification',
      'Tap me — navigation should open showup detail',
      fireAt,
      const NotificationDetails(iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode({'showupId': 'test-showup-id', 'pactId': 'test-pact-id'}),
    );
    debugPrint('[TestNotif] scheduled successfully — background the app and tap the banner in 15 s');
  } catch (e) {
    debugPrint('[TestNotif] scheduling FAILED: $e');
  }
}
