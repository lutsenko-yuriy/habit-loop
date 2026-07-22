import 'package:flutter/foundation.dart' show AsyncCallback;
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_dots.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';
import 'package:habit_loop/theme/spacing.dart';

/// Minimum tap-target size (logical pixels) applied to the calendar-strip day
/// buttons — satisfies both Android's 48dp and iOS's 44pt guideline minimums
/// (`CHK-2026-07-20-heavy-8`).
const double _dayTapTargetMinSize = 48;

typedef DashboardShowupTileBuilder = Widget Function(
  BuildContext context,
  Showup showup,
  String habitName,
  VoidCallback onTap,
);

/// Shared dashboard body — calendar strip, empty states, and showup list.
/// Platform chrome (AppBar, FAB, navigation bar) lives in the enclosing Scaffold.
class DashboardBody extends StatelessWidget {
  final DashboardState state;
  final bool hasPacts;
  final ShowupStatusColors statusColors;

  /// Thin divider placed between the calendar strip and the content area.
  final Widget separator;

  /// Text color for the "no pacts" empty-state description.
  final Color noPactsTextColor;

  final AsyncCallback onCreatePact;
  final ValueChanged<int> onDaySelected;
  final Future<void> Function(String) onShowupTapped;
  final DashboardShowupTileBuilder buildShowupTile;

  /// Returns the platform-specific create-pact button inside the no-pacts CTA.
  final Widget Function(BuildContext context, AsyncCallback onCreatePact) buildNoPactsCta;

  const DashboardBody({
    super.key,
    required this.state,
    required this.hasPacts,
    required this.statusColors,
    required this.separator,
    required this.noPactsTextColor,
    required this.onCreatePact,
    required this.onDaySelected,
    required this.onShowupTapped,
    required this.buildShowupTile,
    required this.buildNoPactsCta,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _CalendarStrip(state: state, statusColors: statusColors, onDaySelected: onDaySelected),
        separator,
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: state.selectedDayShowups.isEmpty
                ? hasPacts
                    ? Center(
                        key: ValueKey('empty-${state.selectedDayIndex}'),
                        child: Text(l10n.noShowupsForDay),
                      )
                    : _NoPactsCta(
                        key: const Key('no-pacts-cta'),
                        l10n: l10n,
                        noPactsTextColor: noPactsTextColor,
                        onCreatePact: onCreatePact,
                        buildButton: buildNoPactsCta,
                      )
                : _ShowupList(
                    key: ValueKey('list-${state.selectedDayIndex}'),
                    showups: state.selectedDayShowups,
                    state: state,
                    onShowupTapped: onShowupTapped,
                    buildShowupTile: buildShowupTile,
                  ),
          ),
        ),
      ],
    );
  }
}

class _CalendarStrip extends StatelessWidget {
  final DashboardState state;
  final ShowupStatusColors statusColors;
  final ValueChanged<int> onDaySelected;

  const _CalendarStrip({
    required this.state,
    required this.statusColors,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final today = state.calendarDays.isNotEmpty ? state.calendarDays[state.todayIndex].date : DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s8),
      child: Row(
        children: List.generate(state.calendarDays.length, (index) {
          final entry = state.calendarDays[index];
          final isToday =
              entry.date.day == today.day && entry.date.month == today.month && entry.date.year == today.year;
          final isSelected = index == state.selectedDayIndex;
          final formattedDate = formatAccessibleDate(context, entry.date);
          final semanticLabel = isToday ? l10n.dashboardDayToday(formattedDate) : formattedDate;

          return Expanded(
            child: _CalendarDayCell(
              entry: entry,
              isToday: isToday,
              isSelected: isSelected,
              statusColors: statusColors,
              reminderOffsetByPactId: state.reminderOffsetByPactId,
              semanticLabel: semanticLabel,
              onTap: () => onDaySelected(index),
            ),
          );
        }),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final CalendarDayEntry entry;
  final bool isToday;
  final bool isSelected;
  final ShowupStatusColors statusColors;
  final Map<String, Duration?> reminderOffsetByPactId;
  final String semanticLabel;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.entry,
    required this.isToday,
    required this.isSelected,
    required this.statusColors,
    required this.reminderOffsetByPactId,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _dayTapTargetMinSize),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? cs.primary : null,
                      border: isToday && !isSelected ? Border.all(color: cs.primary, width: 2) : null,
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      child: Text(
                        '${entry.date.day}',
                        style: TextStyle(
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? cs.onPrimary : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  ShowupStatusDots(
                    showups: entry.showups,
                    date: entry.date,
                    colors: statusColors,
                    uiStates: deriveUiStates(entry.showups, reminderOffsetByPactId),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoPactsCta extends StatelessWidget {
  final AppLocalizations l10n;
  final Color noPactsTextColor;
  final AsyncCallback onCreatePact;
  final Widget Function(BuildContext, AsyncCallback) buildButton;

  const _NoPactsCta({
    super.key,
    required this.l10n,
    required this.noPactsTextColor,
    required this.onCreatePact,
    required this.buildButton,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.noPactsDescription,
            style: TextStyle(color: noPactsTextColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s20),
          buildButton(context, onCreatePact),
        ],
      ),
    );
  }
}

class _ShowupList extends StatelessWidget {
  final List<Showup> showups;
  final DashboardState state;
  final Future<void> Function(String) onShowupTapped;
  final DashboardShowupTileBuilder buildShowupTile;

  const _ShowupList({
    super.key,
    required this.showups,
    required this.state,
    required this.onShowupTapped,
    required this.buildShowupTile,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: showups.length,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      itemBuilder: (context, index) {
        final showup = showups[index];
        return buildShowupTile(
          context,
          showup,
          state.habitName(showup.pactId),
          () => onShowupTapped(showup.id),
        );
      },
    );
  }
}
