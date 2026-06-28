import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/pact/application/pact_showup_cache.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_page.dart';

/// Assembles a [PactTimelinePage] from the pact record and its showups.
///
/// Showups are loaded once per pactId and held in [PactShowupCache]. The
/// cache is evicted by [PactStatsService] whenever a showup status changes or
/// a pact is stopped, so the next [loadAll] re-fetches from the DB.
class PactTimelineService {
  PactTimelineService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required PactTimelineGrouper grouper,
    required PactShowupCache cache,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _grouper = grouper,
        _cache = cache;

  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final PactTimelineGrouper _grouper;
  final PactShowupCache _cache;

  Future<PactTimelinePage> loadAll({
    required String pactId,
    DateTime? now,
  }) async {
    final pact = await _pactRepository.getPactById(pactId);
    if (pact == null) throw ArgumentError('Pact $pactId not found');

    var showups = _cache.get(pactId);
    if (showups == null) {
      final raw = await _showupRepository.getShowupsForPact(pactId);
      showups = [...raw]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      _cache.populate(pactId, showups);
    }

    final effectiveNow = now ?? DateTime.now();
    final grouped = _grouper.group(showups, now: effectiveNow);
    return PactTimelinePage(
      anchorStart: _buildAnchorStart(pact),
      anchorEnd: _buildAnchorEnd(pact, showups, effectiveNow),
      milestones: grouped.milestones,
      tailPeriodInDays: _grouper.noGroupingTailPeriodInDays,
      tailStartIndex: grouped.tailStartIndex,
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
      final done = showups.where((s) => s.status == ShowupStatus.done).length;
      final failed = showups.where((s) => s.status == ShowupStatus.failed).length;
      final total = ShowupGenerator.countTotal(pact);
      return CurrentStateMilestone(
        sortAt: now,
        nextScheduledAt: pending.firstOrNull?.scheduledAt,
        showupsRemaining: (total - done - failed).clamp(0, total),
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
