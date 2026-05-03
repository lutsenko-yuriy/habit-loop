import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/crashlytics/providers/crashlytics_providers.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_view_model.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';
import '../../../infrastructure/crashlytics/fake_crashlytics_service.dart';

void main() {
  final today = DateTime(2026, 3, 29);

  ProviderContainer createContainer({FakeCrashlyticsService? crashlytics}) {
    return ProviderContainer(
      overrides: [
        pactCreationTodayProvider.overrideWithValue(today),
        pactCreationRepositoryProvider.overrideWithValue(InMemoryPactRepository()),
        pactCreationShowupRepositoryProvider.overrideWithValue(InMemoryShowupRepository()),
        if (crashlytics != null) crashlyticsServiceProvider.overrideWithValue(crashlytics),
      ],
    );
  }

  group('PactCreationViewModel breadcrumbs', () {
    test('submit logs pact_creation action breadcrumb', () async {
      final crashlytics = FakeCrashlyticsService();
      final container = createContainer(crashlytics: crashlytics);
      final vm = container.read(pactCreationViewModelProvider.notifier);

      // Set up a complete pact
      vm.setCommitmentAccepted(true);
      vm.setHabitName('Meditate');
      vm.setStartDate(today);
      vm.setEndDate(today.add(const Duration(days: 180)));
      vm.setShowupDuration(const Duration(minutes: 10));
      vm.setScheduleType(ScheduleType.daily);

      await vm.submit();

      expect(
        crashlytics.logs.any((msg) => msg.contains('pact_created')),
        isTrue,
        reason: 'submit() should log a pact_created breadcrumb on success',
      );
    });

    test('nextStep logs step transition breadcrumb', () async {
      final crashlytics = FakeCrashlyticsService();
      final container = createContainer(crashlytics: crashlytics);
      final vm = container.read(pactCreationViewModelProvider.notifier);

      vm.setCommitmentAccepted(true);
      vm.nextStep();

      expect(
        crashlytics.logs.any((msg) => msg.contains('pact_creation')),
        isTrue,
        reason: 'nextStep() should log a pact_creation step transition breadcrumb',
      );
    });
  });
}
