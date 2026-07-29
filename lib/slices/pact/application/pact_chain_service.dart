import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/schedule_type.dart';
import 'package:habit_loop/slices/pact/application/pact_builder.dart';

/// Computes chain-derived defaults for "Adjust and start again" (HAB-202):
/// the versioned habit name and a pre-filled [PactBuilder] for the new
/// successor pact.
class PactChainService {
  PactChainService({required PactRepository pactRepository}) : _pactRepository = pactRepository;

  final PactRepository _pactRepository;

  /// Walks predecessorPactId links from [predecessor] back to the chain's
  /// root, counting hops. Tolerates a dangling reference (predecessor id with
  /// no matching row — possible under out-of-order sync) by stopping there
  /// and treating the last-reached pact as root. Also tolerates a cyclic
  /// chain (self-loop or mutual A<->B links from corrupt/malicious sync
  /// data) by stopping at the first already-visited id rather than looping
  /// forever — there is no DB constraint preventing a cycle, only "at most
  /// one successor per predecessor".
  Future<({Pact root, int hopsToRoot})> _walkToRoot(Pact predecessor) async {
    var current = predecessor;
    var hops = 0;
    final visited = {predecessor.id};
    while (current.predecessorPactId != null) {
      final nextId = current.predecessorPactId!;
      if (visited.contains(nextId)) break;
      final next = await _pactRepository.getPactById(nextId);
      if (next == null) break;
      visited.add(nextId);
      current = next;
      hops++;
    }
    return (root: current, hopsToRoot: hops);
  }

  /// Default name for the new pact being created from [predecessor]: the
  /// root's *current* habit name (renames along the chain are ignored)
  /// suffixed with "(v{n+1})", where n is the number of ancestors between
  /// the root and the new pact.
  Future<String> defaultNameFor(Pact predecessor) async {
    final walk = await _walkToRoot(predecessor);
    // walk.hopsToRoot ancestors sit strictly between the root and predecessor;
    // the new pact is one further generation down.
    final version = walk.hopsToRoot + 2;
    return '${walk.root.habitName} (v$version)';
  }

  /// A [PactBuilder] pre-filled from [predecessor] for the creation wizard:
  /// habit name (see [defaultNameFor]), schedule, showup duration and
  /// reminder offset are carried over; start/end date default like a brand
  /// new pact (start = [today], not the predecessor's) — per spec, the start
  /// date is never carried over.
  Future<PactBuilder> buildPrefillFor(Pact predecessor, {required DateTime today}) async {
    final habitName = await defaultNameFor(predecessor);
    // Reuses fromPact's legacy-schedule migration to SlotSchedule, discarding
    // its start/end date carryover — those come from the fresh PactBuilder default instead.
    final migrated = PactBuilder.fromPact(predecessor, today: today);
    return PactBuilder(
      today: today,
      habitName: habitName,
      showupDuration: predecessor.showupDuration,
      scheduleType: ScheduleType.slot,
      schedule: migrated.schedule,
      reminderOffset: predecessor.reminderOffset,
    );
  }
}
