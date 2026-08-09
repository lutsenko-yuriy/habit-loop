import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_break_creation_state.dart';
import 'package:uuid/uuid.dart';

// Overridable in tests; sampled once in build() so a screen opened at one
// moment keeps stable "today" defaults even if the picker is left open.
final pactBreakCreationNowProvider = Provider<DateTime>((ref) => DateTime.now());

// autoDispose so a fresh form (today's date, empty rationale) is presented
// every time the flow is opened, mirroring ShowupDetailViewModel.
final pactBreakCreationViewModelProvider =
    AutoDisposeNotifierProviderFamily<PactBreakCreationViewModel, PactBreakCreationState, String>(
  PactBreakCreationViewModel.new,
);

class PactBreakCreationViewModel extends AutoDisposeFamilyNotifier<PactBreakCreationState, String> {
  @override
  PactBreakCreationState build(String pactId) {
    final now = ref.read(pactBreakCreationNowProvider);
    final today = DateTime(now.year, now.month, now.day);
    return PactBreakCreationState(
      startDate: today,
      // A week is a reasonable initial suggestion; freely adjustable via the
      // end-date picker, or overridden entirely by the open-ended toggle.
      endDate: today.add(const Duration(days: 7)),
    );
  }

  // The start-date picker's floor is always "today", independent of the
  // current endDate — bump endDate forward when it would otherwise become
  // an inverted window (endDate before the new startDate). A same-day
  // window (endDate == startDate) is a valid single-day break (HAB-215) and
  // is left alone.
  void setStartDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final endDate = state.endDate.isBefore(normalized) ? normalized.add(const Duration(days: 7)) : state.endDate;
    state = state.copyWith(startDate: normalized, endDate: endDate);
  }

  void setEndDate(DateTime date) {
    state = state.copyWith(endDate: DateTime(date.year, date.month, date.day));
  }

  void setUntilPactEnds(bool value) {
    state = state.copyWith(untilPactEnds: value);
  }

  void setRationale(String value) {
    state = state.copyWith(rationale: value);
  }

  /// Loads this pact's showups so [PactBreakCreationState.nextShowupAfterEnd]
  /// can be derived (HAB-215). Fire-and-forget from the screen's `initState`
  /// — any failure is swallowed (mirroring PactDetailViewModel's chain-cache
  /// warm) rather than escaping to the global error handler as a fatal
  /// crash; the hint simply stays absent.
  Future<void> load() async {
    try {
      final scheduledDates = await ref.read(pactBreakServiceProvider).getShowupScheduledDatesForPact(arg);
      state = state.copyWith(showupScheduledDates: scheduledDates);
    } catch (e, st) {
      unawaited(
        ref
            .read(logServiceProvider)
            .error('pact_break_creation_showup_load_failed: pactId=$arg', exception: e, stackTrace: st),
      );
    }
  }

  /// Persists the break via [PactBreakService]. Returns `true` on success.
  /// [source] identifies the entry point for analytics: `pact_detail` |
  /// `tail_zone_showup`.
  Future<bool> submit({required String source}) async {
    if (!state.canSubmit) return false;
    state = state.copyWith(isSubmitting: true, clearSubmitError: true);

    final rationale = state.rationale.trim();
    final untilPactEnds = state.untilPactEnds;

    try {
      final now = ref.read(pactBreakCreationNowProvider);
      // plannedEndDate is stored as the bare picked date — PactBreak treats
      // it as naming a whole calendar day (HAB-215), not a precise instant,
      // so no end-of-day conversion is needed here.
      await ref.read(pactBreakServiceProvider).startBreak(
            id: const Uuid().v4(),
            pactId: arg,
            startDate: state.startDate,
            rationale: rationale,
            now: now,
            plannedEndDate: untilPactEnds ? null : state.endDate,
          );

      // PII rule: only pact ID and rationale length — no rationale text.
      unawaited(ref.read(crashlyticsServiceProvider).log('pact_break_started: pactId=$arg'));
      unawaited(ref.read(logServiceProvider).info('pact_break_started: pactId=$arg source=$source'));

      // +1: inclusive of both start and end dates (HAB-215), matching pact_created's
      // duration_days convention — a same-day break is 1 day, not 0.
      final durationDays = untilPactEnds ? null : state.endDate.difference(state.startDate).inDays + 1;
      unawaited(
        ref.read(analyticsServiceProvider).logEvent(PactBreakStartedEvent(
              pactId: arg,
              source: source,
              endType: untilPactEnds ? 'until_pact_ends' : 'fixed_date',
              durationDays: durationDays,
              rationaleLength: rationale.length,
            )),
      );

      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e, st) {
      unawaited(
        ref.read(logServiceProvider).error('pact_break_start_failed: pactId=$arg', exception: e, stackTrace: st),
      );
      state = state.copyWith(isSubmitting: false, submitError: e);
      return false;
    }
  }
}
