import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_config.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_page.dart';

/// Assembles a [PactTimelinePage] from the pact record and its showups.
///
/// Pure application-layer service; no caching (added in WU4 via [pactTimelineCacheProvider]).
class PactTimelineService {
  const PactTimelineService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository;

  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;

  Future<PactTimelinePage> loadPage({
    required String pactId,
    required int pageNumber,
    required PactTimelineConfig config,
    DateTime? now,
  }) async {
    final pact = await _pactRepository.getPactById(pactId);
    if (pact == null) throw ArgumentError('Pact $pactId not found');

    final rawShowups = await _showupRepository.getShowupsForPact(pactId);
    final showups = [...rawShowups]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final anchorStart = _buildAnchorStart(pact);
    final anchorEnd = _buildAnchorEnd(pact, showups, now ?? DateTime.now());

    final tailSize = config.noGroupingTailSize > 0 ? config.noGroupingTailSize : null;
    final grouper = PactTimelineGrouper(
      groupingThreshold: config.milestoneGroupingThreshold,
      noGroupingTailSize: tailSize,
    );
    final allGrouped = grouper.group(showups);

    final (firstSize, nthSize) = _resolvePageSizes(config);
    final totalVisible = pageNumber == 1 ? firstSize : firstSize + (pageNumber - 1) * nthSize;

    final hasMoreOlder = allGrouped.length > totalVisible;
    final startIndex = hasMoreOlder ? allGrouped.length - totalVisible : 0;
    final visible = allGrouped.sublist(startIndex);

    return PactTimelinePage(
      anchorStart: anchorStart,
      anchorEnd: anchorEnd,
      milestones: visible,
      hasMoreOlder: hasMoreOlder,
      loadedPageCount: pageNumber,
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

  (int firstSize, int nthSize) _resolvePageSizes(PactTimelineConfig config) {
    final hasFirst = config.firstPageSize > 0;
    final hasNth = config.nthPageSize > 0;
    if (hasFirst && hasNth) return (config.firstPageSize, config.nthPageSize);
    if (hasFirst) return (config.firstPageSize, config.firstPageSize ~/ 2);
    if (hasNth) return (config.nthPageSize * 2, config.nthPageSize);
    return (20, 10);
  }
}
