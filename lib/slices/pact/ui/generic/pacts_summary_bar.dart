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

  // Computed each build from LayoutBuilder so the divider lands exactly at the
  // bottom edge of the collapsed sheet: minSize = (_maxHeaderHeight + 1) / bodyH.
  double _computedMinSize = 0.127; // reasonable fallback (≈ 97dp / 760dp body)

  double _computedMaxSize = 0.55; // reasonable fallback (= _expandedSize)

  double _dragStartSize = 0.0;
  double _dragStartGlobalY = 0.0;

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
    _collapse();
    await Future<void>.delayed(const Duration(milliseconds: 260));
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
      _expand();
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pactListViewModelProvider);
    final l10n = AppLocalizations.of(context)!;

    if (state.activeCount == 0 && state.doneCount == 0 && state.cancelledCount == 0 && state.archivedCount == 0) {
      return const SizedBox.shrink();
    }

    final summaryLines = [
      l10n.pactsActive(state.activeCount),
      l10n.pactsDone(state.doneCount),
      l10n.pactsCancelled(state.cancelledCount),
    ].join('\n');

    final allFiltered = state.filteredEntries;
    final unarchivedEntries = allFiltered.where((e) => !e.pact.archived).toList();
    final archivedEntries = allFiltered.where((e) => e.pact.archived).toList();

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final parentHeight = outerConstraints.maxHeight;
        // minSize positions the divider at the bottom of the collapsed sheet.
        final minSize =
            parentHeight > 0 ? ((_maxHeaderHeight + 1.0) / parentHeight).clamp(0.05, _expandedSize) : _computedMinSize;
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
                    const dividerH = 1.0;
                    final headerH = (innerConstraints.maxHeight - dividerH).clamp(0.0, _maxHeaderHeight);

                    return Column(
                      children: [
                        // ── Sticky: drag handle + pact counts ──
                        // DecoratedBox gives the header a slight drop-shadow over
                        // the list area, visually elevating it above the list.
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            height: headerH,
                            child: GestureDetector(
                              key: const Key('pacts-panel-drag-handle'),
                              onTap: _expand,
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragStart: (d) {
                                _dragStartSize = _controller.size;
                                _dragStartGlobalY = d.globalPosition.dy;
                              },
                              onVerticalDragUpdate: (d) {
                                if (parentHeight <= 0) return;
                                final delta = -(d.globalPosition.dy - _dragStartGlobalY) / parentHeight;
                                _controller.jumpTo(
                                  (_dragStartSize + delta).clamp(minSize, maxSize),
                                );
                              },
                              onVerticalDragEnd: (d) {
                                final target = pactsPickSnapTarget(
                                  velocity: d.velocity.pixelsPerSecond.dy,
                                  currentSize: _controller.size,
                                  snapSizes: snapSizes,
                                  maxSize: _computedMaxSize,
                                  minSize: _computedMinSize,
                                );
                                unawaited(_controller.animateTo(
                                  target,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                ));
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                                child: Column(
                                  // mainAxisSize.max: Column fills the SizedBox height so
                                  // Flexible(Align) never causes a layout overflow.
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 4,
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
                                          summaryLines,
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const Divider(height: dividerH),

                        // ── Scrollable pact list ──
                        // NotificationListener blocks ScrollNotification from reaching
                        // the Scaffold so the Material 3 AppBar elevation tint is not
                        // triggered when the sheet's list is scrolled.
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (_) => true,
                            child: CustomScrollView(
                              controller: scrollController,
                              slivers: [
                                // ── Title + add button ──
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            l10n.pactListTitle,
                                            style: Theme.of(context).textTheme.titleLarge,
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: _addPact,
                                          icon: const Icon(Icons.add, size: 18),
                                          label: Text(l10n.addPact),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // ── Filter chips ──
                                SliverToBoxAdapter(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children: [
                                        FilterChip(
                                          label: Text(l10n.filterActive),
                                          selected: state.activeFilters.contains(PactStatus.active),
                                          onSelected: (_) => ref
                                              .read(pactListViewModelProvider.notifier)
                                              .toggleFilter(PactStatus.active),
                                        ),
                                        const SizedBox(width: 8),
                                        FilterChip(
                                          label: Text(l10n.filterDone),
                                          selected: state.activeFilters.contains(PactStatus.completed),
                                          onSelected: (_) => ref
                                              .read(pactListViewModelProvider.notifier)
                                              .toggleFilter(PactStatus.completed),
                                        ),
                                        const SizedBox(width: 8),
                                        FilterChip(
                                          label: Text(l10n.filterCancelled),
                                          selected: state.activeFilters.contains(PactStatus.stopped),
                                          onSelected: (_) => ref
                                              .read(pactListViewModelProvider.notifier)
                                              .toggleFilter(PactStatus.stopped),
                                        ),
                                        // Archived chip animates in when first archived pact exists.
                                        AnimatedSize(
                                          duration: const Duration(milliseconds: 250),
                                          curve: Curves.easeInOut,
                                          child: state.archivedCount > 0
                                              ? Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const SizedBox(width: 8),
                                                    FilterChip(
                                                      key: const Key('archive-filter-chip'),
                                                      label: Text(l10n.filterArchived),
                                                      selected: state.showArchived,
                                                      onSelected: (_) {
                                                        ref.read(pactListViewModelProvider.notifier).toggleArchived();
                                                        if (!state.showArchived) _expandMax();
                                                      },
                                                    ),
                                                  ],
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // ── Pact list body ──
                                // All list content lives in a single SliverToBoxAdapter
                                // so that every widget (including show-archived-pacts-row
                                // and the archived section) is always part of the element
                                // tree regardless of viewport size.  This prevents
                                // integration-test finders from missing widgets that
                                // fall beyond the lazy sliver build window.
                                if (state.isLoading)
                                  SliverFillRemaining(
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(ctx).bottom),
                                      child: const Center(child: CircularProgressIndicator()),
                                    ),
                                  )
                                else if (unarchivedEntries.isEmpty && state.archivedCount == 0)
                                  SliverFillRemaining(
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(ctx).bottom),
                                      child: Center(child: Text(l10n.noPactsYet)),
                                    ),
                                  )
                                else
                                  SliverToBoxAdapter(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Unarchived pacts
                                        for (int i = 0; i < unarchivedEntries.length; i++) ...[
                                          if (i > 0) const Divider(height: 1, indent: 16),
                                          if (unarchivedEntries[i].pact.status == PactStatus.active)
                                            _PactTile(
                                              entry: unarchivedEntries[i],
                                              onTap: () => _navigateToPact(unarchivedEntries[i]),
                                            )
                                          else
                                            _SwipeablePactTile(
                                              key: ValueKey(unarchivedEntries[i].pact.id),
                                              entry: unarchivedEntries[i],
                                              onTap: () => _navigateToPact(unarchivedEntries[i]),
                                              onArchive: (pactId, archive) =>
                                                  ref.read(pactListViewModelProvider.notifier).archivePact(pactId, archive),
                                            ),
                                        ],

                                        // ── Show-archived toggle row ──
                                        if (state.archivedCount > 0)
                                          InkWell(
                                            key: const Key('show-archived-pacts-row'),
                                            onTap: () {
                                              ref.read(pactListViewModelProvider.notifier).toggleArchived();
                                              if (!state.showArchived) _expandMax();
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      l10n.showArchivedPacts(state.archivedCount),
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                            color: Theme.of(context).colorScheme.primary,
                                                          ),
                                                    ),
                                                  ),
                                                  AnimatedRotation(
                                                    turns: state.showArchived ? 0.5 : 0.0,
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

                                        // ── Archived pact section (animated in/out) ──
                                        if (state.archivedCount > 0)
                                          AnimatedSize(
                                            duration: const Duration(milliseconds: 250),
                                            curve: Curves.easeInOut,
                                            child: AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 250),
                                              child: archivedEntries.isEmpty
                                                  ? const SizedBox.shrink(key: ValueKey(false))
                                                  : Column(
                                                      key: const ValueKey(true),
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: archivedEntries
                                                          .map(
                                                            (entry) => Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                const Divider(height: 1, indent: 16),
                                                                _SwipeablePactTile(
                                                                  key: ValueKey(entry.pact.id),
                                                                  entry: entry,
                                                                  onTap: () => _navigateToPact(entry),
                                                                  onArchive: (pactId, archive) => ref
                                                                      .read(pactListViewModelProvider.notifier)
                                                                      .archivePact(pactId, archive),
                                                                ),
                                                              ],
                                                            ),
                                                          )
                                                          .toList(),
                                                    ),
                                            ),
                                          ),

                                        SizedBox(height: MediaQuery.viewPaddingOf(ctx).bottom),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
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

class _SwipeablePactTile extends StatefulWidget {
  final PactListEntry entry;
  final VoidCallback onTap;
  final Future<void> Function(String pactId, bool archive) onArchive;

  const _SwipeablePactTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onArchive,
  });

  @override
  State<_SwipeablePactTile> createState() => _SwipeablePactTileState();
}

