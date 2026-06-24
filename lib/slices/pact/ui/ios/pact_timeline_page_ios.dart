import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Theme;
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_state.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

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
      // bottom: false — the scroll view adds MediaQuery bottom inset to its own
      // padding so content scrolls under the home indicator naturally.
      child: SafeArea(
        bottom: false,
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

class _TimelineList extends StatelessWidget {
  final PactTimelineState state;
  final void Function(PactTimelineMilestone)? onMilestoneTapped;

  const _TimelineList({required this.state, this.onMilestoneTapped});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final milestones = state.milestones;
    final rawItems = <PactTimelineMilestone>[
      if (state.anchorStart != null) state.anchorStart!,
      ...milestones,
      if (state.anchorEnd != null) state.anchorEnd!,
    ];

    if (rawItems.isEmpty) return const SizedBox.shrink();

    // Section-header sentinel: appears before the first SingleShowupMilestone
    // when there is at least one non-single item above it.
    final firstSingleIdxInMilestones = milestones.indexWhere((m) => m is SingleShowupMilestone);
    final anchorOffset = state.anchorStart != null ? 1 : 0;
    final sectionHeaderRawIdx = firstSingleIdxInMilestones > 0 ? anchorOffset + firstSingleIdxInMilestones : null;

    // Build display list in chronological order (oldest at top, newest at bottom).
    // null = section-header slot; non-null = (rawIndex, milestone).
    final displayItems = <(int, PactTimelineMilestone)?>[];
    for (int i = 0; i < rawItems.length; i++) {
      if (i == sectionHeaderRawIdx) displayItems.add(null);
      displayItems.add((i, rawItems[i]));
    }

    // SingleChildScrollView + Column builds all items eagerly so maxScrollExtent
    // is exact and jumpTo(maxScrollExtent) in initState lands correctly.
    final children = [
      for (final entry in displayItems)
        if (entry == null)
          _SectionHeader(label: l10n.timelineRecentSection)
        else
          Builder(
            builder: (ctx) {
              final (rawIdx, m) = entry;
              return _SpineItem(
                milestone: m,
                isFirst: rawIdx == 0,
                isLast: rawIdx == rawItems.length - 1,
                topDotColor: rawIdx > 0 ? _dotColor(rawItems[rawIdx - 1], ctx) : null,
                onTapped: onMilestoneTapped,
              );
            },
          ),
    ];

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 8, bottom: 24 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

// ── Spine item (date | vertical spine | label — golden-ratio columns) ──────────
//
// The spine divides the row at the golden ratio: the date column takes ~38.2% of
// the non-spine width and the label column takes ~61.8%, mirroring the proportion
// a/(a+b) = b/(a+b+a) from the Golden Section. This puts the user's visual
// attention on the dot — the natural focal point — while keeping the date
// readable on the left and the label prominent on the right.

class _SpineItem extends StatelessWidget {
  final PactTimelineMilestone milestone;
  final bool isFirst;
  final bool isLast;
  final Color? topDotColor;
  final void Function(PactTimelineMilestone)? onTapped;

  const _SpineItem({
    required this.milestone,
    required this.isFirst,
    required this.isLast,
    this.topDotColor,
    this.onTapped,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dotColor = _dotColor(milestone, context);
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
          // Date column — golden ratio short side (~38.2% of non-spine width).
          Flexible(
            flex: 382,
            child: Padding(
              padding: EdgeInsets.only(top: vertPad, bottom: vertPad, left: 16, right: 6),
              child: Align(
                alignment: Alignment.topRight,
                child: _MilestoneDateContent(milestone: milestone),
              ),
            ),
          ),
          // Spine (dot + connecting line).
          SizedBox(
            width: 44,
            child: CustomPaint(
              painter: _SpinePainter(
                dotColor: dotColor,
                topDotColor: topDotColor,
                isFirst: isFirst,
                isLast: isLast,
                dotRadius: isAnchor ? 6.0 : 4.0,
              ),
            ),
          ),
          // Label column — golden ratio long side (~61.8% of non-spine width).
          Flexible(
            flex: 618,
            child: Padding(
              padding: EdgeInsets.only(top: vertPad, bottom: vertPad, right: 16),
              child: _MilestoneLabelContent(milestone: milestone, l10n: l10n),
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

// Shared horizontal center for the spine column — used by painter and section header.
const _kSpineX = 22.0;

class _SpinePainter extends CustomPainter {
  final Color dotColor;
  final Color? topDotColor;
  final bool isFirst;
  final bool isLast;
  final double dotRadius;

  static const _dotTopOffset = 16.0;

  const _SpinePainter({
    required this.dotColor,
    required this.topDotColor,
    required this.isFirst,
    required this.isLast,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dotCenterY = _dotTopOffset + dotRadius;
    const strokeWidth = 1.5;

    if (!isFirst && topDotColor != null) {
      const top = 0.0;
      final bottom = dotCenterY - dotRadius - 1;
      if (bottom > top) {
        canvas.drawLine(
          const Offset(_kSpineX, top),
          Offset(_kSpineX, bottom),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [topDotColor!, dotColor],
            ).createShader(Rect.fromLTRB(0, top, 1, bottom))
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    if (!isLast) {
      canvas.drawLine(
        Offset(_kSpineX, dotCenterY + dotRadius + 1),
        Offset(_kSpineX, size.height),
        Paint()
          ..color = dotColor
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(Offset(_kSpineX, dotCenterY), dotRadius, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(_SpinePainter old) =>
      old.dotColor != dotColor ||
      old.topDotColor != topDotColor ||
      old.isFirst != isFirst ||
      old.isLast != isLast ||
      old.dotRadius != dotRadius;
}

// ── Section header (tail-zone divider) ────────────────────────────────────────

// Subtle section divider: neutral grey spine line + small dot + label in the right column.
class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final grey = CupertinoColors.systemGrey.resolveFrom(context).withValues(alpha: 0.5);
    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(flex: 382),
          SizedBox(
            width: 44,
            height: 36,
            child: CustomPaint(
              painter: _SectionHeaderLinePainter(color: grey),
            ),
          ),
          Flexible(
            flex: 618,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 0.4,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeaderLinePainter extends CustomPainter {
  final Color color;
  const _SectionHeaderLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(_kSpineX, 0), Offset(_kSpineX, size.height), paint);
    canvas.drawCircle(Offset(_kSpineX, size.height / 2), 3.0, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SectionHeaderLinePainter old) => old.color != color;
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Color _dotColor(PactTimelineMilestone m, BuildContext context) {
  if (m is PactCreatedMilestone || m is CurrentStateMilestone) {
    return HabitLoopColors.primary;
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
  return _outcomeColor(outcome, context);
}

Color _outcomeColor(ShowupStatus outcome, BuildContext context) => switch (outcome) {
      ShowupStatus.done => CupertinoColors.systemGreen.resolveFrom(context),
      ShowupStatus.failed => CupertinoColors.systemRed.resolveFrom(context),
      ShowupStatus.pending => CupertinoColors.systemGrey.resolveFrom(context),
    };

double _verticalPadding(PactTimelineMilestone m) => switch (m) {
      PactCreatedMilestone _ || CurrentStateMilestone _ || PactConcludedMilestone _ => 14.0,
      ShowupGroupMilestone _ => 20.0,
      SingleShowupMilestone _ => 7.0,
      _ => 12.0,
    };

// ── Date content (left of spine) ───────────────────────────────────────────────

class _MilestoneDateContent extends StatelessWidget {
  final PactTimelineMilestone milestone;

  const _MilestoneDateContent({required this.milestone});

  @override
  Widget build(BuildContext context) {
    final text = _text(context);
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: CupertinoColors.systemGrey),
    );
  }

  String? _text(BuildContext context) => switch (milestone) {
        PactCreatedMilestone m => formatLocaleDate(m.sortAt),
        CurrentStateMilestone m => m.nextScheduledAt != null ? formatLocaleDate(m.nextScheduledAt!) : null,
        PactConcludedMilestone m => formatLocaleDate(m.concludedAt),
        ShowupStreakMilestone m => _dateRange(context, m.firstAt, m.lastAt),
        ShowupGroupMilestone m => _dateRange(context, m.firstAt, m.lastAt),
        NotedShowupMilestone m => formatLocaleDate(m.scheduledAt),
        SingleShowupMilestone m => formatLocaleDate(m.scheduledAt),
      };

  String _dateRange(BuildContext context, DateTime first, DateTime last) {
    final a = formatLocaleDate(first);
    final b = formatLocaleDate(last);
    return first == last ? a : '$a – $b';
  }
}

// ── Label content (right of spine) ─────────────────────────────────────────────

class _MilestoneLabelContent extends StatelessWidget {
  final PactTimelineMilestone milestone;
  final AppLocalizations l10n;

  const _MilestoneLabelContent({required this.milestone, required this.l10n});

  @override
  Widget build(BuildContext context) => switch (milestone) {
        PactCreatedMilestone m => _PactCreatedLabel(m: m, l10n: l10n),
        CurrentStateMilestone m => _CurrentStateLabel(m: m, l10n: l10n),
        PactConcludedMilestone m => _PactConcludedLabel(m: m, l10n: l10n),
        ShowupStreakMilestone m => _StreakLabel(m: m, l10n: l10n),
        ShowupGroupMilestone m => _GroupLabel(m: m, l10n: l10n),
        NotedShowupMilestone m => _NotedShowupLabel(m: m, l10n: l10n),
        SingleShowupMilestone m => _SingleShowupLabel(m: m, l10n: l10n),
      };
}

// ── Anchor label widgets ───────────────────────────────────────────────────────

class _PactCreatedLabel extends StatelessWidget {
  final PactCreatedMilestone m;
  final AppLocalizations l10n;

  const _PactCreatedLabel({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.timelinePactCreated, style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
          const SizedBox(height: 2),
          Text(m.habitName, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            l10n.pactPlannedUntil(formatLocaleDate(m.plannedEndDate)),
            style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: CupertinoColors.systemGrey),
          ),
        ],
      );
}

class _CurrentStateLabel extends StatelessWidget {
  final CurrentStateMilestone m;
  final AppLocalizations l10n;

  const _CurrentStateLabel({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.timelineCurrentState, style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
          const SizedBox(height: 2),
          Text(l10n.timelineShowupsRemaining(m.showupsRemaining), style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );
}

class _PactConcludedLabel extends StatelessWidget {
  final PactConcludedMilestone m;
  final AppLocalizations l10n;

  const _PactConcludedLabel({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final title =
        m.finalStatus == PactStatus.completed ? l10n.timelinePactConcludedCompleted : l10n.timelinePactConcludedStopped;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (m.note != null && m.note!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(m.note!, style: const TextStyle(fontSize: 13)),
        ],
      ],
    );
  }
}

// ── Showup milestone label widgets ─────────────────────────────────────────────

class _StreakLabel extends StatelessWidget {
  final ShowupStreakMilestone m;
  final AppLocalizations l10n;

  const _StreakLabel({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) => Text(
        milestoneTitle(l10n, m),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _outcomeColor(m.outcome, context)),
      );
}

class _GroupLabel extends StatelessWidget {
  final ShowupGroupMilestone m;
  final AppLocalizations l10n;

  const _GroupLabel({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) =>
      Text(milestoneTitle(l10n, m), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));
}

class _NotedShowupLabel extends StatelessWidget {
  final NotedShowupMilestone m;
  final AppLocalizations l10n;

  const _NotedShowupLabel({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            milestoneTitle(l10n, m),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _outcomeColor(m.outcome, context)),
          ),
          const SizedBox(height: 4),
          Text(m.note, style: const TextStyle(fontSize: 13)),
        ],
      );
}

class _SingleShowupLabel extends StatelessWidget {
  final SingleShowupMilestone m;
  final AppLocalizations l10n;

  const _SingleShowupLabel({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) => Text(
        milestoneTitle(l10n, m),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _outcomeColor(m.outcome, context)),
      );
}
