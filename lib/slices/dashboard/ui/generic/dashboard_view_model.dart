import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/crashlytics/contracts/crashlytics_service.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_refresh_signal.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_state.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/reminder/application/reminder_scheduling_service.dart';
import 'package:habit_loop/slices/showup/analytics/showup_analytics_events.dart';

final todayProvider = Provider<DateTime>((ref) => DateTime.now());

final dashboardViewModelProvider = NotifierProvider<DashboardViewModel, DashboardState>(
  DashboardViewModel.new,
);

final hasActivePactsProvider = FutureProvider<bool>((ref) async {
  return ref.watch(pactListQueryServiceProvider).hasActivePacts();
});

// Active-pact context threaded between _loadInner's split steps.
typedef _PactsContext = ({
  List<Pact> allPacts,
  List<Pact> activePacts,
  Map<String, String> pactNames,
  Set<String> activePactIds,
});

class DashboardViewModel extends Notifier<DashboardState> {
  // Guards against overlapping loads that would run the auto-fail sweep twice.
  bool _loadInProgress = false;

  @override
  DashboardState build() {
    ref.listen(dashboardRefreshSignalProvider, (_, __) {
      // ignore: avoid_print
      print('DIAG refreshSignal listener fired at ${DateTime.now().toIso8601String()}');
      ref.invalidate(hasActivePactsProvider);
      unawaited(load());
    });
    return const DashboardState();
  }

  Future<void> load() async {
    // ignore: avoid_print
    print('DIAG load() called, _loadInProgress=$_loadInProgress at ${DateTime.now().toIso8601String()}');
    if (_loadInProgress) return;
    _loadInProgress = true;
    try {
      await _loadInner();
    } finally {
      _loadInProgress = false;
    }
  }

  Future<void> _loadInner() async {
    // ignore: avoid_print
    print('DIAG _loadInner start at ${DateTime.now().toIso8601String()}');
    final today = ref.read(todayProvider);
    final todayNorm = DateTime(today.year, today.month, today.day);
    final crashlytics = ref.read(crashlyticsServiceProvider);

    await crashlytics.log('screen: dashboard');

    final pactsContext = await _loadPactsContext(crashlytics: crashlytics);
    // ignore: avoid_print
    print('DIAG _loadPactsContext done at ${DateTime.now().toIso8601String()}');

    await _runGapFillSweepAndScheduleReminders(
      activePacts: pactsContext.activePacts,
      today: today,
      todayNorm: todayNorm,
      crashlytics: crashlytics,
    );
    // ignore: avoid_print
    print('DIAG _runGapFillSweepAndScheduleReminders done at ${DateTime.now().toIso8601String()}');

    // todayIndex = min(daysSinceOldestPact, 3): ramps 0→3 over first 3 days, then stays 3.
    // ALL pacts (active/stopped/completed) contribute so deleting one never shifts the strip.
    final computedTodayIndex = _computeTodayIndex(pactsContext.allPacts, todayNorm);

    // Single DB query covers the full 7-day strip; reused for auto-fail sweep below.
    final stripStart = DateTime(todayNorm.year, todayNorm.month, todayNorm.day - computedTodayIndex);
    final stripEnd = DateTime(todayNorm.year, todayNorm.month, todayNorm.day + (6 - computedTodayIndex));

    final updatedShowups = await _runAutoFailSweep(
      stripStart: stripStart,
      stripEnd: stripEnd,
      activePactIds: pactsContext.activePactIds,
      today: today,
      crashlytics: crashlytics,
    );
    // ignore: avoid_print
    print('DIAG _runAutoFailSweep done at ${DateTime.now().toIso8601String()}');

    _assembleAndSetState(
      stripStart: stripStart,
      updatedShowups: updatedShowups,
      activePactIds: pactsContext.activePactIds,
      allPacts: pactsContext.allPacts,
      pactNames: pactsContext.pactNames,
      computedTodayIndex: computedTodayIndex,
    );
    // ignore: avoid_print
    print('DIAG _assembleAndSetState done, isLoading should be false at ${DateTime.now().toIso8601String()}');
  }

