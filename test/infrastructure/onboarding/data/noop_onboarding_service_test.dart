import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/onboarding/data/noop_onboarding_service.dart';

void main() {
  group('NoopOnboardingService', () {
    test('isOnboardingPassed always returns false', () {
      const service = NoopOnboardingService();
      expect(service.isOnboardingPassed, isFalse);
    });

    test('isOnboardingPassed returns false even after markOnboardingPassed is called', () async {
      const service = NoopOnboardingService();
      await service.markOnboardingPassed();
      expect(service.isOnboardingPassed, isFalse);
    });

    test('markOnboardingPassed never throws', () async {
      await expectLater(const NoopOnboardingService().markOnboardingPassed(), completes);
    });

    test('repeated markOnboardingPassed calls never throw', () async {
      const service = NoopOnboardingService();
      await service.markOnboardingPassed();
      await service.markOnboardingPassed();
      // No assertion needed — must not throw.
    });
  });
}
