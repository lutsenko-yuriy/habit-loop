import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/onboarding/data/shared_preferences_onboarding_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPreferencesOnboardingService', () {
    setUp(() {
      // Start each test with an empty SharedPreferences store.
      SharedPreferences.setMockInitialValues({});
    });

    test('isOnboardingPassed returns false when key is absent (fresh install)', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesOnboardingService(prefs);

      expect(service.isOnboardingPassed, isFalse);
    });

    test('isOnboardingPassed returns true when key is pre-set (returning user)', () async {
      SharedPreferences.setMockInitialValues({
        'habit_loop_onboarding_passed': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesOnboardingService(prefs);

      expect(service.isOnboardingPassed, isTrue);
    });

    test('markOnboardingPassed writes the flag; isOnboardingPassed returns true on the same instance', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesOnboardingService(prefs);

      expect(service.isOnboardingPassed, isFalse);
      await service.markOnboardingPassed();
      expect(service.isOnboardingPassed, isTrue);
    });

    test('markOnboardingPassed persists across a new instance using the same SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await SharedPreferencesOnboardingService(prefs).markOnboardingPassed();

      // Create a second instance wrapping the same prefs — simulates next launch
      // (SharedPreferences caches the singleton for the test).
      final service2 = SharedPreferencesOnboardingService(prefs);
      expect(service2.isOnboardingPassed, isTrue);
    });

    test('markOnboardingPassed is idempotent — calling twice does not throw', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesOnboardingService(prefs);

      await service.markOnboardingPassed();
      await service.markOnboardingPassed();

      expect(service.isOnboardingPassed, isTrue);
    });

    test('markOnboardingPassed never throws (no-throw contract)', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesOnboardingService(prefs);

      await expectLater(service.markOnboardingPassed(), completes);
    });
  });
}
