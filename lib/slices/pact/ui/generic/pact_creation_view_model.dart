import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_builder.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';

// Overridable in tests to freeze wizard-open time.
final pactCreationTodayProvider = Provider<DateTime>((ref) => DateTime.now());

// Separate from pactCreationTodayProvider: wizard can be open for minutes before submit,
// using stale time would generate showups that immediately auto-fail (HAB-84).
final pactCreationSubmitNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final pactCreationViewModelProvider = NotifierProvider<PactCreationViewModel, PactCreationState>(
  PactCreationViewModel.new,
);

class PactCreationViewModel extends Notifier<PactCreationState> {
  @override
  PactCreationState build() {
    final today = ref.read(pactCreationTodayProvider);
    final base = PactCreationState(today: today);
    return base.copyWith(
      builder: base.builder.copyWith(
        scheduleType: ScheduleType.slot,
        schedule: SlotSchedule(slots: [
          WeeklySlot(weekdays: {1, 2, 3, 4, 5}, timeOfDay: const Duration(hours: 8)),
        ]),
      ),
    );
  }

  void _updateBuilder(PactBuilder Function(PactBuilder) update) {
    state = state.copyWith(builder: update(state.builder));
  }

  void setHabitName(String name) {
    _updateBuilder((b) => b.copyWith(habitName: name));
  }

  void setStartDate(DateTime date) {
    // Normalize to midnight — pickers on some platforms return a time component
    // that would cause durationDays analytics to under-count and daysActive to report 0.
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
      // slot: default is Mon-Fri at 08:00 — one ready-to-use card.
      ScheduleType.slot => SlotSchedule(slots: [
          WeeklySlot(weekdays: {1, 2, 3, 4, 5}, timeOfDay: const Duration(hours: 8)),
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

  void setCommitmentAccepted(bool accepted) {
    state = state.copyWith(commitmentAccepted: accepted);
  }

  // Clamps page index; defaults showupDuration to 10 min on first visit to step 2.
  void goToPage(int page) {
    final clamped = page.clamp(0, PactWizardStep.values.length - 1);
    final targetStep = PactWizardStep.values[clamped];

    // PII rule: only step names — no user-entered text.
    unawaited(
      ref.read(crashlyticsServiceProvider).log(
            'pact_creation: -> ${targetStep.name}',
          ),
    );
    unawaited(
      ref.read(logServiceProvider).info('pact_creation: -> ${targetStep.name}'),
    );

    // Single assignment keeps builder + currentStep atomic — no intermediate state emitted.
    if (targetStep == PactWizardStep.showupDuration && state.showupDuration == null) {
      state = state.copyWith(
        builder: state.builder.copyWith(showupDuration: const Duration(minutes: 10)),
        currentStep: targetStep,
      );
    } else {
      state = state.copyWith(currentStep: targetStep);
    }
  }

  void markSummaryJumped() {
    if (!state.usedSummaryJump) {
      state = state.copyWith(usedSummaryJump: true);
    }
  }

  Future<void> submit({required String commitmentVariant}) async {
    if (!state.builder.isComplete) return;

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);

    try {
      // Use fresh now, not cached wizard-open time (HAB-84).
      final now = ref.read(pactCreationSubmitNowProvider)();

      // Initial window +10 days (wider than 7-day strip for DST safety); further windows generated lazily.
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
      SlotSchedule() => 'slot',
    };
  }
}
