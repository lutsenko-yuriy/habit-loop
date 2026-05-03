import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/crashlytics/providers/crashlytics_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';
import '../../../infrastructure/crashlytics/fake_crashlytics_service.dart';

void main() {
  final today = DateTime(2026, 3, 29);

  ProviderContainer createContainer({
    List<Pact> pacts = const [],
    FakeCrashlyticsService? crashlytics,
  }) {
    return ProviderContainer(
      overrides: [
        pactRepositoryProvider.overrideWithValue(InMemoryPactRepository(pacts)),
        showupRepositoryProvider.overrideWithValue(InMemoryShowupRepository()),
        todayProvider.overrideWithValue(today),
        if (crashlytics != null) crashlyticsServiceProvider.overrideWithValue(crashlytics),
      ],
    );
  }

  group('DashboardViewModel breadcrumbs', () {
    test('load sets active_pacts_count custom key', () async {
      final crashlytics = FakeCrashlyticsService();
      final container = createContainer(
        pacts: [
          Pact(
            id: 'p1',
            habitName: 'Meditate',
            startDate: today,
            endDate: today.add(const Duration(days: 180)),
            showupDuration: const Duration(minutes: 10),
            schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
            status: PactStatus.active,
          ),
        ],
        crashlytics: crashlytics,
      );

      await container.read(dashboardViewModelProvider.notifier).load();

      expect(
        crashlytics.customKeys.any((k) => k.key == 'active_pacts_count'),
        isTrue,
        reason: 'load() should call setCustomKey(active_pacts_count, ...)',
      );
    });

    test('load logs screen breadcrumb', () async {
      final crashlytics = FakeCrashlyticsService();
      final container = createContainer(crashlytics: crashlytics);

      await container.read(dashboardViewModelProvider.notifier).load();

      expect(
        crashlytics.logs.any((msg) => msg.contains('screen: dashboard')),
        isTrue,
        reason: 'load() should log a screen breadcrumb',
      );
    });
  });
}