  // Job 1: fetch all pacts and derive the active-pact context reused by every later step.
  Future<_PactsContext> _loadPactsContext({required CrashlyticsService crashlytics}) async {
    final queryService = ref.read(dashboardQueryServiceProvider);

    final allPacts = await queryService.getAllPacts();
    final activePacts = allPacts.where((p) => p.status == PactStatus.active).toList();
    final pactNames = {for (final p in allPacts) p.id: p.habitName};
    final activePactIds = {for (final p in activePacts) p.id};

    // PII rule: active pact count is safe (no habit names).
    await crashlytics.setCustomKey('active_pacts_count', activePacts.length);

    return (allPacts: allPacts, activePacts: activePacts, pactNames: pactNames, activePactIds: activePactIds);
  }

  // Job 2: per-active-pact — ensure showups exist for the generation window, auto-fail the
  // gap showups (before today), and schedule reminders for the newly generated future showups.
  Future<void> _runGapFillSweepAndScheduleReminders({
    required List<Pact> activePacts,
    required DateTime today,
    required DateTime todayNorm,
    required CrashlyticsService crashlytics,
  }) async {
    final queryService = ref.read(dashboardQueryServiceProvider);
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
        final failed = await _autoFailShowup(
          showup,
          pactStatsService: pactStatsService,
          schedulingService: schedulingService,
          crashlytics: crashlytics,
          today: today,
          sweepLabel: 'gap_fill_sweep',
        );
        if (failed) gapFailedCount++;
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
  }

  // Job 4: todayIndex = min(daysSinceOldestPact, 3): ramps 0→3 over first 3 days, then stays 3.
  // ALL pacts (active/stopped/completed) contribute so deleting one never shifts the strip.
  int _computeTodayIndex(List<Pact> allPacts, DateTime todayNorm) {
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
    return computedTodayIndex;
  }

  // Job 5: fetch the 7-day calendar strip's showups, then auto-fail any pending showup whose
  // window has elapsed. Returns the showups list patched with the auto-failed statuses.
  Future<List<Showup>> _runAutoFailSweep({
    required DateTime stripStart,
    required DateTime stripEnd,
    required Set<String> activePactIds,
    required DateTime today,
    required CrashlyticsService crashlytics,
  }) async {
    final queryService = ref.read(dashboardQueryServiceProvider);
    final pactStatsService = ref.read(pactStatsServiceProvider);
    final schedulingService = ref.read(reminderSchedulingServiceProvider);

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

      final failed = await _autoFailShowup(
        showup,
        pactStatsService: pactStatsService,
        schedulingService: schedulingService,
        crashlytics: crashlytics,
        today: today,
        sweepLabel: 'auto_fail_sweep',
      );
      if (!failed) continue;
      autoFailedById[showup.id] = showup.copyWith(status: ShowupStatus.failed);
      autoFailedCount++;
    }
    if (autoFailedCount > 0) {
      unawaited(crashlytics.log('auto_fail_sweep: count=$autoFailedCount'));
    }

    return autoFailedById.isEmpty ? showups : showups.map((s) => autoFailedById[s.id] ?? s).toList();
  }

  // Persists a showup as failed and fires the standard auto-fail side effects
  // (analytics event + reminder cancellation). Returns whether the persist
  // succeeded so each sweep can still update its own counter/map on failure.
  Future<bool> _autoFailShowup(
    Showup showup, {
    required PactStatsService pactStatsService,
    required ReminderSchedulingService schedulingService,
    required CrashlyticsService crashlytics,
    required DateTime today,
    required String sweepLabel,
  }) async {
    try {
      await pactStatsService.persistShowupStatus(showup: showup, status: ShowupStatus.failed, now: today);
    } catch (error, stackTrace) {
      unawaited(crashlytics.log('$sweepLabel: error failing showup ${showup.id}: $error'));
      unawaited(ref.read(crashlyticsServiceProvider).recordError(error, stackTrace));
      return false;
    }
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(ShowupAutoFailedEvent(pactId: showup.pactId)),
    );
    unawaited(schedulingService.cancelRemindersForShowup(showup.id));
    return true;
  }

  // Job 6: assemble the 7 CalendarDayEntry's from the (possibly auto-failed-patched) showups,
  // compute reminderOffsetByPactId, preserve/reset selectedDayIndex, and update state.
  void _assembleAndSetState({
    required DateTime stripStart,
    required List<Showup> updatedShowups,
    required Set<String> activePactIds,
    required List<Pact> allPacts,
    required Map<String, String> pactNames,
    required int computedTodayIndex,
  }) {
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
