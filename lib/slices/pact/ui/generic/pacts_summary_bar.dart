import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/analytics/dashboard_screens.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_refresh_signal.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_screen.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';
import 'package:habit_loop/theme/spacing.dart';

/// Returns the snap target for the pact panel drag gesture.
///
/// Velocity thresholds (±300 px/s) gate fast-flick shortcuts; slow releases
/// snap to the nearest position in [snapSizes].
@visibleForTesting
double pactsPickSnapTarget({
  required double velocity,
  required double currentSize,
  required List<double> snapSizes,
  required double maxSize,
  required double minSize,
}) {
  if (velocity < -300) return maxSize;
  if (velocity > 300) return minSize;
  return snapSizes.reduce(
    (a, b) => (a - currentSize).abs() < (b - currentSize).abs() ? a : b,
  );
}

/// A persistent draggable panel at the bottom of the dashboard.
///
/// The panel header (drag handle + pact counts) is always visible and never
/// scrolls. A divider separates it from the independently scrollable pact list.
///
/// [maxChildSize] is computed dynamically so the fully-expanded sheet top edge
/// sits at the calendar/content separator. A [NotificationListener] blocks
/// [ScrollNotification] from reaching the [Scaffold] so the Material 3 AppBar
/// elevation tint is not triggered.
class PactsPanel extends ConsumerStatefulWidget {
  final AsyncCallback onCreatePact;

  const PactsPanel({super.key, required this.onCreatePact});

  @override
  ConsumerState<PactsPanel> createState() => _PactsPanelState();
}

class _PactsPanelState extends ConsumerState<PactsPanel> {
  late final DraggableScrollableController _controller;

  static const double _expandedSize = 0.55;

  // Calendar strip: padding(24) + circle(40) + gap(4) + dots(6) + separator(1) = 75 dp.
  static const double _calendarHeight = 75.0;

  // Maximum height of the sticky header section, used by LayoutBuilder to
  // prevent Column overflow in the collapsed/test viewport.
  static const double _maxHeaderHeight = 96.0; // handle(14) + 3-line text(60) + padding(22)

  // Computed each build from LayoutBuilder so the separator lands exactly at the
  // bottom edge of the collapsed sheet: minSize = (_maxHeaderHeight + 0.5) / bodyH.
  double _computedMinSize = 0.127; // reasonable fallback (≈ 97dp / 760dp body)

  double _computedMaxSize = 0.55; // reasonable fallback (= _expandedSize)

  @override
  void initState() {
    super.initState();
    _controller = DraggableScrollableController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _expand() => _controller.animateTo(
        _expandedSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

  void _expandMax() => _controller.animateTo(
        _computedMaxSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

  void _collapse() => _controller.animateTo(
        _computedMinSize,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeIn,
      );

  Future<void> _navigateToPact(PactListEntry entry) async {
    if (!mounted) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Navigator.of(context).push(CupertinoPageRoute<void>(
        builder: (_) => PactDetailScreen(pactId: entry.pact.id),
      ));
    } else {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PactDetailScreen(pactId: entry.pact.id),
      ));
    }
    if (mounted) {
      unawaited(
        ref.read(analyticsServiceProvider).logScreenView(const DashboardAnalyticsScreen()),
      );
      unawaited(ref.read(pactListViewModelProvider.notifier).load());
      ref.read(dashboardRefreshSignalProvider.notifier).update((n) => n + 1);
    }
  }

  Future<void> _addPact() async {
    _collapse();
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    await widget.onCreatePact();
  }

  double _computeMaxSize(double parentHeight) {
    if (parentHeight <= 0) return _expandedSize;
    return ((parentHeight - _calendarHeight) / parentHeight).clamp(_expandedSize, 1.0);
  }

  void _toggleArchived(PactListState state) {
    final wasShowingArchived = state.showArchived;
    ref.read(pactListViewModelProvider.notifier).toggleArchived();
    if (!wasShowingArchived) _expandMax();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pactListViewModelProvider);
    final l10n = AppLocalizations.of(context)!;

    if (state.activeCount == 0 && state.doneCount == 0 && state.cancelledCount == 0 && state.archivedCount == 0) {
      return const SizedBox.shrink();
    }

