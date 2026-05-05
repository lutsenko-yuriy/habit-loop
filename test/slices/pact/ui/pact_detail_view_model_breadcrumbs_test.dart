import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/analytics/providers/analytics_providers.dart';
import 'package:habit_loop/infrastructure/crashlytics/providers/crashlytics_providers.dart';
import 'package:habit_loop/slices/pact/application/pact_service.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/crashlytics/fake_crashlytics_service.dart';

void main() {
  final today = DateTime(2026, 3, 29);

  Pact buildActivePact(String id) => Pact(
        id: id,
        habitName: 'Meditate',
        startDate: today,
        endDate: today.add(const Duration(days: 180)),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );

  ProviderContainer createContainer({
    required Pact pact,
    FakeCrashlyticsService? crashlytics,
  }) {
    final pactRepo = InMemoryPactRepository([pact]);
    final showupRepo = InMemoryShowupRepository();
    final service = PactService(
      pactRepository: pactRepo,
      showupRepository: showupRepo,
      transactionService: null,
    );
    final statsService = PactStatsService(
      pactRepository: pactRepo,
      showupRepository: showupRepo,
    );
    return ProviderContainer(
      overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        pactDetailNowProvider.overrideWithValue(today),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        if (crashlytics != null) crashlyticsServiceProvider.overrideWithValue(crashlytics),
      ],
    );
  }

  group('PactDetailViewModel breadcrumbs', () {
    test('load logs screen breadcrumb', () async {
      final crashlytics = FakeCrashlyticsService();
      final pact = buildActivePact('p1');
      final container = createContainer(pact: pact, crashlytics: crashlytics);

      await container.read(pactDetailViewModelProvider('p1').notifier).load();

      expect(
        crashlytics.logs.any((msg) => msg.contains('screen: pact_detail')),
        isTrue,
        reason: 'load() should log a screen breadcrumb',
      );
    });

    test('stopPact logs pact_stopped action breadcrumb', () async {
      final crashlytics = FakeCrashlyticsService();
      final pact = buildActivePact('p2');
      final container = createContainer(pact: pact, crashlytics: crashlytics);
      final notifier = container.read(pactDetailViewModelProvider('p2').notifier);
      await notifier.load();
      crashlytics.reset();

      await notifier.stopPact(null);

      expect(
        crashlytics.logs.any((msg) => msg.contains('pact_stopped')),
        isTrue,
        reason: 'stopPact() should log a pact_stopped breadcrumb',
      );
    });
  });
}
