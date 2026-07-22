import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/theme/spacing.dart';

const double _weekdayToggleTapTargetMinSize = 48;

// Card-based SlotSchedule editor. showTimePicker is platform-injected (null = cancelled).
// Test keys: slot-card-<i>, remove-slot-<i>, add-weekly-slot, add-monthly-slot,
//            weekday-<i>-<d>, time-chip-<i>, day-of-month-<i>.
class SlotScheduleEditor extends StatelessWidget {
  final SlotSchedule schedule;
  final ValueChanged<SlotSchedule> onChanged;
  final Future<Duration?> Function(BuildContext context, Duration current) showTimePicker;

  const SlotScheduleEditor({
    super.key,
    required this.schedule,
    required this.onChanged,
    required this.showTimePicker,
  });

  void _updateSlot(int index, ScheduleSlot slot) {
    final newSlots = List<ScheduleSlot>.of(schedule.slots);
    newSlots[index] = slot;
    onChanged(SlotSchedule(slots: newSlots));
  }

  void _removeSlot(int index) {
    final newSlots = List<ScheduleSlot>.of(schedule.slots)..removeAt(index);
    onChanged(SlotSchedule(slots: newSlots));
  }

  void _addWeeklySlot() {
    onChanged(SlotSchedule(slots: [
      ...schedule.slots,
      WeeklySlot(weekdays: {1, 2, 3, 4, 5}, timeOfDay: const Duration(hours: 8)),
    ]));
  }

  void _addMonthlySlot() {
    onChanged(SlotSchedule(slots: [
      ...schedule.slots,
      const MonthlySlot(dayOfMonth: 1, timeOfDay: Duration(hours: 8)),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canRemove = schedule.slots.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...schedule.slots.asMap().entries.map((entry) {
          final index = entry.key;
          final slot = entry.value;
          return _SlotCard(
            key: Key('slot-card-$index'),
            slot: slot,
            slotIndex: index,
            canRemove: canRemove,
            l10n: l10n,
            showTimePicker: showTimePicker,
            onChanged: (updated) => _updateSlot(index, updated),
            onRemove: () => _removeSlot(index),
          );
        }),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            TextButton.icon(
              key: const Key('add-weekly-slot'),
              onPressed: _addWeeklySlot,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.scheduleCardWeekly),
            ),
            const SizedBox(width: AppSpacing.s8),
            TextButton.icon(
              key: const Key('add-monthly-slot'),
              onPressed: _addMonthlySlot,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.scheduleCardMonthly),
            ),
          ],
        ),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  final ScheduleSlot slot;
  final int slotIndex;
  final bool canRemove;
  final AppLocalizations l10n;
  final Future<Duration?> Function(BuildContext, Duration) showTimePicker;
  final ValueChanged<ScheduleSlot> onChanged;
  final VoidCallback onRemove;

  const _SlotCard({
    super.key,
    required this.slot,
    required this.slotIndex,
    required this.canRemove,
    required this.l10n,
    required this.showTimePicker,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: switch (slot) {
        WeeklySlot() => _WeeklySlotContent(
            slot: slot as WeeklySlot,
            slotIndex: slotIndex,
            canRemove: canRemove,
            l10n: l10n,
            showTimePicker: showTimePicker,
            onChanged: onChanged,
            onRemove: onRemove,
          ),
        MonthlySlot() => _MonthlySlotContent(
            slot: slot as MonthlySlot,
            slotIndex: slotIndex,
            canRemove: canRemove,
            l10n: l10n,
            showTimePicker: showTimePicker,
            onChanged: onChanged,
            onRemove: onRemove,
          ),
      },
    );
  }
}

class _WeeklySlotContent extends StatelessWidget {
  final WeeklySlot slot;
  final int slotIndex;
  final bool canRemove;
  final AppLocalizations l10n;
  final Future<Duration?> Function(BuildContext, Duration) showTimePicker;
  final ValueChanged<ScheduleSlot> onChanged;
  final VoidCallback onRemove;

  const _WeeklySlotContent({
    required this.slot,
    required this.slotIndex,
    required this.canRemove,
    required this.l10n,
    required this.showTimePicker,
    required this.onChanged,
    required this.onRemove,
  });

