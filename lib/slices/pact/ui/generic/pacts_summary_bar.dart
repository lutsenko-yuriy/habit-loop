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

    if (state.activeCount == 0 && state.doneCount == 0 && state.cancelledCount == 0) {
      return const SizedBox.shrink();
    }

    final summaryLines = [
      l10n.pactsActive(state.activeCount),
      l10n.pactsDone(state.doneCount),
      l10n.pactsCancelled(state.cancelledCount),
    ].join('\n');

    final entries = state.filteredEntries;

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final parentHeight = outerConstraints.maxHeight;
        // minSize positions the divider at the bottom of the collapsed sheet.
        final minSize =
            parentHeight > 0 ? ((_maxHeaderHeight + 1.0) / parentHeight).clamp(0.05, _expandedSize) : _computedMinSize;
        // Plain field update (no setState) — safe inside LayoutBuilder.builder.
        _computedMinSize = minSize;
        final maxSize = _computeMaxSize(parentHeight);
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
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            height: headerH,
                            child: GestureDetector(
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
                                final velocity = d.velocity.pixelsPerSecond.dy;
                                if (velocity < -300) {
                                  _expand();
                                } else if (velocity > 300) {
                                  _collapse();
                                } else {
                                  final current = _controller.size;
                                  final snap = snapSizes.reduce(
                                    (a, b) => (a - current).abs() < (b - current).abs() ? a : b,
                                  );
                                  unawaited(_controller.animateTo(
                                    snap,
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                  ));
                                }
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
                                      ],
                                    ),
                                  ),
                                ),

                                // ── Pact list ──
                                if (state.isLoading)
                                  SliverFillRemaining(
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(ctx).bottom),
                                      child: const Center(child: CircularProgressIndicator()),
                                    ),
                                  )
                                else if (entries.isEmpty)
                                  SliverFillRemaining(
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(ctx).bottom),
                                      child: Center(child: Text(l10n.noPactsYet)),
                                    ),
                                  )
                                else
                                  SliverList.separated(
                                    itemCount: entries.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                                    itemBuilder: (context, index) {
                                      final entry = entries[index];
                                      return _PactTile(
                                        entry: entry,
                                        onTap: () => _navigateToPact(entry),
                                      );
                                    },
                                  ),
                                SliverToBoxAdapter(
                                  child: SizedBox(height: MediaQuery.viewPaddingOf(ctx).bottom),
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
