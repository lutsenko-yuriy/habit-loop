import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_builder.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';

/// Provides the current time when the pact creation wizard is first opened.
/// Used to initialise the wizard's start-date default.
///
/// Override in tests to freeze the wizard-open time.
final pactCreationTodayProvider = Provider<DateTime>((ref) => DateTime.now());

/// Provides a factory that returns the current time at submit.
///
/// Kept separate from [pactCreationTodayProvider] because the wizard can be
/// open for minutes before the user taps "Create" — using wizard-open time as
/// the submit instant causes showups whose window closes during wizard filling
/// to be generated and then immediately auto-failed on the first dashboard load
/// (HAB-84).
///
/// Override in tests via `overrideWithValue(() => fixedTime)`.
final pactCreationSubmitNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

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

  /// Navigates the wizard to the given [page] index.
  ///
  /// Called from the [PageView]'s `onPageChanged` callback whenever a page
  /// transition completes (swipe or programmatic jump). Updates [currentStep]
  /// so the rest of the UI (step indicator, analytics) stays in sync.
  ///
  /// Out-of-range indices are clamped to the valid [PactWizardStep] range.
  ///
  /// When the [showupDuration] page (index 2) is first visited and
  /// [showupDuration] is still null, defaults it to 10 minutes — identical to
  /// the old `nextStep()` behaviour so existing tests and UX are preserved.
  void goToPage(int page) {
    final clamped = page.clamp(0, PactWizardStep.values.length - 1);
    final targetStep = PactWizardStep.values[clamped];

    // Log step transition breadcrumb for production diagnostics (fire-and-forget).
    // PII rule: only step names — no user-entered text.
    unawaited(
      ref.read(crashlyticsServiceProvider).log(
            'pact_creation: -> ${targetStep.name}',
          ),
    );
    unawaited(
      ref.read(logServiceProvider).info('pact_creation: -> ${targetStep.name}'),
    );

    // Default showup duration to 10 min when entering the showup duration step
    // for the first time. Both builder and currentStep updates are done in a
    // single assignment to preserve atomicity — no intermediate state emitted.
    if (targetStep == PactWizardStep.showupDuration && state.showupDuration == null) {
      state = state.copyWith(
        builder: state.builder.copyWith(showupDuration: const Duration(minutes: 10)),
        currentStep: targetStep,
      );
    } else {
      state = state.copyWith(currentStep: targetStep);
    }
  }

  /// Marks that the user tapped a Summary-screen row to jump back to a step.
  ///
  /// Sets [usedSummaryJump] to `true` so the `pact_created` analytics event
  /// can report whether the user reviewed any step before committing.
  void markSummaryJumped() {
    if (!state.usedSummaryJump) {
      state = state.copyWith(usedSummaryJump: true);
    }
  }

  Future<void> submit({required String commitmentVariant}) async {
    if (!state.builder.isComplete) return;

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);

    try {
      // Use the actual current time at submit — not the cached wizard-open time.
      // The wizard can be open for several minutes; using the stale provider
      // value would allow showups whose window closes during wizard filling to
      // be generated and then immediately auto-failed on dashboard load (HAB-84).
      final now = ref.read(pactCreationSubmitNowProvider)();

      // Generate only the initial 11-day window (startDate through startDate+10)
      // to keep the repository lean. The window is intentionally wider than the
      // 7-day calendar strip so that a DST fall-back transition (which can make
      // Duration arithmetic land 1 hour early) still covers all visible strip
      // days. Further windows are generated lazily by ShowupGenerationService
      // when the dashboard loads each day.
      //
      // Showups scheduled before pact.createdAt are excluded by
      // createPactFromBuilder (and in ShowupGenerationService.ensureShowupsExist)
      // so that a user who creates a pact at 10 pm never sees an already-failed
      // 8 am slot on day 1.
      final windowEnd = state.startDate.add(const Duration(days: 10));
      final service = ref.read(pactServiceProvider);
      final pact = await service.createPactFromBuilder(
        builder: state.builder,
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        now: now,
        windowEnd: windowEnd,
      );

      final showups = await service.getShowupsForPact(pact.id);
      final totalShowups = ShowupGenerator.countTotal(pact);
      final pactWithStats = await ref.read(pactStatsServiceProvider).persistInitialStatsOrRollback(
            pact: pact,
            showups: showups,
          );

      // Schedule reminders for the initial window of showups when a reminder
      // offset is configured. Locale resolution is handled internally by
      // ReminderSchedulingService via LocalePreferenceService.
      if (pactWithStats.reminderOffset != null) {
        unawaited(
          ref.read(reminderSchedulingServiceProvider).scheduleRemindersForShowups(
                pact: pactWithStats,
                showups: showups,
              ),
        );
        unawaited(
          ref.read(crashlyticsServiceProvider).log(
                'PactCreationViewModel: scheduled reminders for ${showups.length} showups',
              ),
        );
      }

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
              usedSummaryJump: state.usedSummaryJump,
              commitmentVariant: commitmentVariant,
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
