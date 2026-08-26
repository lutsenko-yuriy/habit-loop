import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/reminder/application/reminder_plan_context.dart';

import '../../../infrastructure/remote_config/fake_remote_config_service.dart';

void main() {
  group('ReminderPlanContext.resolve', () {
    test('isIOS=true always schedules the deadline regardless of RC behavior', () {
      final remoteConfig = FakeRemoteConfigService(overrides: {'post_deadline_notification_behavior': 'dismiss'});

      final context = ReminderPlanContext.resolve(remoteConfig: remoteConfig, isIOS: true);

      expect(context.scheduleDeadline, isTrue);
    });

    test('isIOS=false schedules the deadline only when RC behavior is encourage', () {
      final dismiss = FakeRemoteConfigService(overrides: {'post_deadline_notification_behavior': 'dismiss'});
      final encourage = FakeRemoteConfigService(overrides: {'post_deadline_notification_behavior': 'encourage'});

      expect(ReminderPlanContext.resolve(remoteConfig: dismiss, isIOS: false).scheduleDeadline, isFalse);
      expect(ReminderPlanContext.resolve(remoteConfig: encourage, isIOS: false).scheduleDeadline, isTrue);
    });

    test('clamps an out-of-range hurry_up_time_in_minutes (e.g. unset RC returns 0)', () {
      final remoteConfig = FakeRemoteConfigService(overrides: {'hurry_up_time_in_minutes': 0});

      final context = ReminderPlanContext.resolve(remoteConfig: remoteConfig, isIOS: false);

      expect(context.hurryUpTime, isNot(equals(Duration.zero)));
    });

    test('reads hurryUpEnabled and welcomeBackEnabled straight from remote config', () {
      final remoteConfig = FakeRemoteConfigService(overrides: {
        'hurry_up_notification_enabled': true,
        'break_welcome_back_notification_enabled': false,
      });

      final context = ReminderPlanContext.resolve(remoteConfig: remoteConfig, isIOS: false);

      expect(context.hurryUpEnabled, isTrue);
      expect(context.welcomeBackEnabled, isFalse);
    });

    test('reads the notification text variant straight from remote config', () {
      final remoteConfig = FakeRemoteConfigService(overrides: {'notification_text_variant': 'deadline'});

      final context = ReminderPlanContext.resolve(remoteConfig: remoteConfig, isIOS: false);

      expect(context.textVariant, equals('deadline'));
    });
  });
}
