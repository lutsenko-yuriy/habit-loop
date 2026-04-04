import 'package:flutter/foundation.dart' show AsyncCallback;
import 'package:flutter/material.dart';
import 'package:habit_loop/features/dashboard/domain/dashboard_state.dart';
import 'package:habit_loop/features/pact/ui/generic/pacts_summary_bar.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

class DashboardPageAndroid extends StatelessWidget {
  final DashboardState state;
  final bool hasPacts;
  final ValueChanged<int> onDaySelected;
  final AsyncCallback onCreatePact;
  final Future<void> Function(String) onShowupTapped;

  const DashboardPageAndroid({
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dashboardTitle)),
      floatingActionButton: hasPacts
          ? FloatingActionButton(
              key: const Key('create-pact-button'),
              onPressed: onCreatePact,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : !hasPacts
                    ? _EmptyState(l10n: l10n, onCreatePact: onCreatePact)
                    : _DashboardContent(
                        state: state,
                        l10n: l10n,
                        onDaySelected: onDaySelected,
                        onShowupTapped: onShowupTapped,
                      ),
          ),
          PactsSummaryBar(onCreatePact: onCreatePact),
        ],
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
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noPactsDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
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
        const Divider(height: 1),
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

          return _CalendarDay(
            entry: entry,
            isToday: isToday,
            isSelected: isSelected,
            onTap: () => onDaySelected(index),
          );
        }),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final CalendarDayEntry entry;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _CalendarDay({
    required this.entry,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? theme.colorScheme.primary : null,
              border: isToday && !isSelected
                  ? Border.all(color: theme.colorScheme.primary, width: 2)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry.date.day}',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.colorScheme.onPrimary : null,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _buildDots(entry.showups, entry.date, theme),
        ],
      ),
    );
  }

  Widget _buildDots(List<Showup> showups, DateTime date, ThemeData theme) {
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
          ? Colors.grey
          : done >= failed
              ? Colors.green
              : Colors.red;
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
            color: _dotColor(s.status, theme),
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

  Color _dotColor(ShowupStatus status, ThemeData theme) {
    switch (status) {
      case ShowupStatus.done:
        return Colors.green;
      case ShowupStatus.failed:
        return Colors.red;
      case ShowupStatus.pending:
        return Colors.grey;
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
    final icon = switch (showup.status) {
      ShowupStatus.done => Icons.check_circle,
      ShowupStatus.failed => Icons.cancel,
      ShowupStatus.pending => Icons.radio_button_unchecked,
    };
    final color = switch (showup.status) {
      ShowupStatus.done => Colors.green,
      ShowupStatus.failed => Colors.red,
      ShowupStatus.pending => Colors.grey,
    };
    final statusText = switch (showup.status) {
      ShowupStatus.done => l10n.showupDone,
      ShowupStatus.failed => l10n.showupFailed,
      ShowupStatus.pending => l10n.showupPending,
    };

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(habitName),
      subtitle: Text('${showup.duration.inMinutes} min — $statusText'),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
