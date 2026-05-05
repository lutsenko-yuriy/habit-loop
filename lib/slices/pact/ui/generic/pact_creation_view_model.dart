import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/infrastructure/analytics/providers/analytics_providers.dart';
import 'package:habit_loop/infrastructure/crashlytics/providers/crashlytics_providers.dart';
import 'package:habit_loop/infrastructure/logging/providers/log_service_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_builder.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/application/pact_service.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';

final pactCreationTodayProvider = Provider<DateTime>((ref) => DateTime.now());

final pactCreationViewModelProvider = NotifierProvider<PactCreationViewModel, PactCreationState>(
  PactCreationViewModel.new,
);

class PactCreationViewModel extends Notifier<PactCreationState> {
  @override
  PactCreationState build() {
    final today = ref.read(pactCreationTodayProvider);
    return PactCreationState(today: today);
  }

  // ---------------------------------------------------------------------------
  // Private helper — routes all data-field mutations through the builder.
  // ---------------------------------------------------------------------------

  void _updateBuilder(PactBuilder Function(PactBuilder) update) {
    state = state.copyWith(builder: update(state.builder));
  }

  // ---------------------------------------------------------------------------
  // Data-field setters — all delegate through _updateBuilder.
  // ---------------------------------------------------------------------------

  void setHabitName(String name) {
    _updateBuilder((b) => b.copyWith(habitName: name));
  }

  void setStartDate(DateTime date) {
    // Normalize to midnight so that startDate is always a pure date value.
    // Date pickers on some platforms return a DateTime with a time component,
    // which would cause durationDays analytics to under-count and daysActive
    // to report 0 when the pact is stopped the following morning.
    _updateBuilder((b) => b.copyWith(startDate: DateTime(date.year, date.month, date.day)));
  }

  void setEndDate(DateTime date) {
    _updateBuilder((b) => b.copyWith(endDate: date));
  }

  void setShowupDuration(Duration duration) {
    _updateBuilder((b) => b.copyWith(showupDuration: duration));
  }

