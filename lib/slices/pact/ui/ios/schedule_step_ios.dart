import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/option_tile.dart';
import 'package:habit_loop/slices/pact/ui/generic/schedule_details_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/slot_schedule_editor.dart';
import 'package:habit_loop/slices/pact/ui/ios/cupertino_picker_sheet.dart';

class ScheduleStepIos extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<ScheduleType> onScheduleTypeChanged;
  final ValueChanged<ShowupSchedule> onScheduleChanged;

  const ScheduleStepIos({
    super.key,
    required this.state,
    required this.l10n,
    required this.onScheduleTypeChanged,
    required this.onScheduleChanged,
  });

  List<Widget> _scheduleOptions(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final unselectedColor = CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final options = <(ScheduleType, String)>[
      (ScheduleType.daily, l10n.scheduleDaily),
      (ScheduleType.weekday, l10n.scheduleWeekday),
      (ScheduleType.monthlyByWeekday, l10n.scheduleMonthlyByWeekday),
      (ScheduleType.monthlyByDate, l10n.scheduleMonthlyByDate),
    ];
    return options.map((option) {
      final (type, label) = option;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OptionTile(
          isSelected: state.scheduleType == type,
          label: label,
          onTap: () => onScheduleTypeChanged(type),
          selectedColor: primaryColor,
          unselectedColor: unselectedColor,
          selectedIcon: CupertinoIcons.check_mark_circled_solid,
          unselectedIcon: CupertinoIcons.circle,
          unselectedIconColor: CupertinoColors.systemGrey.resolveFrom(context),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isSlot = state.scheduleType == ScheduleType.slot;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(
          l10n.scheduleStep,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (!isSlot) ...[
          Text(l10n.scheduleTypeLabel),
          const SizedBox(height: 16),
          ..._scheduleOptions(context),
          const SizedBox(height: 24),
          if (state.scheduleType != null)
            ScheduleDetailsIos(
              state: state,
              l10n: l10n,
              onScheduleChanged: onScheduleChanged,
            ),
        ] else ...[
          const SizedBox(height: 8),
          ScheduleDetailsIos(
            state: state,
            l10n: l10n,
            onScheduleChanged: onScheduleChanged,
          ),
        ],
      ],
    );
  }
}

class ScheduleDetailsIos extends StatefulWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<ShowupSchedule> onScheduleChanged;

  const ScheduleDetailsIos({
    super.key,
    required this.state,
    required this.l10n,
    required this.onScheduleChanged,
  });

  @override
  State<ScheduleDetailsIos> createState() => ScheduleDetailsIosState();
}

class ScheduleDetailsIosState extends State<ScheduleDetailsIos> with ScheduleDetailsState<ScheduleDetailsIos> {
  @override
  PactCreationState get detailsState => widget.state;

  @override
  AppLocalizations get detailsL10n => widget.l10n;

  @override
  void initState() {
    super.initState();
    initScheduleDetails();
  }

