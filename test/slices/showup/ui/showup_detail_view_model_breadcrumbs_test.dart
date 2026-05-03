import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/analytics/providers/analytics_providers.dart';
import 'package:habit_loop/infrastructure/crashlytics/providers/crashlytics_providers.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/crashlytics/fake_crashlytics_service.dart';

void main() {
  // Set "today" to 9:00 AM so showups scheduled at 9:30 AM are still pending
  // (not auto-failed). We need the showup window to not have passed yet.
  final today = DateTime(2026, 3, 29, 9, 0);

  Pact buildPact(String id) => Pact(
        id: id,
        habitName: 'Meditate',
        startDate: DateTime(today.year, today.month, today.day),
        endDate: DateTime(today.year, today.month + 6, today.day),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 9, minutes: 30)),
        status: PactStatus.active,
      );

  // Scheduled at 9:30 AM with 10 min duration → window ends 9:40 AM.
  // With today = 9:00 AM, now < windowEnd so the showup stays pending.
  Showup buildShowup(String id, {required String pactId}) => Showup(
        id: id,
        pactId: pactId,
        scheduledAt: DateTime(today.year, today.month, today.day, 9, 30),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.pending,
      );

  ProviderContainer createContainer({
    required Pact pact,
    required Showup showup,
    FakeCrashlyticsService? crashlytics,
  }) {
    return ProviderContainer(
      overrides: [
        showupDetailPactRepositoryProvider.overrideWithValue(InMemoryPactRepository([pact])),
        showupDetailShowupRepositoryProvider.overrideWithValue(InMemoryShowupRepository([showup])),
        showupDetailNowProvider.overrideWithValue(today),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        if (crashlytics != null) crashlyticsServiceProvider.overrideWithValue(crashlytics),
      ],
    );
  }

  group('ShowupDetailViewModel breadcrumbs', () {
    test('load logs screen breadcrumb', () async {
      final crashlytics = FakeCrashlyticsService();
      final pact = buildPact('p1');
      final showup = buildShowup('s1', pactId: 'p1');
      final container = createContainer(pact: pact, showup: showup, crashlytics: crashlytics);

      await container.read(showupDetailViewModelProvider('s1').notifier).load();

      expect(
        crashlytics.logs.any((msg) => msg.contains('screen: showup_detail')),
        isTrue,
        reason: 'load() should log a screen breadcrumb',
      );
    });

    test('markDone logs action breadcrumb', () async {
      final crashlytics = FakeCrashlyticsService();
      final pact = buildPact('p2');
      final showup = buildShowup('s2', pactId: 'p2');
      final container = createContainer(pact: pact, showup: showup, crashlytics: crashlytics);
      final notifier = container.read(showupDetailViewModelProvider('s2').notifier);
      await notifier.load();
      crashlytics.reset();

      await notifier.markDone();

      expect(
        crashlytics.logs.any((msg) => msg.contains('mark_done')),
        isTrue,
        reason: 'markDone() should log an action breadcrumb',
      );
    });

    test('markFailed logs action breadcrumb', () async {
      final crashlytics = FakeCrashlyticsService();
      final pact = buildPact('p3');
      final showup = buildShowup('s3', pactId: 'p3');
      final container = createContainer(pact: pact, showup: showup, crashlytics: crashlytics);
      final notifier = container.read(showupDetailViewModelProvider('s3').notifier);
      await notifier.load();
      crashlytics.reset();

      await notifier.markFailed();

      expect(
        crashlytics.logs.any((msg) => msg.contains('mark_failed')),
        isTrue,
        reason: 'markFailed() should log an action breadcrumb',
      );
    });
  });
}