class _SwipeablePactTileState extends State<_SwipeablePactTile> with SingleTickerProviderStateMixin {
  double _offset = 0.0;
  late final AnimationController _collapseController;
  late final Animation<double> _sizeAnim;

  static const double _actionWidth = 72.0;
  static const double _threshold = 36.0;

  @override
  void initState() {
    super.initState();
    _collapseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _sizeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _collapseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _collapseController.dispose();
    super.dispose();
  }

  void _settle(bool reveal) => setState(() => _offset = reveal ? -_actionWidth : 0.0);

  Future<void> _triggerArchive() async {
    // Collapse the tile first, then persist the change — avoids a visual jump
    // when the parent list rebuilds after the state update.
    await _collapseController.forward();
    if (mounted) await widget.onArchive(widget.entry.pact.id, !widget.entry.pact.archived);
  }

  @override
  Widget build(BuildContext context) {
    final pact = widget.entry.pact;
    final cs = Theme.of(context).colorScheme;

    return SizeTransition(
      sizeFactor: _sizeAnim,
      alignment: Alignment.topCenter,
      child: ClipRect(
        child: Stack(
          children: [
            // Archive action (beneath tile, revealed on swipe)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: _actionWidth,
                  child: ColoredBox(
                    color: cs.primaryContainer,
                    child: Center(
                      child: IconButton(
                        key: const Key('swipe-archive-button'),
                        onPressed: _triggerArchive,
                        icon: Icon(
                          pact.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                          color: cs.onPrimaryContainer,
                        ),
                        tooltip: null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Pact tile (slides left on drag to reveal action; opaque background
            // prevents the archive icon from showing through the tile).
            GestureDetector(
              onHorizontalDragUpdate: (d) {
                setState(() => _offset = (_offset + d.delta.dx).clamp(-_actionWidth, 0.0));
              },
              onHorizontalDragEnd: (d) => _settle(_offset < -_threshold),
              child: Transform.translate(
                offset: Offset(_offset, 0),
                // Material gives the ListTile a proper ink-splash ancestor
                // while also providing an opaque surface-color background so
                // the swipe action icon behind the tile stays hidden.
                child: Material(
                  color: cs.surface,
                  child: _PactTile(entry: widget.entry, onTap: widget.onTap),
                ),
              ),
            ),
          ],
        ),
      ),
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
      subtitle = next != null ? l10n.pactNextShowup(formatLocaleDate(context, next)) : '';
    } else if (pact.status == PactStatus.completed) {
      subtitle = l10n.pactEndedOn(formatLocaleDate(context, pact.endDate));
    } else {
      final cancelledStr = l10n.pactCancelledOn(formatLocaleDate(context, pact.stoppedAt ?? pact.endDate));
      subtitle = pact.stoppedAt != null
          ? '$cancelledStr\n${l10n.pactPlannedUntil(formatLocaleDate(context, pact.endDate))}'
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