  void _toggleWeekday(int weekday) {
    final current = Set<int>.of(slot.weekdays);
    if (current.contains(weekday)) {
      // Do not allow removing the last selected day.
      if (current.length <= 1) return;
      current.remove(weekday);
    } else {
      current.add(weekday);
    }
    onChanged(WeeklySlot(weekdays: current, timeOfDay: slot.timeOfDay));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_view_week, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpacing.s6),
            Text(l10n.scheduleCardWeekly, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            Visibility(
              visible: canRemove,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: IconButton(
                key: Key('remove-slot-$slotIndex'),
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                color: Theme.of(context).colorScheme.error,
                tooltip: l10n.scheduleRemoveSlotTooltip,
                onPressed: onRemove,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s10),
        _WeekdayToggleRow(
          slotIndex: slotIndex,
          selected: slot.weekdays,
          l10n: l10n,
          onToggle: _toggleWeekday,
        ),
        const SizedBox(height: AppSpacing.s10),
        Align(
          alignment: Alignment.centerRight,
          child: _TimeChipButton(
            slotIndex: slotIndex,
            time: slot.timeOfDay,
            showTimePicker: showTimePicker,
            onChanged: (newTime) => onChanged(WeeklySlot(weekdays: slot.weekdays, timeOfDay: newTime)),
          ),
        ),
      ],
    );
  }
}

class _MonthlySlotContent extends StatelessWidget {
  final MonthlySlot slot;
  final int slotIndex;
  final bool canRemove;
  final AppLocalizations l10n;
  final Future<Duration?> Function(BuildContext, Duration) showTimePicker;
  final ValueChanged<ScheduleSlot> onChanged;
  final VoidCallback onRemove;

  const _MonthlySlotContent({
    required this.slot,
    required this.slotIndex,
    required this.canRemove,
    required this.l10n,
    required this.showTimePicker,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s6),
            Text(l10n.scheduleCardMonthly, style: theme.textTheme.labelLarge),
            const Spacer(),
            Visibility(
              visible: canRemove,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: IconButton(
                key: Key('remove-slot-$slotIndex'),
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                color: theme.colorScheme.error,
                tooltip: l10n.scheduleRemoveSlotTooltip,
                onPressed: onRemove,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s10),
        Row(
          children: [
            Text(l10n.dayOfMonthLabel, style: theme.textTheme.bodyMedium),
            const SizedBox(width: AppSpacing.s12),
            DropdownButton<int>(
              key: Key('day-of-month-$slotIndex'),
              value: slot.dayOfMonth,
              isDense: true,
              items: List.generate(
                31,
                (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
              ),
              onChanged: (day) {
                if (day == null) return;
                onChanged(MonthlySlot(dayOfMonth: day, timeOfDay: slot.timeOfDay));
              },
            ),
            const Spacer(),
            _TimeChipButton(
              slotIndex: slotIndex,
              time: slot.timeOfDay,
              showTimePicker: showTimePicker,
              onChanged: (newTime) => onChanged(MonthlySlot(dayOfMonth: slot.dayOfMonth, timeOfDay: newTime)),
            ),
          ],
        ),
      ],
    );
  }
}

// 7 toggle buttons Mon..Sun (weekday keys: weekday-<slotIndex>-<weekday>).
class _WeekdayToggleRow extends StatelessWidget {
  final int slotIndex;
  final Set<int> selected;
  final AppLocalizations l10n;
  final ValueChanged<int> onToggle;

  const _WeekdayToggleRow({
    required this.slotIndex,
    required this.selected,
    required this.l10n,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayLabels = [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final weekday = i + 1;
        final isSelected = selected.contains(weekday);
        return Expanded(
          child: Semantics(
            label: formatWeekdayName(context, weekday),
            selected: isSelected,
            button: true,
            child: GestureDetector(
              key: Key('weekday-$slotIndex-$weekday'),
              onTap: () => onToggle(weekday),
              child: ExcludeSemantics(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _weekdayToggleTapTargetMinSize),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
                      decoration: BoxDecoration(
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          dayLabels[i],
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _TimeChipButton extends StatelessWidget {
  final int slotIndex;
  final Duration time;
  final Future<Duration?> Function(BuildContext, Duration) showTimePicker;
  final ValueChanged<Duration> onChanged;

  const _TimeChipButton({
    required this.slotIndex,
    required this.time,
    required this.showTimePicker,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tod = TimeOfDay(hour: time.inHours, minute: time.inMinutes % 60);
    return GestureDetector(
      key: Key('time-chip-$slotIndex'),
      onTap: () => unawaited(_pick(context)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          tod.format(context),
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(context, time);
    if (picked != null) {
      onChanged(picked);
    }
  }
}
