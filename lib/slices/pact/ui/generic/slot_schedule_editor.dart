import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

/// Platform-agnostic card-based editor for a [SlotSchedule].
///
/// Renders one card per [ScheduleSlot] in [schedule.slots] and provides
/// "Add weekly slot" / "Add monthly slot" action buttons.
///
/// The [showTimePicker] callback is injected by the platform-specific caller
/// so that iOS can use [CupertinoDatePicker] while Android uses Material's
/// [showTimePicker].  If the callback returns `null` the user cancelled and
/// the schedule is left unchanged.
///
/// Key contract for automated tests:
/// - Slot card container: `Key('slot-card-<index>')`
/// - Remove button: `Key('remove-slot-<index>')`
/// - Add-weekly button: `Key('add-weekly-slot')`
/// - Add-monthly button: `Key('add-monthly-slot')`
/// - Weekday toggle for slot i, weekday d: `Key('weekday-<i>-<d>')`
/// - Time chip for slot i: `Key('time-chip-<i>')`
/// - Day-of-month widget for slot i: `Key('day-of-month-<i>')`
class SlotScheduleEditor extends StatelessWidget {
  final SlotSchedule schedule;
  final ValueChanged<SlotSchedule> onChanged;

  /// Called when the user taps the time chip for a slot.
  ///
  /// Receives the current [Duration] and must return the user-selected
  /// [Duration], or `null` if the user cancelled.
  final Future<Duration?> Function(BuildContext context, Duration current) showTimePicker;

  const SlotScheduleEditor({
    super.key,
    required this.schedule,
    required this.onChanged,
    required this.showTimePicker,
  });

  // ---------------------------------------------------------------------------
  // Mutation helpers
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canRemove = schedule.slots.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Slot cards ---
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

        // --- Add buttons ---
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              key: const Key('add-weekly-slot'),
              onPressed: _addWeeklySlot,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.scheduleCardWeekly),
            ),
            const SizedBox(width: 8),
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

// ---------------------------------------------------------------------------
// Private — individual slot card
// ---------------------------------------------------------------------------

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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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

// ---------------------------------------------------------------------------
// Private — weekly slot content
// ---------------------------------------------------------------------------

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
        // Header row: label + remove button.
        Row(
          children: [
            Icon(Icons.calendar_view_week, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(l10n.scheduleCardWeekly, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            if (canRemove)
              IconButton(
                key: Key('remove-slot-$slotIndex'),
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                color: Theme.of(context).colorScheme.error,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onRemove,
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Weekday toggle row.
        _WeekdayToggleRow(
          slotIndex: slotIndex,
          selected: slot.weekdays,
          l10n: l10n,
          onToggle: _toggleWeekday,
        ),
        const SizedBox(height: 10),

        // Time chip.
        _TimeChipButton(
          slotIndex: slotIndex,
          time: slot.timeOfDay,
          showTimePicker: showTimePicker,
          onChanged: (newTime) => onChanged(WeeklySlot(weekdays: slot.weekdays, timeOfDay: newTime)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private — monthly slot content
// ---------------------------------------------------------------------------

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
        // Header row.
        Row(
          children: [
            Icon(Icons.calendar_month, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(l10n.scheduleCardMonthly, style: theme.textTheme.labelLarge),
            const Spacer(),
            if (canRemove)
              IconButton(
                key: Key('remove-slot-$slotIndex'),
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                color: theme.colorScheme.error,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onRemove,
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Day-of-month selector.
        Row(
          children: [
            Text(l10n.dayOfMonthLabel, style: theme.textTheme.bodyMedium),
            const SizedBox(width: 12),
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

            // Time chip.
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

// ---------------------------------------------------------------------------
// Private — weekday toggle row
// ---------------------------------------------------------------------------

/// 7 small toggle buttons, Mon..Sun (1..7 per [DateTime.weekday]).
///
/// Each button has a key `weekday-<slotIndex>-<weekday>`.
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
    // Short day names in order Mon..Sun (weekdays 1..7).
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
          child: GestureDetector(
            key: Key('weekday-$slotIndex-$weekday'),
            onTap: () => onToggle(weekday),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 6),
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
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Private — time chip button
// ---------------------------------------------------------------------------

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          tod.format(context),
          style: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
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
