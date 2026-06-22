import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_page.dart';

/// Assembles a [PactTimelinePage] from the pact record and its showups.
///
/// Pure application-layer service; no caching.
class PactTimelineService {
  const PactTimelineService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required PactTimelineGrouper grouper,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _grouper = grouper;

  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final PactTimelineGrouper _grouper;

  Future<PactTimelinePage> loadAll({
    required String pactId,
    DateTime? now,
  }) async {
    final pact = await _pactRepository.getPactById(pactId);
    if (pact == null) throw ArgumentError('Pact $pactId not found');

    final rawShowups = await _showupRepository.getShowupsForPact(pactId);
    final showups = [...rawShowups]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return PactTimelinePage(
      anchorStart: _buildAnchorStart(pact),
      anchorEnd: _buildAnchorEnd(pact, showups, now ?? DateTime.now()),
      milestones: _grouper.group(showups),
    );
  }

  PactCreatedMilestone _buildAnchorStart(Pact pact) => PactCreatedMilestone(
        sortAt: pact.createdAt ?? pact.startDate,
        habitName: pact.habitName,
        schedule: pact.schedule,
        plannedEndDate: pact.endDate,
      );

  PactTimelineMilestone _buildAnchorEnd(Pact pact, List<Showup> showups, DateTime now) {
    if (pact.status == PactStatus.active) {
      final pending = showups.where((s) => s.status == ShowupStatus.pending);
      return CurrentStateMilestone(
        sortAt: now,
        nextScheduledAt: pending.firstOrNull?.scheduledAt,
        showupsRemaining: pending.length,
        plannedEndDate: pact.endDate,
      );
    }
    final concludedAt = pact.stoppedAt ?? pact.endDate;
    return PactConcludedMilestone(
      sortAt: concludedAt,
      concludedAt: concludedAt,
      finalStatus: pact.status,
      note: pact.stopReason,
    );
  }
}
