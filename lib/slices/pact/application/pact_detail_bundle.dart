import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_page.dart';

/// Combined stats + timeline + pact metadata for a single pact.
///
/// This is the unit populated and write-through-refreshed by [PactDetailCache]
/// (HAB-174) — the shared cache replacing the separate `PactTimelineCache` and
/// `PactStatsService`'s private stats cache. Habit name and other pact
/// metadata are already available via [pact] / [timelinePage].anchorStart, so
/// no separate metadata field is needed.
final class PactDetailBundle {
  const PactDetailBundle({
    required this.pact,
    required this.stats,
    required this.timelinePage,
  });

  final Pact pact;
  final PactStats stats;
  final PactTimelinePage timelinePage;
}
