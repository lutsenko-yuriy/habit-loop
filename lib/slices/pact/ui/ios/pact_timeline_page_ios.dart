import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Theme;
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_state.dart';

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

class _TimelineList extends StatelessWidget {
  final PactTimelineState state;
  final void Function(PactTimelineMilestone)? onMilestoneTapped;

  const _TimelineList({required this.state, this.onMilestoneTapped});

  @override
  Widget build(BuildContext context) {
    final items = <PactTimelineMilestone>[
      if (state.anchorStart != null) state.anchorStart!,
      ...state.milestones,
      if (state.anchorEnd != null) state.anchorEnd!,
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _MilestoneTile(
        milestone: items[i],
        onTapped: onMilestoneTapped,
      ),
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  final PactTimelineMilestone milestone;
  final void Function(PactTimelineMilestone)? onTapped;

  const _MilestoneTile({required this.milestone, this.onTapped});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fill = CupertinoColors.tertiarySystemFill.resolveFrom(context);

    final isTappable = milestone is NotedShowupMilestone || milestone is SingleShowupMilestone;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: _MilestoneContent(milestone: milestone, l10n: l10n),
    );

    if (!isTappable || onTapped == null) return content;

    final showupId = switch (milestone) {
      NotedShowupMilestone m => m.showupId,
      SingleShowupMilestone m => m.showupId,
      _ => '',
    };

    return GestureDetector(
      key: Key('timeline-milestone-$showupId'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onTapped!(milestone),
      child: content,
    );
  }
}

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

class _PactCreatedContent extends StatelessWidget {
  final PactCreatedMilestone m;
  final AppLocalizations l10n;

  const _PactCreatedContent({required this.m, required this.l10n});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.timelinePactCreated,
              style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
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
          Text(l10n.timelineCurrentState,
              style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
          const SizedBox(height: 2),
          Text(l10n.timelineShowupsRemaining(m.showupsRemaining),
              style: const TextStyle(fontWeight: FontWeight.w600)),
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
    final title = m.finalStatus == PactStatus.completed
        ? l10n.timelinePactConcludedCompleted
        : l10n.timelinePactConcludedStopped;

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
        Text(milestoneTitle(l10n, m), style: const TextStyle(fontWeight: FontWeight.w600)),
        if (dateRange != null) ...[
          const SizedBox(height: 2),
          Text(dateRange, style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
        ],
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
        Text(milestoneTitle(l10n, m), style: const TextStyle(fontWeight: FontWeight.w600)),
        if (dateRange != null) ...[
          const SizedBox(height: 2),
          Text(dateRange, style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
        ],
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
          Text(milestoneTitle(l10n, m), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            formatLocaleDate(context, m.scheduledAt),
            style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
          ),
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
          Text(milestoneTitle(l10n, m), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            formatLocaleDate(context, m.scheduledAt),
            style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
          ),
        ],
      );
}
