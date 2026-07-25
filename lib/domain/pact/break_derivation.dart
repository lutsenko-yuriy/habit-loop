import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/showup/showup.dart';
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
}
