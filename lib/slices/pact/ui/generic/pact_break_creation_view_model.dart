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
  // <= the new startDate (a zero-length or inverted window that still
  // counts as "unresolved" and blocks starting any other break).
  void setStartDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final endDate = state.endDate.isAfter(normalized) ? state.endDate : normalized.add(const Duration(days: 7));
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
  /// — the hint simply stays absent until this resolves.
  Future<void> load() async {
    final showups = await ref.read(showupRepositoryProvider).getShowupsForPact(arg);
    state = state.copyWith(showupScheduledDates: showups.map((s) => s.scheduledAt).toList());
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
      // End-of-day, not midnight (HAB-215) — state.endDate is a bare picked
      // date; passing it straight through would make PactBreak.contains()
      // treat anything after midnight on that date as already past the
      // break, resuming a day earlier than the user picked.
      final endOfPickedDay = DateTime(state.endDate.year, state.endDate.month, state.endDate.day, 23, 59, 59, 999);
      await ref.read(pactBreakServiceProvider).startBreak(
            id: const Uuid().v4(),
            pactId: arg,
            startDate: state.startDate,
            rationale: rationale,
            now: now,
            plannedEndDate: untilPactEnds ? null : endOfPickedDay,
          );

      // PII rule: only pact ID and rationale length — no rationale text.
      unawaited(ref.read(crashlyticsServiceProvider).log('pact_break_started: pactId=$arg'));
      unawaited(ref.read(logServiceProvider).info('pact_break_started: pactId=$arg source=$source'));

      final durationDays = untilPactEnds ? null : state.endDate.difference(state.startDate).inDays;
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
