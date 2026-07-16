import 'package:flutter/material.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_spine.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_state.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

// ── Public page widget ─────────────────────────────────────────────────────────

class PactTimelinePageAndroid extends StatelessWidget {
  final PactTimelineState state;

  /// Called when the user taps a tappable milestone ([NotedShowupMilestone] or
  /// [SingleShowupMilestone]). The screen uses this to fire analytics and navigate.
  final void Function(PactTimelineMilestone milestone)? onMilestoneTapped;

  /// Pact name known before [state.anchorStart] loads (e.g. carried over from the
  /// Pact Details screen), so the title doesn't flash a bare "Timeline" first.
  final String? initialHabitName;

  const PactTimelinePageAndroid({
    super.key,
    required this.state,
    this.onMilestoneTapped,
    this.initialHabitName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final habitName = state.anchorStart?.habitName ?? initialHabitName;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(
          habitName != null ? '$habitName – ${l10n.pactTimelineTitle}' : l10n.pactTimelineTitle,
        ),
      ),
      body: Column(
        children: [
          Container(height: 0.5, color: Theme.of(context).dividerColor),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.loadError != null
                    ? Center(child: Text(state.loadError.toString()))
                    : _TimelineList(state: state, onMilestoneTapped: onMilestoneTapped),
          ),
        ],
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

    // Section-header sentinel: placed at the exact tail-zone boundary from the grouper.
    // Do NOT infer from SingleShowupMilestone — that type also appears in the non-tail
    // zone when groupingThreshold == 1, which would produce a wrong position.
    final anchorOffset = state.anchorStart != null ? 1 : 0;
    final tailIdx = state.tailStartIndex;
    final sectionHeaderRawIdx = tailIdx > 0 && tailIdx < milestones.length ? anchorOffset + tailIdx : null;

    final displayItems = <(int, PactTimelineMilestone)?>[];
    for (int i = 0; i < rawItems.length; i++) {
      if (i == sectionHeaderRawIdx) displayItems.add(null);
      displayItems.add((i, rawItems[i]));
    }

    final children = [
      for (final entry in displayItems)
        if (entry == null)
          _SectionHeader(label: l10n.timelineRecentSection(state.tailPeriodInDays))
        else
          Builder(
            builder: (ctx) {
              final (rawIdx, m) = entry;
              return _SpineItem(
                milestone: m,
                isFirst: rawIdx == 0,
                isLast: rawIdx == rawItems.length - 1,
                isBeforeSectionHeader: sectionHeaderRawIdx != null && rawIdx == sectionHeaderRawIdx - 1,
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

class _SpineItem extends StatelessWidget {
  final PactTimelineMilestone milestone;
  final bool isFirst;
  final bool isLast;
  final bool isBeforeSectionHeader;
  final Color? topDotColor;
  final void Function(PactTimelineMilestone)? onTapped;

  const _SpineItem({
    required this.milestone,
    required this.isFirst,
    required this.isLast,
    this.isBeforeSectionHeader = false,
    this.topDotColor,
    this.onTapped,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = _dotColor(milestone, context);
    final isAnchor =
        milestone is PactCreatedMilestone || milestone is CurrentStateMilestone || milestone is PactConcludedMilestone;
    final isTappable = milestone is NotedShowupMilestone || milestone is SingleShowupMilestone;
    final showupId = switch (milestone) {
      NotedShowupMilestone m => m.showupId,
      SingleShowupMilestone m => m.showupId,
      _ => null,
    };
    final vertPad = timelineVerticalPadding(milestone);
    final extraBottomPad = isBeforeSectionHeader ? 12.0 : 0.0;
    // Cap-height midpoint of the first text line differs by label font size:
    // anchor labels are 13pt (half-line ≈ 7dp); all others use 16pt (≈ 9dp).
    final dotCenterY = vertPad + (isAnchor ? 7.0 : 9.0);

    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date column — golden ratio short side (~38.2% of non-spine width).
          Flexible(
            flex: 382,
            child: Padding(
              padding: EdgeInsets.only(top: vertPad, bottom: vertPad + extraBottomPad, left: 16, right: 6),
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
              painter: TimelineSpinePainter(
                dotColor: dotColor,
                topDotColor: topDotColor,
                isFirst: isFirst,
                isLast: isLast,
                dotRadius: isAnchor ? 6.0 : 4.0,
                dotCenterY: dotCenterY,
              ),
            ),
          ),
          // Label column — golden ratio long side (~61.8% of non-spine width).
          Flexible(
            flex: 618,
            child: Padding(
              padding: EdgeInsets.only(top: vertPad, bottom: vertPad + extraBottomPad, right: 16),
              child: _MilestoneLabelContent(milestone: milestone),
            ),
          ),
        ],
      ),
    );

    if (!isTappable || onTapped == null) return row;

    return InkWell(
      key: showupId != null ? Key('timeline-milestone-$showupId') : null,
      onTap: () => onTapped!(milestone),
      child: row,
    );
  }
}

// ── Section header (tail-zone divider) ────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 0.5, color: outline),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.4,
              color: onSurfaceVariant,
            ),
          ),
        ),
        Container(height: 0.5, color: outline),
      ],
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Color _dotColor(PactTimelineMilestone m, BuildContext context) {
  if (m is PactCreatedMilestone || m is CurrentStateMilestone) {
    return HabitLoopColors.primary;
  }
  if (m is PactConcludedMilestone) {
    return m.finalStatus == PactStatus.completed ? HabitLoopColors.success : HabitLoopColors.danger;
  }
  if (m is ShowupGroupMilestone) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
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
      ShowupStatus.done => HabitLoopColors.success,
      ShowupStatus.failed => HabitLoopColors.danger,
      ShowupStatus.pending => Theme.of(context).colorScheme.onSurfaceVariant,
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
      style: TextStyle(
        fontSize: 12,
        fontStyle: FontStyle.italic,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  String? _text(BuildContext context) => switch (milestone) {
        PactCreatedMilestone m => formatLocaleDate(m.sortAt),
        CurrentStateMilestone m => m.nextScheduledAt != null ? formatLocaleDate(m.nextScheduledAt!) : null,
        PactConcludedMilestone m => formatLocaleDate(m.concludedAt),
        ShowupStreakMilestone m => _dateRange(m.firstAt, m.lastAt),
        ShowupGroupMilestone m => _dateRange(m.firstAt, m.lastAt),
        NotedShowupMilestone m => formatLocaleDate(m.scheduledAt),
        SingleShowupMilestone m => formatLocaleDate(m.scheduledAt),
      };

  String _dateRange(DateTime first, DateTime last) {
    final a = formatLocaleDate(first);
    final b = formatLocaleDate(last);
    return first == last ? a : '$a – $b';
  }
}

// ── Label content (right of spine) ─────────────────────────────────────────────

class _MilestoneLabelContent extends StatelessWidget {
  final PactTimelineMilestone milestone;

  const _MilestoneLabelContent({required this.milestone});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (milestone) {
      PactCreatedMilestone m => _PactCreatedLabel(m: m, l10n: l10n),
      CurrentStateMilestone m => _CurrentStateLabel(m: m, l10n: l10n),
      PactConcludedMilestone m => _PactConcludedLabel(m: m, l10n: l10n),
      ShowupStreakMilestone m => _StreakLabel(m: m, l10n: l10n),
      ShowupGroupMilestone m => _GroupLabel(m: m, l10n: l10n),
      NotedShowupMilestone m => _NotedShowupLabel(m: m, l10n: l10n),
      SingleShowupMilestone m => _SingleShowupLabel(m: m, l10n: l10n),
    };
  }
}

// ── Anchor label widgets ───────────────────────────────────────────────────────

class _PactCreatedLabel extends StatelessWidget {
  final PactCreatedMilestone m;
  final AppLocalizations l10n;

  const _PactCreatedLabel({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.timelinePactCreated, style: TextStyle(fontSize: 13, color: muted)),
        const SizedBox(height: 2),
        Text(m.habitName, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          l10n.pactPlannedUntil(formatLocaleDate(m.plannedEndDate)),
          style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: muted),
        ),
      ],
    );
  }
}

class _CurrentStateLabel extends StatelessWidget {
  final CurrentStateMilestone m;
  final AppLocalizations l10n;

  const _CurrentStateLabel({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.timelineCurrentState, style: TextStyle(fontSize: 13, color: muted)),
        const SizedBox(height: 2),
        Text(l10n.timelineShowupsRemaining(m.showupsRemaining), style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
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
