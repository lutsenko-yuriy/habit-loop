import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show AsyncCallback;
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:habit_loop/features/dashboard/domain/dashboard_state.dart';
import 'package:habit_loop/features/pact/ui/generic/pacts_summary_bar.dart' show PactsPanel;
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

class DashboardPageIos extends StatelessWidget {
  final DashboardState state;
  final bool hasPacts;
  final ValueChanged<int> onDaySelected;
  final AsyncCallback onCreatePact;
  final Future<void> Function(String) onShowupTapped;

  const DashboardPageIos({
    super.key,
    required this.state,
    required this.hasPacts,
    required this.onDaySelected,
    required this.onCreatePact,
    required this.onShowupTapped,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.dashboardTitle),
        trailing: hasPacts
            ? CupertinoButton(
                key: const Key('create-pact-button'),
                padding: EdgeInsets.zero,
                onPressed: onCreatePact,
                child: const Icon(CupertinoIcons.add),
              )
            : null,
      ),
      child: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              state.isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : !hasPacts
                      ? _EmptyState(l10n: l10n, onCreatePact: onCreatePact)
                      : _DashboardContent(
                          state: state,
                          l10n: l10n,
                          onDaySelected: onDaySelected,
                          onShowupTapped: onShowupTapped,
                        ),
              PactsPanel(onCreatePact: onCreatePact),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  final AsyncCallback onCreatePact;

  const _EmptyState({required this.l10n, required this.onCreatePact});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.noPactsYet,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noPactsDescription,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: onCreatePact,
              child: Text(l10n.createPact),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardState state;
  final AppLocalizations l10n;
  final ValueChanged<int> onDaySelected;
  final Future<void> Function(String) onShowupTapped;

  const _DashboardContent({
    required this.state,
    required this.l10n,
    required this.onDaySelected,
    required this.onShowupTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CalendarStrip(
          state: state,
          onDaySelected: onDaySelected,
        ),
        const _Separator(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: state.selectedDayShowups.isEmpty
                ? Center(
                    key: ValueKey('empty-${state.selectedDayIndex}'),
                    child: Text(l10n.noShowupsForDay),
                  )
                : _ShowupList(
                    key: ValueKey('list-${state.selectedDayIndex}'),
                    showups: state.selectedDayShowups,
                    state: state,
                    onShowupTapped: onShowupTapped,
                  ),
          ),
        ),
      ],
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      color: CupertinoColors.separator,
    );
  }
}

class _CalendarStrip extends StatelessWidget {
  final DashboardState state;
  final ValueChanged<int> onDaySelected;

  const _CalendarStrip({
    required this.state,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final today = state.calendarDays.isNotEmpty
        ? state.calendarDays[3].date
        : DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(state.calendarDays.length, (index) {
          final entry = state.calendarDays[index];
          final isToday = entry.date.day == today.day &&
              entry.date.month == today.month &&
              entry.date.year == today.year;
          final isSelected = index == state.selectedDayIndex;

          return GestureDetector(
            onTap: () => onDaySelected(index),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? CupertinoTheme.of(context).primaryColor
                        : null,
                    border: isToday && !isSelected
                        ? Border.all(
                            color: CupertinoTheme.of(context).primaryColor,
                            width: 2,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${entry.date.day}',
                    style: TextStyle(
                      fontWeight:
                          isToday ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? CupertinoColors.white
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _buildDots(entry.showups, entry.date),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDots(List<Showup> showups, DateTime date) {
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (showups.isEmpty) return const SizedBox.shrink();
    if (showups.length >= 4) {
      var done = 0, failed = 0, pending = 0;
      for (final s in showups) {
        if (s.status == ShowupStatus.done) {
          done++;
        } else if (s.status == ShowupStatus.failed) {
          failed++;
        } else {
          pending++;
        }
      }
      final overflowColor = pending > 0
          ? CupertinoColors.systemGrey
          : done >= failed
              ? CupertinoColors.activeGreen
              : CupertinoColors.destructiveRed;
      return Container(
        key: Key('status-dot-overflow-$dateKey'),
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: overflowColor,
        ),
      );
    }
    Widget dot(Showup s) => Container(
          key: Key('status-dot-${s.id}'),
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _dotColor(s.status),
          ),
        );
    if (showups.length <= 2) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: showups.map(dot).toList(),
      );
    }
    // 3 showups: 2 on top row, 1 on bottom row
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [dot(showups[0]), dot(showups[1])],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [dot(showups[2])],
        ),
      ],
    );
  }

  Color _dotColor(ShowupStatus status) {
    switch (status) {
      case ShowupStatus.done:
        return CupertinoColors.activeGreen;
      case ShowupStatus.failed:
        return CupertinoColors.destructiveRed;
      case ShowupStatus.pending:
        return CupertinoColors.systemGrey;
    }
  }
}

class _ShowupList extends StatelessWidget {
  final List<Showup> showups;
  final DashboardState state;
  final Future<void> Function(String) onShowupTapped;

  const _ShowupList({
    super.key,
    required this.showups,
    required this.state,
    required this.onShowupTapped,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: showups.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final showup = showups[index];
        return _ShowupTile(
          showup: showup,
          habitName: state.habitName(showup.pactId),
          onTap: () => onShowupTapped(showup.pactId),
        );
      },
    );
  }
}

class _ShowupTile extends StatelessWidget {
  final Showup showup;
  final String habitName;
  final VoidCallback onTap;

  const _ShowupTile({
    required this.showup,
    required this.habitName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusText = switch (showup.status) {
      ShowupStatus.done => l10n.showupDone,
      ShowupStatus.failed => l10n.showupFailed,
      ShowupStatus.pending => l10n.showupPending,
    };

    return CupertinoListTile(
      onTap: onTap,
      leading: Icon(
        switch (showup.status) {
          ShowupStatus.done => CupertinoIcons.check_mark_circled_solid,
          ShowupStatus.failed => CupertinoIcons.xmark_circle_fill,
          ShowupStatus.pending => CupertinoIcons.circle,
        },
        color: switch (showup.status) {
          ShowupStatus.done => CupertinoColors.activeGreen,
          ShowupStatus.failed => CupertinoColors.destructiveRed,
          ShowupStatus.pending => CupertinoColors.systemGrey,
        },
      ),
      title: Text(habitName),
      subtitle: Text('${showup.duration.inMinutes} min — $statusText'),
      trailing: const CupertinoListTileChevron(),
    );
  }
}