  /// Platform time picker for [SlotScheduleEditor] on iOS.
  Future<Duration?> _showCupertinoTimePicker(BuildContext ctx, Duration initial) async {
    Duration? result;
    await showCupertinoPickerSheet(
      context: ctx,
      doneLabel: widget.l10n.pickerDone,
      pickerBuilder: (popupCtx) => CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        use24hFormat: MediaQuery.alwaysUse24HourFormatOf(popupCtx),
        initialDateTime: DateTime(2026, 1, 1, initial.inHours, initial.inMinutes % 60),
        onDateTimeChanged: (dt) {
          result = Duration(hours: dt.hour, minutes: dt.minute);
        },
      ),
    );
    return result;
  }

  void _showTimePicker(Duration initial, ValueChanged<Duration> onChanged) {
    unawaited(
      showCupertinoPickerSheet(
        context: context,
        doneLabel: widget.l10n.pickerDone,
        pickerBuilder: (ctx) => CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          use24hFormat: MediaQuery.alwaysUse24HourFormatOf(ctx),
          initialDateTime: DateTime(2026, 1, 1, initial.inHours, initial.inMinutes % 60),
          onDateTimeChanged: (dt) {
            onChanged(Duration(hours: dt.hour, minutes: dt.minute));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => buildScheduleDetails(context);

  @override
  Widget buildDailyDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimeRow(
          label: widget.l10n.timeOfDayLabel,
          time: dailyTime,
          onTap: () => _showTimePicker(dailyTime, (t) {
            setState(() => dailyTime = t);
            widget.onScheduleChanged(DailySchedule(timeOfDay: t));
          }),
        ),
      ],
    );
  }

  @override
  Widget buildWeekdayDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...weekdayEntries.asMap().entries.map((e) {
          final index = e.key;
          final entry = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _DropdownWeekday(
                    value: entry.weekday,
                    weekdayName: weekdayNameFor,
                    onChanged: (wd) {
                      setState(() {
                        weekdayEntries[index] = WeekdayEntry(weekday: wd, timeOfDay: entry.timeOfDay);
                      });
                      widget.onScheduleChanged(WeekdaySchedule(entries: List.of(weekdayEntries)));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                _TimeChip(
                  time: entry.timeOfDay,
                  onTap: () => _showTimePicker(entry.timeOfDay, (t) {
                    setState(() {
                      weekdayEntries[index] = WeekdayEntry(weekday: entry.weekday, timeOfDay: t);
                    });
                    widget.onScheduleChanged(WeekdaySchedule(entries: List.of(weekdayEntries)));
                  }),
                ),
                if (weekdayEntries.length > 1)
                  CupertinoButton(
                    padding: const EdgeInsets.only(left: 4),
                    child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.destructiveRed, size: 22),
                    onPressed: () {
                      setState(() => weekdayEntries.removeAt(index));
                      widget.onScheduleChanged(WeekdaySchedule(entries: List.of(weekdayEntries)));
                    },
                  ),
              ],
            ),
          );
        }),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            setState(() {
              weekdayEntries.add(const WeekdayEntry(weekday: 1, timeOfDay: Duration(hours: 8)));
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.add_circled, size: 20),
              const SizedBox(width: 4),
              Text(widget.l10n.addEntry),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget buildMonthlyByWeekdayDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...monthlyWeekdayEntries.asMap().entries.map((e) {
          final index = e.key;
          final entry = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _DropdownOccurrence(
                    value: entry.occurrence,
                    occurrenceName: occurrenceNameFor,
                    onChanged: (occ) {
                      setState(() {
                        monthlyWeekdayEntries[index] = MonthlyWeekdayEntry(
                          occurrence: occ,
                          weekday: entry.weekday,
                          timeOfDay: entry.timeOfDay,
                        );
                      });
                      widget.onScheduleChanged(MonthlyByWeekdaySchedule(entries: List.of(monthlyWeekdayEntries)));
                    },
                  ),
                ),
                Expanded(
                  child: _DropdownWeekday(
                    value: entry.weekday,
                    weekdayName: weekdayNameFor,
                    onChanged: (wd) {
                      setState(() {
                        monthlyWeekdayEntries[index] = MonthlyWeekdayEntry(
                          occurrence: entry.occurrence,
                          weekday: wd,
                          timeOfDay: entry.timeOfDay,
                        );
                      });
                      widget.onScheduleChanged(MonthlyByWeekdaySchedule(entries: List.of(monthlyWeekdayEntries)));
                    },
                  ),
                ),
                _TimeChip(
                  time: entry.timeOfDay,
                  onTap: () => _showTimePicker(entry.timeOfDay, (t) {
                    setState(() {
                      monthlyWeekdayEntries[index] = MonthlyWeekdayEntry(
                        occurrence: entry.occurrence,
                        weekday: entry.weekday,
                        timeOfDay: t,
                      );
                    });
                    widget.onScheduleChanged(MonthlyByWeekdaySchedule(entries: List.of(monthlyWeekdayEntries)));
                  }),
                ),
                const Spacer(),
                if (monthlyWeekdayEntries.length > 1)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.destructiveRed, size: 22),
                    onPressed: () {
                      setState(() => monthlyWeekdayEntries.removeAt(index));
                      widget.onScheduleChanged(MonthlyByWeekdaySchedule(entries: List.of(monthlyWeekdayEntries)));
                    },
                  ),
              ],
            ),
          );
        }),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            setState(() {
              monthlyWeekdayEntries
                  .add(const MonthlyWeekdayEntry(occurrence: 1, weekday: 1, timeOfDay: Duration(hours: 8)));
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.add_circled, size: 20),
              const SizedBox(width: 4),
              Text(widget.l10n.addEntry),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget buildMonthlyByDateDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...monthlyDateEntries.asMap().entries.map((e) {
          final index = e.key;
          final entry = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: _DayOfMonthPicker(
                    value: entry.dayOfMonth,
                    label: widget.l10n.dayOfMonthLabel,
                    onChanged: (day) {
                      setState(() {
                        monthlyDateEntries[index] = MonthlyDateEntry(dayOfMonth: day, timeOfDay: entry.timeOfDay);
                      });
                      widget.onScheduleChanged(MonthlyByDateSchedule(entries: List.of(monthlyDateEntries)));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _TimeChip(
                  time: entry.timeOfDay,
                  onTap: () => _showTimePicker(entry.timeOfDay, (t) {
                    setState(() {
                      monthlyDateEntries[index] = MonthlyDateEntry(dayOfMonth: entry.dayOfMonth, timeOfDay: t);
                    });
                    widget.onScheduleChanged(MonthlyByDateSchedule(entries: List.of(monthlyDateEntries)));
                  }),
                ),
                if (monthlyDateEntries.length > 1)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.destructiveRed, size: 22),
                    onPressed: () {
                      setState(() => monthlyDateEntries.removeAt(index));
                      widget.onScheduleChanged(MonthlyByDateSchedule(entries: List.of(monthlyDateEntries)));
                    },
                  ),
              ],
            ),
          );
        }),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            setState(() {
              monthlyDateEntries.add(const MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 8)));
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.add_circled, size: 20),
              const SizedBox(width: 4),
              Text(widget.l10n.addEntry),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget buildSlotDetails() {
    final slotSchedule =
        widget.state.schedule is SlotSchedule ? widget.state.schedule as SlotSchedule : const SlotSchedule(slots: []);
    return SlotScheduleEditor(
      schedule: slotSchedule,
      onChanged: widget.onScheduleChanged,
      showTimePicker: _showCupertinoTimePicker,
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final Duration time;
  final VoidCallback onTap;

  const _TimeRow({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              TimeOfDay(hour: time.inHours, minute: time.inMinutes % 60).format(context),
              style: TextStyle(
                color: CupertinoTheme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final Duration time;
  final VoidCallback onTap;

  const _TimeChip({
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          TimeOfDay(hour: time.inHours, minute: time.inMinutes % 60).format(context),
          style: TextStyle(
            color: CupertinoTheme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }
}

class _DropdownWeekday extends StatelessWidget {
  final int value;
  final String Function(int) weekdayName;
  final ValueChanged<int> onChanged;

  const _DropdownWeekday({
    required this.value,
    required this.weekdayName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      onPressed: () {
        unawaited(
          showCupertinoPickerSheet(
            context: context,
            doneLabel: AppLocalizations.of(context)!.pickerDone,
            pickerBuilder: (ctx) => CupertinoPicker(
              scrollController: FixedExtentScrollController(initialItem: value - 1),
              itemExtent: 40,
              onSelectedItemChanged: (i) => onChanged(i + 1),
              children: List.generate(
                7,
                (i) => Center(child: Text(weekdayName(i + 1))),
              ),
            ),
          ),
        );
      },
      child: Text(weekdayName(value)),
    );
  }
}

class _DropdownOccurrence extends StatelessWidget {
  final int value;
  final String Function(int) occurrenceName;
  final ValueChanged<int> onChanged;

  const _DropdownOccurrence({
    required this.value,
    required this.occurrenceName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      onPressed: () {
        unawaited(
          showCupertinoPickerSheet(
            context: context,
            doneLabel: AppLocalizations.of(context)!.pickerDone,
            pickerBuilder: (ctx) => CupertinoPicker(
              scrollController: FixedExtentScrollController(initialItem: value - 1),
              itemExtent: 40,
              onSelectedItemChanged: (i) => onChanged(i + 1),
              children: List.generate(
                4,
                (i) => Center(child: Text(occurrenceName(i + 1))),
              ),
            ),
          ),
        );
      },
      child: Text(occurrenceName(value)),
    );
  }
}

class _DayOfMonthPicker extends StatelessWidget {
  final int value;
  final String label;
  final ValueChanged<int> onChanged;

  const _DayOfMonthPicker({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        unawaited(
          showCupertinoPickerSheet(
            context: context,
            doneLabel: AppLocalizations.of(context)!.pickerDone,
            pickerBuilder: (ctx) => CupertinoPicker(
              scrollController: FixedExtentScrollController(initialItem: value - 1),
              itemExtent: 40,
              onSelectedItemChanged: (index) => onChanged(index + 1),
              children: List.generate(
                31,
                (i) => Center(child: Text('${i + 1}')),
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$label: $value'),
      ),
    );
  }
}
