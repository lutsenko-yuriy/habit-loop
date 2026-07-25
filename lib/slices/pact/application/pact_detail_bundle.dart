import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_page.dart';

/// Combined stats + timeline + pact metadata for a single pact.
///
/// This is the unit populated and write-through-refreshed by [PactDetailCache]
/// (HAB-174) — the shared cache replacing the separate `PactTimelineCache` and
/// `PactStatsService`'s private stats cache. Habit name and other pact
/// metadata are already available via [pact] / [timelinePage].anchorStart, so
/// no separate metadata field is needed.
///
/// [breaks] (HAB-195) is the pact's full break history, oldest first — already
/// folded into [stats].skippedOnBreak; kept on the bundle so a later read
/// surface (e.g. the timeline's break milestone) can render it without a
/// separate cache fetch.
final class PactDetailBundle {
  const PactDetailBundle({
    required this.pact,
    required this.stats,
    required this.timelinePage,
    this.breaks = const [],
  });

  final Pact pact;
  final PactStats stats;
  final PactTimelinePage timelinePage;
  final List<PactBreak> breaks;
}
