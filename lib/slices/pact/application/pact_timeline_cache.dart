import 'package:habit_loop/domain/showup/showup.dart';

/// Session-scoped in-memory showup cache for the pact timeline.
///
/// Keyed by pactId. Evicted whenever a showup status changes or a pact stops,
/// so the next [PactTimelineService.loadAll] re-fetches from the DB.
class PactTimelineCache {
  final Map<String, List<Showup>> _cache = {};

  List<Showup>? get(String pactId) => _cache[pactId];

  void populate(String pactId, List<Showup> showups) {
    _cache[pactId] = showups;
  }

  void evict(String pactId) {
    _cache.remove(pactId);
  }
}
