import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Theme;
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_state.dart';

// ── Public page widget ─────────────────────────────────────────────────────────

class PactTimelinePageIos extends StatelessWidget {
  final PactTimelineState state;

  /// Called when the user taps a tappable milestone ([NotedShowupMilestone] or
  /// [SingleShowupMilestone]). The screen uses this to fire analytics and navigate.
  final void Function(PactTimelineMilestone milestone)? onMilestoneTapped;

  const PactTimelinePageIos({
    super.key,
    required this.state,
    this.onMilestoneTapped,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        middle: Text(l10n.pactTimelineTitle),
      ),
      child: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: state.isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : state.loadError != null
                  ? Center(child: Text(state.loadError.toString()))
                  : _TimelineList(state: state, onMilestoneTapped: onMilestoneTapped),
        ),
      ),
    );
  }
}

// ── Timeline list ──────────────────────────────────────────────────────────────

class _TimelineList extends StatefulWidget {
  final PactTimelineState state;
  final void Function(PactTimelineMilestone)? onMilestoneTapped;

  const _TimelineList({required this.state, this.onMilestoneTapped});

  @override
  State<_TimelineList> createState() => _TimelineListState();
}

class _TimelineListState extends State<_TimelineList> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    // Scroll to anchor (bottom of list) after first layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients && _controller.position.maxScrollExtent > 0) {
        _controller.jumpTo(_controller.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = <PactTimelineMilestone>[
      if (widget.state.anchorStart != null) widget.state.anchorStart!,
      ...widget.state.milestones,
      if (widget.state.anchorEnd != null) widget.state.anchorEnd!,
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      controller: _controller,
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _SpineItem(
        milestone: items[i],
        isFirst: i == 0,
        isLast: i == items.length - 1,
        onTapped: widget.onMilestoneTapped,
      ),
    );
  }
}

// ── Spine item (vertical line + dot + full-bleed content) ─────────────────────

class _SpineItem extends StatelessWidget {
  final PactTimelineMilestone milestone;
  final bool isFirst;
  final bool isLast;
  final void Function(PactTimelineMilestone)? onTapped;

  const _SpineItem({
    required this.milestone,
    required this.isFirst,
    required this.isLast,
    this.onTapped,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dotColor = _dotColor(milestone, context);
    final lineColor = CupertinoColors.separator.resolveFrom(context);
    final isAnchor =
        milestone is PactCreatedMilestone || milestone is CurrentStateMilestone || milestone is PactConcludedMilestone;
    final isTappable = milestone is NotedShowupMilestone || milestone is SingleShowupMilestone;
    final showupId = switch (milestone) {
      NotedShowupMilestone m => m.showupId,
      SingleShowupMilestone m => m.showupId,
      _ => null,
    };
    final vertPad = _verticalPadding(milestone);

    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: CustomPaint(
              painter: _SpinePainter(
                dotColor: dotColor,
                lineColor: lineColor,
                isFirst: isFirst,
                isLast: isLast,
                dotRadius: isAnchor ? 6.0 : 4.0,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: vertPad, bottom: vertPad, right: 16),
              child: _MilestoneContent(milestone: milestone, l10n: l10n),
            ),
          ),
        ],
      ),
    );

    if (!isTappable || onTapped == null) return row;

    return GestureDetector(
      key: showupId != null ? Key('timeline-milestone-$showupId') : null,
      behavior: HitTestBehavior.opaque,
      onTap: () => onTapped!(milestone),
      child: row,
    );
  }
}

// ── Spine painter ──────────────────────────────────────────────────────────────

class _SpinePainter extends CustomPainter {
  final Color dotColor;
  final Color lineColor;
  final bool isFirst;
  final bool isLast;
  final double dotRadius;

  // Horizontal center of the spine within the 44px spine column.
  static const _spineX = 22.0;
  // Vertical offset of the dot center from the top of the item.
  static const _dotTopOffset = 16.0;