    String archivedNote(String base, int total, int archived) {
      if (archived == 0) return base;
      if (archived == total) return '$base ${l10n.pactsAllArchived}';
      return '$base ${l10n.pactsArchivedParenthetical(archived)}';
    }

    final summaryLines = [
      l10n.pactsActive(state.activeCount),
      archivedNote(
        l10n.pactsDone(state.doneCount - state.archivedDoneCount),
        state.doneCount,
        state.archivedDoneCount,
      ),
      archivedNote(
        l10n.pactsCancelled(state.cancelledCount - state.archivedCancelledCount),
        state.cancelledCount,
        state.archivedCancelledCount,
      ),
    ].join('\n');

    final unarchivedEntries = state.filteredEntries.where((e) => !e.pact.archived).toList();
    // Computed from state.entries (not filteredEntries) so the list stays populated
    // when showArchived is toggled off — required for the exit animation to have content.
    final archivedEntries =
        state.entries.where((e) => e.pact.archived && state.activeFilters.contains(e.pact.status)).toList();
    final allEmpty = unarchivedEntries.isEmpty && archivedEntries.isEmpty && state.archivedCount == 0;

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final parentHeight = outerConstraints.maxHeight;
        // minSize positions the separator at the bottom of the collapsed sheet.
        final minSize =
            parentHeight > 0 ? ((_maxHeaderHeight + 0.5) / parentHeight).clamp(0.05, _expandedSize) : _computedMinSize;
        // Plain field updates (no setState) — safe inside LayoutBuilder.builder.
        _computedMinSize = minSize;
        final maxSize = _computeMaxSize(parentHeight);
        _computedMaxSize = maxSize;
        final snapSizes = <double>{minSize, _expandedSize, maxSize}.toList()..sort();

