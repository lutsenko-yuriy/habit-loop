import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_state.dart';
import 'package:habit_loop/slices/showup/analytics/showup_analytics_events.dart';
import 'package:habit_loop/slices/showup/application/showup_generation_service.dart';

final todayProvider = Provider<DateTime>((ref) => DateTime.now());

final dashboardViewModelProvider = NotifierProvider<DashboardViewModel, DashboardState>(
  DashboardViewModel.new,
);

final hasActivePactsProvider = FutureProvider<bool>((ref) async {
  final pactRepo = ref.watch(pactRepositoryProvider);
  final pacts = await pactRepo.getActivePacts();
  return pacts.isNotEmpty;
});

class DashboardViewModel extends Notifier<DashboardState> {
  /// True while a [load] call is already awaiting completion.
  ///
  /// Guards against overlapping calls (e.g. initState + navigation-return both
  /// triggering load simultaneously) which would run the auto-fail sweep twice
  /// and fire duplicate [ShowupAutoFailedEvent]s.
  bool _loadInProgress = false;

  @override
  DashboardState build() {
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
    final pactRepo = ref.read(pactRepositoryProvider);
    final showupRepo = ref.read(showupRepositoryProvider);
    final crashlytics = ref.read(crashlyticsServiceProvider);

    // Log screen breadcrumb for production diagnostics.
    // PII rule: no user-entered text — only screen name.
    await crashlytics.log('screen: dashboard');

    final allPacts = await pactRepo.getAllPacts();
    final activePacts = allPacts.where((p) => p.status == PactStatus.active).toList();
    final pactNames = {for (final p in allPacts) p.id: p.habitName};
    final activePactIds = {for (final p in activePacts) p.id};

    // Set Crashlytics custom key for active pact count so crashes can be
    // filtered by user context. PII rule: count is safe — no habit names.
    await crashlytics.setCustomKey('active_pacts_count', activePacts.length);

    final generationService = ShowupGenerationService(repository: showupRepo);
    final pactStatsService = ref.read(pactStatsServiceProvider);
    final schedulingService = ref.read(reminderSchedulingServiceProvider);

    // -----------------------------------------------------------------------
    // Gap-fill pass: generate and immediately auto-fail any showups that were
    // missed during a period of extended absence.
    //
    // On each load we query the most recently persisted showup date for each
    // active pact. If there is a gap between that date and today the app was
    // not opened for an extended period and showups that should have been
    // generated during the absence were never created. We fill the gap by
    // generating those showups and marking each one as failed immediately
    // (their scheduled windows have fully elapsed).
    //
    // This is idempotent: once the gap is filled getLatestScheduledAtForPact
    // returns a date >= today and no additional work is done on subsequent
    // loads.
    //
    // The gap window ends at yesterday because today's showups are covered by
    // the forward generation pass below. The two windows are adjacent and
    // never overlap.
    // -----------------------------------------------------------------------
    final yesterday = DateTime(todayNorm.year, todayNorm.month, todayNorm.day - 1);
    var gapFailedCount = 0;
    for (final pact in activePacts) {
      final latestDate = await showupRepo.getLatestScheduledAtForPact(pact.id);
      final DateTime gapStart;
      if (latestDate == null) {
        // No showups at all yet.  Skip pacts that start today or in the future
        // — only pacts that started before today can have a past gap.
        if (!pact.startDate.isBefore(todayNorm)) continue;
        gapStart = pact.startDate;
      } else {
        // Start from the day after the most recently generated showup.
        gapStart = DateTime(latestDate.year, latestDate.month, latestDate.day + 1);
      }
      // No gap when the computed start has already reached today.
      if (!gapStart.isBefore(todayNorm)) continue;

      final gapShowups = await generationService.ensureShowupsExist(
        pact,
        from: gapStart,
        to: yesterday,
      );
      // Immediately fail all gap showups — per-showup errors are isolated so
      // that a single bad row cannot block the rest.
      // TODO(perf): if many showups share the same pact, persistShowupStatus is
      //   called once per showup (each triggers syncStats → getShowupsForPact +
      //   updatePact). A batch variant would reduce this to one syncStats call
      //   per pact. Acceptable for now given the infrequency of large gaps.
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
    }
    if (gapFailedCount > 0) {
      unawaited(crashlytics.log('gap_fill_sweep: count=$gapFailedCount'));
    }

    // -----------------------------------------------------------------------
    // Forward generation pass: ensure showups exist for each active pact in
    // the window [today, today + 10] before reading from the repository.
    // The window is intentionally wider than the 7-day calendar strip so that
    // a DST-caused 1-day shortfall still covers all visible strip days.
    // -----------------------------------------------------------------------
    final generationWindowEnd = todayNorm.add(const Duration(days: 10));
    // Accumulate newly generated showups per pact so we can schedule reminders
    // only for the newly saved ones (already-scheduled notifications must not be
    // duplicated on subsequent load calls).
    final Map<Pact, List<Showup>> newShowupsByPact = {};
    for (final pact in activePacts) {
      final newShowups = await generationService.ensureShowupsExist(
        pact,
        from: todayNorm,
        to: generationWindowEnd,
      );
      if (newShowups.isNotEmpty) {
        newShowupsByPact[pact] = newShowups;
      }
    }

    // Schedule reminders for newly generated showups. Only pacts with a
    // reminderOffset get notifications. This is fire-and-forget: notification
    // scheduling failure must never surface to the user.
    //
    // Locale resolution is handled internally by ReminderSchedulingService
    // via LocalePreferenceService — no BuildContext needed here.
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

    // -----------------------------------------------------------------------
    // todayIndex: gradual ramp over the first 3 days after the user created
    // their very first pact, then stays centred (3) thereafter.
    //
    // Formula: min(daysSinceOldestPact, 3) where
    //   daysSinceOldestPact = today.difference(oldestStartDate).inDays
    //
    // ALL pacts (active, stopped, completed) contribute to finding the oldest
    // start date so that deleting or stopping a pact never shifts the strip.
    //
    //   Day 1 (today == oldestStartDate)        → todayIndex = 0
    //   Day 2 (today == oldestStartDate + 1)    → todayIndex = 1
    //   Day 3 (today == oldestStartDate + 2)    → todayIndex = 2
    //   Day 4+ (today >= oldestStartDate + 3)   → todayIndex = 3
    // -----------------------------------------------------------------------
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

    // -----------------------------------------------------------------------
    // Load the full 7-day strip in a single DB query.  The strip always starts
    // at today - computedTodayIndex (≤ today - 3), so loading from today - 3
    // covers the entire strip regardless of the final todayIndex value.
    // This same list is reused for the auto-fail sweep below, eliminating a
    // redundant round-trip.
    // -----------------------------------------------------------------------
    final stripStart = DateTime(todayNorm.year, todayNorm.month, todayNorm.day - computedTodayIndex);
    final stripEnd = DateTime(todayNorm.year, todayNorm.month, todayNorm.day + (6 - computedTodayIndex));

    final showups = await showupRepo.getShowupsForDateRange(stripStart, stripEnd);

    // -----------------------------------------------------------------------
    // Auto-fail sweep: transition any past-due pending showups in the past
    // portion of the already-loaded strip list to ShowupStatus.failed.
    //
    // The strip query covers [stripStart, stripEnd] which includes today and
    // past days; the wall-clock check (now.isAfter(scheduledAt + duration))
    // guards against prematurely failing today's showups whose window has not
    // yet elapsed.  The sweep is intentionally filtered in-memory from the
    // strip list to avoid a second DB round-trip.
    //
    // A showup is eligible when ALL of the following hold:
    //   1. status == ShowupStatus.pending
    //   2. its pact is active
    //   3. now.isAfter(scheduledAt + duration)  [window fully elapsed]
    //
    // TODO(perf): if multiple showups belong to the same pact, persistShowupStatus
    //   is called once per showup, each triggering syncStats (getShowupsForPact +
    //   updatePact).  A future optimisation could update all showup statuses in one
    //   pass and then call syncStats once per distinct pact.  This is an N+1 against
    //   the pacts table and is acceptable given the small sweep window (≤3 days).
    // -----------------------------------------------------------------------
    // Track showups that were successfully auto-failed so the calendar strip
    // reflects the updated status without a second DB round-trip.
    final Map<String, Showup> autoFailedById = {};
    var autoFailedCount = 0;
    for (final showup in showups) {
      if (showup.status != ShowupStatus.pending) continue;
      if (!activePactIds.contains(showup.pactId)) continue;
      final windowEnd = showup.scheduledAt.add(showup.duration);
      if (!today.isAfter(windowEnd)) continue;

      try {
        // Persist the failed status and refresh the stats cache.
        await pactStatsService.persistShowupStatus(showup: showup, status: ShowupStatus.failed);
      } catch (error, stackTrace) {
        // A single bad row must not abort the entire sweep.  Log the error as
        // a breadcrumb so production diagnostics capture it, then continue with
        // the remaining showups.
        unawaited(
          crashlytics.log(
            'auto_fail_sweep: error persisting showup ${showup.id}: $error',
          ),
        );
        unawaited(ref.read(crashlyticsServiceProvider).recordError(error, stackTrace));
        continue;
      }
      autoFailedById[showup.id] = showup.copyWith(status: ShowupStatus.failed);
      // Fire analytics event (fire-and-forget — must not block the UI).
      unawaited(
        ref.read(analyticsServiceProvider).logEvent(ShowupAutoFailedEvent(pactId: showup.pactId)),
      );
      // Cancel any scheduled reminder for this showup (fire-and-forget).
      unawaited(schedulingService.cancelRemindersForShowup(showup.id));
      autoFailedCount++;
    }
    if (autoFailedCount > 0) {
      unawaited(crashlytics.log('auto_fail_sweep: count=$autoFailedCount'));
    }

    // Apply the auto-fail updates to the in-memory strip list so the calendar
    // immediately reflects the new status without an extra DB round-trip.
    final updatedShowups = autoFailedById.isEmpty ? showups : showups.map((s) => autoFailedById[s.id] ?? s).toList();

    final days = List.generate(7, (i) {
      final date = DateTime(stripStart.year, stripStart.month, stripStart.day + i);
      final dayShowups =
          updatedShowups.where((s) => _sameDay(s.scheduledAt, date) && activePactIds.contains(s.pactId)).toList();
      return CalendarDayEntry(date: date, showups: dayShowups);
    });

    final reminderOffsetByPactId = {for (final p in allPacts) p.id: p.reminderOffset};

    state = state.copyWith(
      calendarDays: days,
      pactNames: pactNames,
      isLoading: false,
      todayIndex: computedTodayIndex,
      selectedDayIndex: computedTodayIndex,
      reminderOffsetByPactId: reminderOffsetByPactId,
    );
  }

  void selectDay(int index) {
    state = state.copyWith(selectedDayIndex: index);
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
