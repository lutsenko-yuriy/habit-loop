import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';

/// Shared on-break predicate — on-break state is derived at read time, never
/// materialised on the showup row (HAB-195). Every read surface (stats,
/// dashboard sweep, showup detail, timeline) must use this helper so they
/// cannot diverge.
abstract final class BreakDerivation {
  /// A showup is "on break" iff it is still [ShowupStatus.pending] and its
  /// [Showup.scheduledAt] falls inside any of [breaks]' windows.
  ///
  /// An explicit mark (done/failed) always overrides the break — this is
  /// checked first so a resolved showup is never reported as on-break.
  static bool isShowupOnBreak({
    required Showup showup,
    required List<PactBreak> breaks,
  }) {
    if (showup.status != ShowupStatus.pending) return false;
    return breaks.any((b) => b.contains(showup.scheduledAt));
  }

  // Bounds the ShowupGenerator lookahead used to find a break's first
  // post-break showup — comfortably covers even a monthly schedule's cycle
  // without generating a pact's entire remaining lifetime just to find one id.
  static const _lookahead = Duration(days: 60);

  /// The showup that should get "welcome back" reminder text (HAB-227) for
  /// [b] — the first showup scheduled after [b]'s fixed end, as long as [b]
  /// wasn't resumed early via "Resume pact". Returns `null` when [b] doesn't
  /// qualify (open-ended, resumed early, or no matching showup found).
  ///
  /// Open-ended breaks (no [PactBreak.plannedEndDate]) never qualify — there's
  /// no fixed end to compute a first-showup-after from, and per spec an
  /// explicit resume of an open-ended break gets normal reminders throughout.
  /// Purely a function of [PactBreak.plannedEndDate]/[PactBreak.stoppedAt] —
  /// nothing is persisted, so this stays correct across recomputation (e.g. a
  /// showup not yet generated when a break starts still resolves to the right
  /// id once actually created, and an early resume naturally drops out here
  /// without any separate "un-tag" step).
  static Showup? firstShowupAfterBreak(Pact pact, PactBreak b) {
    final plannedEnd = b.plannedEndDate;
    if (plannedEnd == null) return null;

    final boundary = PactBreak.endOfDay(plannedEnd);
    final resumedEarly = b.stoppedAt != null && b.stoppedAt!.isBefore(boundary);
    if (resumedEarly) return null;

    // generateWindow's range check is day-granular (from's whole day is
    // included), so filter to strictly-after the exact boundary instant —
    // otherwise a showup earlier that same day (still inside the break)
    // would wrongly qualify as "the first showup after the break".
    final candidates = ShowupGenerator.generateWindow(pact, from: boundary, to: boundary.add(_lookahead))
        .where((s) => s.scheduledAt.isAfter(boundary));
    if (candidates.isEmpty) return null;
    return candidates.reduce((a, c) => c.scheduledAt.isBefore(a.scheduledAt) ? c : a);
  }

  /// The showup ids that should get "welcome back" reminder text (HAB-227) —
  /// see [firstShowupAfterBreak], applied across all of [breaks].
  static Set<String> welcomeBackShowupIds(Pact pact, List<PactBreak> breaks) {
    return breaks.map((b) => firstShowupAfterBreak(pact, b)?.id).whereType<String>().toSet();
  }
}