  void setScheduleType(ScheduleType type) {
    final defaultSchedule = switch (type) {
      ScheduleType.daily => const DailySchedule(timeOfDay: Duration(hours: 8)),
      ScheduleType.weekday => const WeekdaySchedule(entries: [
          WeekdayEntry(weekday: 1, timeOfDay: Duration(hours: 8)),
        ]),
      ScheduleType.monthlyByWeekday => const MonthlyByWeekdaySchedule(entries: [
          MonthlyWeekdayEntry(occurrence: 1, weekday: 1, timeOfDay: Duration(hours: 8)),
        ]),
      ScheduleType.monthlyByDate => const MonthlyByDateSchedule(entries: [
          MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 8)),
        ]),
    };
    _updateBuilder((b) => b.copyWith(scheduleType: type, schedule: defaultSchedule));
  }

  void setSchedule(ShowupSchedule schedule) {
    _updateBuilder((b) => b.copyWith(schedule: schedule));
  }

  void setReminderOffset(Duration offset) {
    _updateBuilder((b) => b.copyWith(reminderOffset: offset));
  }

  void clearReminderOffset() {
    _updateBuilder((b) => b.copyWith(clearReminderOffset: true));
  }

  // ---------------------------------------------------------------------------
  // Wizard-concern setters — operate directly on PactCreationState.
  // ---------------------------------------------------------------------------

  void setCommitmentAccepted(bool accepted) {
    state = state.copyWith(commitmentAccepted: accepted);
  }

  void nextStep() {
    if (!state.canAdvanceFromStep) return;
    final nextStep = state.currentStep.next;
    if (nextStep == null) return;

    // Log step transition breadcrumb for production diagnostics (fire-and-forget).
    // PII rule: only step names — no user-entered text.
    unawaited(
      ref.read(crashlyticsServiceProvider).log(
            'pact_creation: step ${state.currentStep.name} -> ${nextStep.name}',
          ),
    );
    unawaited(
      ref.read(logServiceProvider).info('pact_creation: step ${state.currentStep.name} -> ${nextStep.name}'),
    );

    // Default showup duration to 10 min when entering the showup duration step.
    // CRITICAL: both builder and currentStep updates are done in a single
    // state = assignment to preserve atomicity — no intermediate state is emitted.
    if (nextStep == PactCreationStep.showupDuration && state.showupDuration == null) {
      state = state.copyWith(
        builder: state.builder.copyWith(showupDuration: const Duration(minutes: 10)),
        currentStep: nextStep,
      );
    } else {
      state = state.copyWith(currentStep: nextStep);
    }
  }

  void previousStep() {
    final prevStep = state.currentStep.previous;
    if (prevStep != null) {
      state = state.copyWith(currentStep: prevStep);
    }
  }

  Future<void> submit() async {
    if (!state.builder.isComplete) return;

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);

    try {
      // Build the pact and generate showups before any I/O so that a retry
      // does not mint a second pact ID when the first attempt fails before
      // savePact is called.
      final now = ref.read(pactCreationTodayProvider);
      final pact = state.builder.build(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt: now,
      );

      // Generate only the initial 11-day window (startDate through startDate+10)
      // to keep the repository lean. The window is intentionally wider than the
      // 7-day calendar strip so that a DST fall-back transition (which can make
      // Duration arithmetic land 1 hour early) still covers all visible strip
      // days. Further windows are generated lazily by ShowupGenerationService
      // when the dashboard loads each day.
      //
      // Showups scheduled before pact.createdAt are excluded here (and in
      // ShowupGenerationService.ensureShowupsExist) so that a user who creates
      // a pact at 10pm never sees an already-failed 8am slot on day 1.
      final windowEnd = state.startDate.add(const Duration(days: 10));
      final showups = ShowupGenerator.generateWindow(
        pact,
        from: state.startDate,
        to: windowEnd,
      ).where((s) => !s.scheduledAt.isBefore(now)).toList();

      // Delegate to PactService: atomically persist pact + showups (SQLite),
      // or fall back to the sequential save + rollback path (in-memory repos).
      final service = ref.read(pactServiceProvider);
      await service.createPact(pact, showups);

      final totalShowups = ShowupGenerator.countTotal(pact);
      final pactWithStats = await ref.read(pactStatsServiceProvider).persistInitialStatsOrRollback(
            pact: pact,
            showups: showups,
          );

      // Both pact and showups were persisted successfully — log breadcrumb and
      // fire analytics. CrashlyticsService, AnalyticsService, and LogService are
      // no-throw. Use unawaited so diagnostics never block the UI path.
      // PII rule: log only schedule type and counts — no habit name.
      final scheduleTypeName = _scheduleTypeName(pactWithStats.schedule);
      unawaited(
        ref.read(crashlyticsServiceProvider).log(
              'pact_created: scheduleType=$scheduleTypeName showupsExpected=$totalShowups',
            ),
      );
      unawaited(
        ref.read(logServiceProvider).info('pact_created: id=${pact.id} scheduleType=$scheduleTypeName'
            ' showupsExpected=$totalShowups'),
      );
      unawaited(
        ref.read(analyticsServiceProvider).logEvent(PactCreatedEvent(
              scheduleType: scheduleTypeName,
              durationDays: pactWithStats.endDate.difference(pactWithStats.startDate).inDays + 1,
              showupDurationMinutes: pactWithStats.showupDuration.inMinutes,
              reminderOffsetMinutes: pactWithStats.reminderOffset?.inMinutes,
              showupsExpected: totalShowups,
            )),
      );
    } catch (e, st) {
      unawaited(ref.read(logServiceProvider).error('pact_creation_failed', exception: e, stackTrace: st));
      state = state.copyWith(submitError: e);
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  /// Maps a [ShowupSchedule] to the analytics schedule type string.
  String _scheduleTypeName(ShowupSchedule schedule) {
    return switch (schedule) {
      DailySchedule() => 'daily',
      WeekdaySchedule() => 'weekly',
      MonthlyByWeekdaySchedule() => 'monthly',
      MonthlyByDateSchedule() => 'monthly',
    };
  }
}
