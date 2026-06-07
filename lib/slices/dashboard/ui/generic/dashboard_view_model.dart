import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_refresh_signal.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_state.dart';
import 'package:habit_loop/slices/showup/analytics/showup_analytics_events.dart';

final todayProvider = Provider<DateTime>((ref) => DateTime.now());

final dashboardViewModelProvider = NotifierProvider<DashboardViewModel, DashboardState>(
  DashboardViewModel.new,
);

final hasActivePactsProvider = FutureProvider<bool>((ref) async {
  return ref.watch(pactListQueryServiceProvider).hasActivePacts();
});

class DashboardViewModel extends Notifier<DashboardState> {
  // Guards against overlapping loads that would run the auto-fail sweep twice.
  bool _loadInProgress = false;

  @override
  DashboardState build() {
    ref.listen(dashboardRefreshSignalProvider, (_, __) {
      ref.invalidate(hasActivePactsProvider);
      unawaited(load());
    });
    return const DashboardState();
  }

  Future<void> load() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    try {
      await _loadInner();
    } finally {
      _loadInProgress = false;
    }
  }

  Future<void> _loadInner() async {
    final today = ref.read(todayProvider);
    final todayNorm = DateTime(today.year, today.month, today.day);
    final queryService = ref.read(dashboardQueryServiceProvider);
    final crashlytics = ref.read(crashlyticsServiceProvider);

    await crashlytics.log('screen: dashboard');

    final allPacts = await queryService.getAllPacts();
    final activePacts = allPacts.where((p) => p.status == PactStatus.active).toList();
    final pactNames = {for (final p in allPacts) p.id: p.habitName};
    final activePactIds = {for (final p in activePacts) p.id};

    // PII rule: active pact count is safe (no habit names).
    await crashlytics.setCustomKey('active_pacts_count', activePacts.length);

    final generationService = ref.read(showupGenerationServiceProvider);
    final pactStatsService = ref.read(pactStatsServiceProvider);
    final schedulingService = ref.read(reminderSchedulingServiceProvider);

    // windowStart: normally todayNorm; moved back to first missed day when a gap exists.
    // Gap showups (< todayNorm) → auto-failed; forward showups → eligible for reminders.
    // Window end +10 days (> 7-day strip) to survive DST fall-back shortfall.
    final generationWindowEnd = todayNorm.add(const Duration(days: 10));
    // Only newly saved showups get reminders — existing notifications must not be duplicated.
    final Map<Pact, List<Showup>> newShowupsByPact = {};
    var gapFailedCount = 0;
    for (final pact in activePacts) {
      final latestDate = await queryService.getLatestScheduledAtForPact(pact.id);

      final DateTime windowStart;
      if (latestDate == null) {
        // Back-fill only if the pact started before today; future start → forward generation only.
        windowStart = pact.startDate.isBefore(todayNorm) ? pact.startDate : todayNorm;
      } else {
        final dayAfterLatest = DateTime(latestDate.year, latestDate.month, latestDate.day + 1);
        windowStart = dayAfterLatest.isBefore(todayNorm) ? dayAfterLatest : todayNorm;
      }

      final allNewShowups = await generationService.ensureShowupsExist(
        pact,
        from: windowStart,
        to: generationWindowEnd,
      );

      final gapShowups = allNewShowups.where((s) => s.scheduledAt.isBefore(todayNorm)).toList();
      final futureShowups = allNewShowups.where((s) => !s.scheduledAt.isBefore(todayNorm)).toList();

      // Per-showup errors isolated so a single bad row cannot block the rest.
      // TODO(perf): batch persistShowupStatus calls per pact to reduce syncStats round-trips.
      for (final showup in gapShowups) {
        try {
          await pactStatsService.persistShowupStatus(showup: showup, status: ShowupStatus.failed);
        } catch (error, stackTrace) {
          unawaited(crashlytics.log('gap_fill_sweep: error failing showup ${showup.id}: $error'));
          unawaited(ref.read(crashlyticsServiceProvider).recordError(error, stackTrace));
          continue;
        }
        unawaited(
          ref.read(analyticsServiceProvider).logEvent(ShowupAutoFailedEvent(pactId: showup.pactId)),
        );
        unawaited(schedulingService.cancelRemindersForShowup(showup.id));
        gapFailedCount++;
      }

      if (futureShowups.isNotEmpty) {
        newShowupsByPact[pact] = futureShowups;
      }
    }
    if (gapFailedCount > 0) {
      unawaited(crashlytics.log('gap_fill_sweep: count=$gapFailedCount'));
    }

    if (newShowupsByPact.isNotEmpty) {
      var totalNewCount = 0;
      for (final entry in newShowupsByPact.entries) {
        final pact = entry.key;
        if (pact.reminderOffset == null) continue;
        unawaited(
          schedulingService.scheduleRemindersForShowups(
            pact: pact,
            showups: entry.value,
            now: todayNorm,
          ),
        );
        totalNewCount += entry.value.length;
      }
      if (totalNewCount > 0) {
        unawaited(
          crashlytics.log(
            'DashboardViewModel: scheduling reminders for $totalNewCount eligible new showups',
          ),
        );
      }
    }

    // todayIndex = min(daysSinceOldestPact, 3): ramps 0→3 over first 3 days, then stays 3.
    // ALL pacts (active/stopped/completed) contribute so deleting one never shifts the strip.
    int computedTodayIndex = 3;
    if (allPacts.isNotEmpty) {
      DateTime? earliestStart;
      for (final p in allPacts) {
        final start = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
        if (earliestStart == null || start.isBefore(earliestStart)) {
          earliestStart = start;
        }
      }
      if (earliestStart != null) {
        final daysSince = todayNorm.difference(earliestStart).inDays;
        computedTodayIndex = daysSince.clamp(0, 3);
      }
    }

    // Single DB query covers the full 7-day strip; reused for auto-fail sweep below.
    final stripStart = DateTime(todayNorm.year, todayNorm.month, todayNorm.day - computedTodayIndex);
    final stripEnd = DateTime(todayNorm.year, todayNorm.month, todayNorm.day + (6 - computedTodayIndex));

    final showups = await queryService.getShowupsForDateRange(stripStart, stripEnd);

    // Auto-fail sweep: pending showups whose window has fully elapsed (status==pending, pact active, now > scheduledAt+duration).
    // TODO(perf): batch persistShowupStatus per pact to reduce syncStats round-trips (N+1, small window ≤3 days).
    final Map<String, Showup> autoFailedById = {};
    var autoFailedCount = 0;
    for (final showup in showups) {
      if (showup.status != ShowupStatus.pending) continue;
      if (!activePactIds.contains(showup.pactId)) continue;
      final windowEnd = showup.scheduledAt.add(showup.duration);
      if (!today.isAfter(windowEnd)) continue;

      try {
        await pactStatsService.persistShowupStatus(showup: showup, status: ShowupStatus.failed);
      } catch (error, stackTrace) {
        unawaited(
          crashlytics.log(
            'auto_fail_sweep: error persisting showup ${showup.id}: $error',
          ),
        );
        unawaited(ref.read(crashlyticsServiceProvider).recordError(error, stackTrace));
        continue;
      }
      autoFailedById[showup.id] = showup.copyWith(status: ShowupStatus.failed);
      unawaited(
        ref.read(analyticsServiceProvider).logEvent(ShowupAutoFailedEvent(pactId: showup.pactId)),
      );
      unawaited(schedulingService.cancelRemindersForShowup(showup.id));
      autoFailedCount++;
    }
    if (autoFailedCount > 0) {
      unawaited(crashlytics.log('auto_fail_sweep: count=$autoFailedCount'));
    }

    final updatedShowups = autoFailedById.isEmpty ? showups : showups.map((s) => autoFailedById[s.id] ?? s).toList();

    final days = List.generate(7, (i) {
      final date = DateTime(stripStart.year, stripStart.month, stripStart.day + i);
      final dayShowups =
          updatedShowups.where((s) => _sameDay(s.scheduledAt, date) && activePactIds.contains(s.pactId)).toList();
      return CalendarDayEntry(date: date, showups: dayShowups);
    });

    final reminderOffsetByPactId = {for (final p in allPacts) p.id: p.reminderOffset};

    // Preserve selection on same-date reload; reset when first load or midnight crossed.
    final newSelectedDayIndex = (state.calendarDays.isNotEmpty && computedTodayIndex == state.todayIndex)
        ? state.selectedDayIndex
        : computedTodayIndex;

    state = state.copyWith(
      calendarDays: days,
      pactNames: pactNames,
      isLoading: false,
      todayIndex: computedTodayIndex,
      selectedDayIndex: newSelectedDayIndex,
      reminderOffsetByPactId: reminderOffsetByPactId,
    );
  }

  void selectDay(int index) {
    state = state.copyWith(selectedDayIndex: index);
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
