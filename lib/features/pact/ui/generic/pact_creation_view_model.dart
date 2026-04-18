import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/analytics/providers/analytics_providers.dart';
import 'package:habit_loop/features/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/features/pact/data/pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_creation_state.dart';
import 'package:habit_loop/features/pact/domain/pact_stats.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/showup/data/showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup_generator.dart';

final pactCreationTodayProvider = Provider<DateTime>((ref) => DateTime.now());

final pactCreationRepositoryProvider = Provider<PactRepository>((ref) {
  throw UnimplementedError('Override pactCreationRepositoryProvider');
});

/// Provides the [ShowupRepository] used during pact creation.
///
/// Must be overridden in every [ProviderScope] (and in every test that
/// exercises [PactCreationViewModel.submit]), otherwise accessing it will
/// throw [UnimplementedError].
final pactCreationShowupRepositoryProvider = Provider<ShowupRepository>((ref) {
  throw UnimplementedError('Override pactCreationShowupRepositoryProvider');
});

final pactCreationViewModelProvider =
    NotifierProvider<PactCreationViewModel, PactCreationState>(
  PactCreationViewModel.new,
);

class PactCreationViewModel extends Notifier<PactCreationState> {
  @override
  PactCreationState build() {
    final today = ref.read(pactCreationTodayProvider);
    return PactCreationState(today: today);
  }

  void setHabitName(String name) {
    state = state.copyWith(habitName: name);
  }

  void setStartDate(DateTime date) {
    state = state.copyWith(startDate: date);
  }

  void setEndDate(DateTime date) {
    state = state.copyWith(endDate: date);
  }

  void setShowupDuration(Duration duration) {
    state = state.copyWith(showupDuration: duration);
  }

  void setScheduleType(ScheduleType type) {
    final defaultSchedule = switch (type) {
      ScheduleType.daily => const DailySchedule(timeOfDay: Duration(hours: 8)),
      ScheduleType.weekday => const WeekdaySchedule(entries: [
          WeekdayEntry(weekday: 1, timeOfDay: Duration(hours: 8)),
        ]),
      ScheduleType.monthlyByWeekday => const MonthlyByWeekdaySchedule(entries: [
          MonthlyWeekdayEntry(
              occurrence: 1, weekday: 1, timeOfDay: Duration(hours: 8)),
        ]),
      ScheduleType.monthlyByDate => const MonthlyByDateSchedule(entries: [
          MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 8)),
        ]),
    };
    state = state.copyWith(scheduleType: type, schedule: defaultSchedule);
  }

  void setSchedule(ShowupSchedule schedule) {
    state = state.copyWith(schedule: schedule);
  }

  void setReminderOffset(Duration offset) {
    state = state.copyWith(reminderOffset: offset);
  }

  void clearReminderOffset() {
    state = state.copyWith(clearReminderOffset: true);
  }

  void setCommitmentAccepted(bool accepted) {
    state = state.copyWith(commitmentAccepted: accepted);
  }

  void nextStep() {
    if (!state.canAdvanceFromStep) return;
    final nextStep = state.currentStep.next;
    if (nextStep == null) return;
    // Default showup duration to 10 min when entering the showup duration step
    if (nextStep == PactCreationStep.showupDuration &&
        state.showupDuration == null) {
      state = state.copyWith(
        currentStep: nextStep,
        showupDuration: const Duration(minutes: 10),
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
    if (state.schedule == null || state.showupDuration == null) return;

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);

    // Build the pact and generate showups before any I/O so that a retry
    // does not mint a second pact ID when the first attempt fails before
    // savePact is called. Note: if savePact succeeded but the rollback via
    // deletePact later fails, a subsequent retry will produce a new ID and
    // a second orphaned record — full idempotency requires storage-level
    // transactions, which will be addressed in the SQLite implementation.
    final now = ref.read(pactCreationTodayProvider);
    final pact = Pact(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      habitName: state.habitName.trim(),
      startDate: state.startDate,
      endDate: state.endDate,
      showupDuration: state.showupDuration!,
      schedule: state.schedule!,
      status: PactStatus.active,
      reminderOffset: state.reminderOffset,
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

    try {
      final pactRepo = ref.read(pactCreationRepositoryProvider);
      await pactRepo.savePact(pact);

      try {
        final showupRepo = ref.read(pactCreationShowupRepositoryProvider);
        final result = await showupRepo.saveShowups(showups);
        if (!result.allSaved) {
          throw StateError(
            'Failed to save ${result.skippedIds.length} showup(s): '
            '${result.skippedIds}',
          );
        }
      } catch (e) {
        // Roll back the pact so the app is not left with an orphaned pact
        // that has no showups.
        // TECH DEBT: if deletePact itself throws (e.g. DB locked), the
        // rollback silently fails, the original error is masked by the new
        // exception, and the pact remains orphaned. The proper fix is to
        // wrap both writes in a single DB transaction (sqflite db.transaction)
        // once the SQLite implementation is in place, making this manual
        // rollback unnecessary. Tracked in CHANGELOG.md § Issues.
        await pactRepo.deletePact(pact.id);
        rethrow;
      }

      final totalShowups = ShowupGenerator.countTotal(pact);
      final pactWithStats = pact.copyWith(
        stats: PactStats.compute(
          startDate: pact.startDate,
          endDate: pact.endDate,
          showups: showups,
          totalShowups: totalShowups,
        ),
      );
      await pactRepo.updatePact(pactWithStats);

      // Both pact and showups were persisted successfully — fire analytics.
      // AnalyticsService is no-throw; no wrapping try/catch needed.
      await ref.read(analyticsServiceProvider).logEvent(PactCreatedEvent(
            scheduleType: _scheduleTypeName(pactWithStats.schedule),
            durationDays: pactWithStats.endDate
                    .difference(pactWithStats.startDate)
                    .inDays +
                1,
            showupDurationMinutes: pactWithStats.showupDuration.inMinutes,
            reminderOffsetMinutes: pactWithStats.reminderOffset?.inMinutes,
            showupsExpected: totalShowups,
          ));
    } catch (e) {
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
