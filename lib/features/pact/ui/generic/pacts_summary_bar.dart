import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/analytics/providers/analytics_providers.dart';
import 'package:habit_loop/features/dashboard/analytics/dashboard_screens.dart';
import 'package:habit_loop/features/pact/domain/pact_list_state.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_detail_screen.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_list_view_model.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';
import 'package:intl/intl.dart';

/// A persistent draggable panel at the bottom of the dashboard.
///
/// Uses [DraggableScrollableSheet] with a [CustomScrollView] so that the
/// sheet expands as the user drags, then scrolls the pact list once fully
/// open — avoiding any fixed-height Column overflow.
class PactsPanel extends ConsumerStatefulWidget {
  final AsyncCallback onCreatePact;

  const PactsPanel({super.key, required this.onCreatePact});

  @override
  ConsumerState<PactsPanel> createState() => _PactsPanelState();
}

class _PactsPanelState extends ConsumerState<PactsPanel> {
  late final DraggableScrollableController _controller;

  static const double _minSize = 0.12;
  static const double _expandedSize = 0.55;
  static const double _maxSize = 0.92;

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
        _minSize,
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
      ref
          .read(analyticsServiceProvider)
          .logScreenView(const DashboardAnalyticsScreen());
      ref.read(pactListViewModelProvider.notifier).load();
      ref.read(dashboardViewModelProvider.notifier).load();
    }
  }

  Future<void> _addPact() async {
    _collapse();
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    await widget.onCreatePact();
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

    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: _minSize,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      snap: true,
      snapSizes: const [_minSize, _expandedSize, _maxSize],
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
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // ── Drag handle + summary (collapsed peek) ──
              SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: _expand,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            summaryLines,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Title + add button (visible only when expanded) ──
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
                        selected:
                            state.activeFilters.contains(PactStatus.active),
                        onSelected: (_) => ref
                            .read(pactListViewModelProvider.notifier)
                            .toggleFilter(PactStatus.active),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(l10n.filterDone),
                        selected: state.activeFilters
                            .contains(PactStatus.completed),
                        onSelected: (_) => ref
                            .read(pactListViewModelProvider.notifier)
                            .toggleFilter(PactStatus.completed),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(l10n.filterCancelled),
                        selected:
                            state.activeFilters.contains(PactStatus.stopped),
                        onSelected: (_) => ref
                            .read(pactListViewModelProvider.notifier)
                            .toggleFilter(PactStatus.stopped),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 8),
              ),
              const SliverToBoxAdapter(
                child: Divider(height: 1),
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
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16),
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
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMd(locale);
    final pact = entry.pact;

    final String subtitle;
    if (pact.status == PactStatus.active) {
      final next = entry.nextShowupAt;
      subtitle =
          next != null ? l10n.pactNextShowup(dateFormat.format(next)) : '';
    } else if (pact.status == PactStatus.completed) {
      subtitle = l10n.pactEndedOn(dateFormat.format(pact.endDate));
    } else {
      subtitle = l10n.pactCancelledOn(dateFormat.format(pact.endDate));
    }

    final statusText = switch (pact.status) {
      PactStatus.active => l10n.pactStatusActive,
      PactStatus.completed => l10n.pactStatusCompleted,
      PactStatus.stopped => l10n.pactStatusStopped,
    };
    final statusColor = switch (pact.status) {
      PactStatus.active => HabitLoopColors.primary,
      PactStatus.completed => HabitLoopColors.success,
      PactStatus.stopped => HabitLoopColors.danger,
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
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
