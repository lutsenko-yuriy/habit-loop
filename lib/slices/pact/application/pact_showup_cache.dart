import 'package:habit_loop/domain/showup/showup.dart';

/// Session-scoped in-memory showup cache shared by [PactTimelineService] and
/// [PactStatsService].
///
/// Keyed by pactId. Evicted whenever a showup status changes or a pact stops,
/// so the next consumer call re-fetches from the DB.
class PactShowupCache {
  final Map<String, List<Showup>> _cache = {};

  List<Showup>? get(String pactId) => _cache[pactId];

  void populate(String pactId, List<Showup> showups) {
    _cache[pactId] = showups;
  }

  void evict(String pactId) {
    _cache.remove(pactId);
  }
}