  const _SpinePainter({
    required this.dotColor,
    required this.lineColor,
    required this.isFirst,
    required this.isLast,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final dotCenterY = _dotTopOffset + dotRadius;

    if (!isFirst) {
      canvas.drawLine(const Offset(_spineX, 0), Offset(_spineX, dotCenterY - dotRadius - 1), linePaint);
    }
    if (!isLast) {
      canvas.drawLine(Offset(_spineX, dotCenterY + dotRadius + 1), Offset(_spineX, size.height), linePaint);
    }
    canvas.drawCircle(Offset(_spineX, dotCenterY), dotRadius, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(_SpinePainter old) =>
      old.dotColor != dotColor ||
      old.lineColor != lineColor ||
      old.isFirst != isFirst ||
      old.isLast != isLast ||
      old.dotRadius != dotRadius;
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Color _dotColor(PactTimelineMilestone m, BuildContext context) {
  if (m is PactCreatedMilestone || m is CurrentStateMilestone) {
    return CupertinoColors.activeBlue.resolveFrom(context);
  }
  if (m is PactConcludedMilestone) {
    return m.finalStatus == PactStatus.completed
        ? CupertinoColors.systemGreen.resolveFrom(context)
        : CupertinoColors.systemRed.resolveFrom(context);
  }
  if (m is ShowupGroupMilestone) {
    return CupertinoColors.systemGrey.resolveFrom(context);
  }
  final outcome = switch (m) {
    ShowupStreakMilestone s => s.outcome,
    NotedShowupMilestone n => n.outcome,
    SingleShowupMilestone s => s.outcome,
    _ => ShowupStatus.pending,
  };
  return outcome == ShowupStatus.done
      ? CupertinoColors.systemGreen.resolveFrom(context)
      : CupertinoColors.systemRed.resolveFrom(context);
}

double _verticalPadding(PactTimelineMilestone m) => switch (m) {
      PactCreatedMilestone _ || CurrentStateMilestone _ || PactConcludedMilestone _ => 14.0,
      ShowupGroupMilestone _ => 20.0,
      SingleShowupMilestone _ => 7.0,
      _ => 12.0,
    };

// ── Milestone content widgets ──────────────────────────────────────────────────

class _MilestoneContent extends StatelessWidget {
  final PactTimelineMilestone milestone;
  final AppLocalizations l10n;

  const _MilestoneContent({required this.milestone, required this.l10n});

  @override
  Widget build(BuildContext context) => switch (milestone) {
        PactCreatedMilestone m => _PactCreatedContent(m: m, l10n: l10n),
        CurrentStateMilestone m => _CurrentStateContent(m: m, l10n: l10n),
        PactConcludedMilestone m => _PactConcludedContent(m: m, l10n: l10n),
        ShowupStreakMilestone m => _StreakContent(m: m, l10n: l10n),
        ShowupGroupMilestone m => _GroupContent(m: m, l10n: l10n),
        NotedShowupMilestone m => _NotedShowupContent(m: m, l10n: l10n),
        SingleShowupMilestone m => _SingleShowupContent(m: m, l10n: l10n),
      };
}

// Anchors — label-first layout (unchanged from WU6).

class _PactCreatedContent extends StatelessWidget {
  final PactCreatedMilestone m;
  final AppLocalizations l10n;

  const _PactCreatedContent({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.timelinePactCreated, style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
          const SizedBox(height: 2),
          Text(m.habitName, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            l10n.pactPlannedUntil(formatLocaleDate(context, m.plannedEndDate)),
            style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
          ),
        ],
      );
}

class _CurrentStateContent extends StatelessWidget {
  final CurrentStateMilestone m;
  final AppLocalizations l10n;

  const _CurrentStateContent({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.timelineCurrentState, style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
          const SizedBox(height: 2),
          Text(l10n.timelineShowupsRemaining(m.showupsRemaining), style: const TextStyle(fontWeight: FontWeight.w600)),
          if (m.nextScheduledAt != null) ...[
            const SizedBox(height: 2),
            Text(
              l10n.timelineUpNext(formatLocaleDate(context, m.nextScheduledAt!)),
              style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
            ),
          ],
        ],
      );
}

class _PactConcludedContent extends StatelessWidget {
  final PactConcludedMilestone m;
  final AppLocalizations l10n;

  const _PactConcludedContent({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final title =
        m.finalStatus == PactStatus.completed ? l10n.timelinePactConcludedCompleted : l10n.timelinePactConcludedStopped;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          formatLocaleDate(context, m.concludedAt),
          style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
        ),
        if (m.note != null && m.note!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(m.note!, style: const TextStyle(fontSize: 13)),
        ],
      ],
    );
  }
}

// Showup milestones — date-above-status layout (WU6.1).

class _StreakContent extends StatelessWidget {
  final ShowupStreakMilestone m;
  final AppLocalizations l10n;

  const _StreakContent({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final dateRange = milestoneDateRange(context, m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dateRange != null) ...[
          Text(
            dateRange,
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: CupertinoColors.systemGrey),
          ),
          const SizedBox(height: 2),
        ],
        Text(milestoneTitle(l10n, m), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _GroupContent extends StatelessWidget {
  final ShowupGroupMilestone m;
  final AppLocalizations l10n;

  const _GroupContent({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final dateRange = milestoneDateRange(context, m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dateRange != null) ...[
          Text(
            dateRange,
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: CupertinoColors.systemGrey),
          ),
          const SizedBox(height: 2),
        ],
        Text(milestoneTitle(l10n, m), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _NotedShowupContent extends StatelessWidget {
  final NotedShowupMilestone m;
  final AppLocalizations l10n;

  const _NotedShowupContent({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatLocaleDate(context, m.scheduledAt),
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: CupertinoColors.systemGrey),
          ),
          const SizedBox(height: 2),
          Text(milestoneTitle(l10n, m), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(m.note, style: const TextStyle(fontSize: 13)),
        ],
      );
}

class _SingleShowupContent extends StatelessWidget {
  final SingleShowupMilestone m;
  final AppLocalizations l10n;

  const _SingleShowupContent({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatLocaleDate(context, m.scheduledAt),
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: CupertinoColors.systemGrey),
          ),
          const SizedBox(height: 2),
          Text(milestoneTitle(l10n, m), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      );
}