        return DraggableScrollableSheet(
          controller: _controller,
          initialChildSize: minSize,
          minChildSize: minSize,
          maxChildSize: maxSize,
          snap: true,
          snapSizes: snapSizes,
          builder: (ctx, scrollController) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15),
                    offset: const Offset(0, -4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                // Inner LayoutBuilder constrains the sticky header to the available
                // viewport height so the Column never overflows (e.g. in collapsed
                // state or in widget tests with a small surface).
                child: LayoutBuilder(
                  builder: (_, innerConstraints) {
                    const dividerH = 0.5;
                    final headerH = (innerConstraints.maxHeight - dividerH).clamp(0.0, _maxHeaderHeight);

                    return Column(
                      children: [
                        _PactsPanelHeader(
                          height: headerH,
                          summaryLines: summaryLines,
                          controller: _controller,
                          parentHeight: parentHeight,
                          minSize: minSize,
                          maxSize: maxSize,
                          snapSizes: snapSizes,
                          onTap: _expand,
                        ),

                        Container(height: dividerH, color: Theme.of(context).dividerColor),

                        // ── Scrollable pact list ──
                        Expanded(
                          child: _PactListBody(
                            scrollController: scrollController,
                            state: state,
                            unarchivedEntries: unarchivedEntries,
                            archivedEntries: archivedEntries,
                            allEmpty: allEmpty,
                            onAddPact: _addPact,
                            onToggleFilter: (status) =>
                                ref.read(pactListViewModelProvider.notifier).toggleFilter(status),
                            onToggleArchived: () => _toggleArchived(state),
                            onTapEntry: _navigateToPact,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Sticky header: drag handle + pact-count summary text.
///
/// Owns the drag gesture math (start/update/end) entirely — the parent
/// [_PactsPanelState] only supplies the [DraggableScrollableController] and
/// the current [minSize]/[maxSize]/[snapSizes]/[parentHeight] for this build.
class _PactsPanelHeader extends StatefulWidget {
  final double height;
  final String summaryLines;
  final DraggableScrollableController controller;
  final double parentHeight;
  final double minSize;
  final double maxSize;
  final List<double> snapSizes;
  final VoidCallback onTap;

  const _PactsPanelHeader({
    required this.height,
    required this.summaryLines,
    required this.controller,
    required this.parentHeight,
    required this.minSize,
    required this.maxSize,
    required this.snapSizes,
    required this.onTap,
  });

  @override
  State<_PactsPanelHeader> createState() => _PactsPanelHeaderState();
}

class _PactsPanelHeaderState extends State<_PactsPanelHeader> {
  double _dragStartSize = 0.0;
  double _dragStartGlobalY = 0.0;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: SizedBox(
        height: widget.height,
        child: GestureDetector(
          key: const Key('pacts-panel-drag-handle'),
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (d) {
            _dragStartSize = widget.controller.size;
            _dragStartGlobalY = d.globalPosition.dy;
          },
          onVerticalDragUpdate: (d) {
            if (widget.parentHeight <= 0) return;
            final delta = -(d.globalPosition.dy - _dragStartGlobalY) / widget.parentHeight;
            widget.controller.jumpTo(
              (_dragStartSize + delta).clamp(widget.minSize, widget.maxSize),
            );
          },
          onVerticalDragEnd: (d) {
            final target = pactsPickSnapTarget(
              velocity: d.velocity.pixelsPerSecond.dy,
              currentSize: widget.controller.size,
              snapSizes: widget.snapSizes,
              maxSize: widget.maxSize,
              minSize: widget.minSize,
            );
            unawaited(widget.controller.animateTo(
              target,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            ));
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, AppSpacing.md),
            child: Column(
              // mainAxisSize.max: Column fills the SizedBox height so
              // Flexible(Align) never causes a layout overflow.
              children: [
                Container(
                  width: 36,
                  height: AppSpacing.xs,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.summaryLines,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of status filter chips, plus the archived-pacts chip that
/// animates in once at least one archived pact exists.
class _PactFilterChipsRow extends StatelessWidget {
  final Set<PactStatus> activeFilters;
  final int archivedCount;
  final bool showArchived;
  final ValueChanged<PactStatus> onToggleFilter;
  final VoidCallback onToggleArchived;

  const _PactFilterChipsRow({
    required this.activeFilters,
    required this.archivedCount,
    required this.showArchived,
    required this.onToggleFilter,
    required this.onToggleArchived,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          FilterChip(
            label: Text(l10n.filterActive),
            selected: activeFilters.contains(PactStatus.active),
            onSelected: (_) => onToggleFilter(PactStatus.active),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            label: Text(l10n.filterDone),
            selected: activeFilters.contains(PactStatus.completed),
            onSelected: (_) => onToggleFilter(PactStatus.completed),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            label: Text(l10n.filterCancelled),
            selected: activeFilters.contains(PactStatus.stopped),
            onSelected: (_) => onToggleFilter(PactStatus.stopped),
          ),
          // Archived chip animates in when first archived pact exists.
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: archivedCount > 0
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: AppSpacing.sm),
                      FilterChip(
                        key: const Key('archive-filter-chip'),
                        label: Text(l10n.filterArchived),
                        selected: showArchived,
                        onSelected: (_) => onToggleArchived(),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// The scrollable body: title/add-pact row, filter chips, and the pact list
/// (loading / empty / populated), followed by the archived-pacts section.
class _PactListBody extends StatelessWidget {
  final ScrollController scrollController;
  final PactListState state;
  final List<PactListEntry> unarchivedEntries;
  final List<PactListEntry> archivedEntries;
  final bool allEmpty;
  final VoidCallback onAddPact;
  final ValueChanged<PactStatus> onToggleFilter;
  final VoidCallback onToggleArchived;
  final void Function(PactListEntry) onTapEntry;

  const _PactListBody({
    required this.scrollController,
    required this.state,
    required this.unarchivedEntries,
    required this.archivedEntries,
    required this.allEmpty,
    required this.onAddPact,
    required this.onToggleFilter,
    required this.onToggleArchived,
    required this.onTapEntry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // NotificationListener blocks ScrollNotification from reaching the
    // Scaffold so the Material 3 AppBar elevation tint is not triggered
    // when the sheet's list is scrolled.
    return NotificationListener<ScrollNotification>(
      onNotification: (_) => true,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          // ── Title + add button ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.pactListTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onAddPact,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.addPact),
                  ),
                ],
              ),
            ),
          ),

          // ── Filter chips ──
          SliverToBoxAdapter(
            child: _PactFilterChipsRow(
              activeFilters: state.activeFilters,
              archivedCount: state.archivedCount,
              showArchived: state.showArchived,
              onToggleFilter: onToggleFilter,
              onToggleArchived: onToggleArchived,
            ),
          ),

          // ── Pact list body ──
          if (state.isLoading)
            SliverFillRemaining(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom),
                child: const Center(child: CircularProgressIndicator()),
              ),
            )
          else if (allEmpty)
            SliverFillRemaining(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom),
                child: Center(child: Text(l10n.noPactsYet)),
              ),
            )
          else ...[
            if (unarchivedEntries.isNotEmpty)
              SliverList.separated(
                itemCount: unarchivedEntries.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: AppSpacing.lg),
                itemBuilder: (_, i) => _PactTile(
                  entry: unarchivedEntries[i],
                  onTap: () => onTapEntry(unarchivedEntries[i]),
                ),
              ),
            SliverToBoxAdapter(
              child: _ArchivedPactsSection(
                showDividerAboveToggle: unarchivedEntries.isNotEmpty,
                archivedCount: state.archivedCount,
                showArchived: state.showArchived,
                archivedEntries: archivedEntries,
                onToggleArchived: onToggleArchived,
                onTapEntry: onTapEntry,
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
            ),
          ],
        ],
      ),
    );
  }
}

/// Archived-pacts toggle row (visible once ≥1 archived pact exists) and the
/// animated list of archived entries it reveals.
class _ArchivedPactsSection extends StatelessWidget {
  final bool showDividerAboveToggle;
  final int archivedCount;
  final bool showArchived;
  final List<PactListEntry> archivedEntries;
  final VoidCallback onToggleArchived;
  final void Function(PactListEntry) onTapEntry;

  const _ArchivedPactsSection({
    required this.showDividerAboveToggle,
    required this.archivedCount,
    required this.showArchived,
    required this.archivedEntries,
    required this.onToggleArchived,
    required this.onTapEntry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (archivedCount > 0) ...[
          if (showDividerAboveToggle) const Divider(height: 1, indent: AppSpacing.lg),
          InkWell(
            key: const Key('show-archived-pacts-row'),
            onTap: onToggleArchived,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, AppSpacing.lg, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.archivedPacts(archivedCount),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: showArchived ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            alignment: Alignment.topCenter,
            child: child,
          ),
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          child: showArchived && archivedEntries.isNotEmpty
              ? Column(
                  key: const ValueKey('archived-pacts'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < archivedEntries.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: AppSpacing.lg),
                      _PactTile(
                        entry: archivedEntries[i],
                        onTap: () => onTapEntry(archivedEntries[i]),
                      ),
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _PactTile extends StatelessWidget {
  final PactListEntry entry;
  final VoidCallback onTap;

  const _PactTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pact = entry.pact;

    final String subtitle;
    if (pact.status == PactStatus.active) {
      final next = entry.nextShowupAt;
      subtitle = next != null ? l10n.pactNextShowup(formatLocaleDate(next)) : '';
    } else if (pact.status == PactStatus.completed) {
      subtitle = l10n.pactEndedOn(formatLocaleDate(pact.endDate));
    } else {
      final cancelledStr = l10n.pactCancelledOn(formatLocaleDate(pact.stoppedAt ?? pact.endDate));
      subtitle = pact.stoppedAt != null
          ? '$cancelledStr\n${l10n.pactPlannedUntil(formatLocaleDate(pact.endDate))}'
          : cancelledStr;
    }

    final statusText = pactStatusText(l10n, pact.status);
    final cs = Theme.of(context).colorScheme;
    final (badgeBg, badgeFg) = switch (pact.status) {
      PactStatus.active => (cs.primaryContainer, cs.onPrimaryContainer),
      PactStatus.completed => (cs.secondaryContainer, cs.onSecondaryContainer),
      PactStatus.stopped => (cs.errorContainer, cs.onErrorContainer),
    };

    return ListTile(
      onTap: onTap,
      title: Text(pact.habitName),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badgeFg,
              ),
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
