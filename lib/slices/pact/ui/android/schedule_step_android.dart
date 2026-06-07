import 'package:flutter/material.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/option_tile.dart';
import 'package:habit_loop/slices/pact/ui/generic/schedule_details_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/slot_schedule_editor.dart';

class ScheduleStepAndroid extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<ScheduleType> onScheduleTypeChanged;
  final ValueChanged<ShowupSchedule> onScheduleChanged;

  const ScheduleStepAndroid({
    super.key,
    required this.state,
    required this.l10n,
    required this.onScheduleTypeChanged,
    required this.onScheduleChanged,
  });

  List<Widget> _scheduleOptions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          selectedColor: cs.primary,
          unselectedColor: cs.surfaceContainerHighest,
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
        Text(l10n.scheduleStep, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        if (!isSlot) ...[
          Text(l10n.scheduleTypeLabel),
          const SizedBox(height: 16),
          ..._scheduleOptions(context),
          const SizedBox(height: 24),
          if (state.scheduleType != null)
            ScheduleDetailsAndroid(
              state: state,
              l10n: l10n,
              onScheduleChanged: onScheduleChanged,
            ),
        ] else ...[
          const SizedBox(height: 8),
          ScheduleDetailsAndroid(
            state: state,
            l10n: l10n,
            onScheduleChanged: onScheduleChanged,
          ),
        ],
      ],
    );
  }
}

class ScheduleDetailsAndroid extends StatefulWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<ShowupSchedule> onScheduleChanged;

  const ScheduleDetailsAndroid({
    super.key,
    required this.state,
    required this.l10n,
    required this.onScheduleChanged,
  });

  @override
  State<ScheduleDetailsAndroid> createState() => ScheduleDetailsAndroidState();
}

class ScheduleDetailsAndroidState extends State<ScheduleDetailsAndroid>
    with ScheduleDetailsState<ScheduleDetailsAndroid> {
  @override
  PactCreationState get detailsState => widget.state;

  @override
  AppLocalizations get detailsL10n => widget.l10n;

  @override
  ValueChanged<ShowupSchedule> get detailsOnScheduleChanged => widget.onScheduleChanged;

  @override
  void initState() {
    super.initState();
    initScheduleDetails();
  }

  TimeOfDay _asTimeOfDay(Duration d) => TimeOfDay(hour: d.inHours, minute: d.inMinutes % 60);

  Duration _todToDuration(TimeOfDay t) => Duration(hours: t.hour, minutes: t.minute);

  /// Platform time picker for [SlotScheduleEditor] on Android.
  Future<Duration?> _showMaterialTimePicker(BuildContext ctx, Duration initial) async {
    final tod = TimeOfDay(hour: initial.inHours, minute: initial.inMinutes % 60);
    final picked = await showTimePicker(context: ctx, initialTime: tod);
    if (picked == null) return null;
    return Duration(hours: picked.hour, minutes: picked.minute);
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) {
    return showTimePicker(context: context, initialTime: initial);
  }

  @override
  Widget build(BuildContext context) => buildScheduleDetails(context);

  @override
  Widget buildDailyDetails() {
    final tod = _asTimeOfDay(dailyTime);
    return ListTile(
      title: Text(widget.l10n.timeOfDayLabel),
      trailing: TextButton(
        onPressed: () async {
          final t = await _pickTime(tod);
          if (t != null) {
            setState(() => dailyTime = _todToDuration(t));
            widget.onScheduleChanged(DailySchedule(timeOfDay: _todToDuration(t)));
          }
        },
        child: Text(tod.format(context)),
      ),
    );
  }

  @override
  Widget buildWeekdayDetails() {
    return Column(
      children: [
        ...weekdayEntries.asMap().entries.map((e) {
          final index = e.key;
          final entry = e.value;
          return ListTile(
            title: DropdownButton<int>(
              value: entry.weekday,
              items: List.generate(
                7,
                (i) => DropdownMenuItem(value: i + 1, child: Text(weekdayNameFor(i + 1))),
              ),
              onChanged: (wd) {
                if (wd == null) return;
                setState(() {
                  weekdayEntries[index] = WeekdayEntry(weekday: wd, timeOfDay: entry.timeOfDay);
                });
                widget.onScheduleChanged(WeekdaySchedule(entries: List.of(weekdayEntries)));
              },
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () async {
                    final t = await _pickTime(_asTimeOfDay(entry.timeOfDay));
                    if (t != null) {
                      setState(() {
                        weekdayEntries[index] = WeekdayEntry(weekday: entry.weekday, timeOfDay: _todToDuration(t));
                      });
                      widget.onScheduleChanged(WeekdaySchedule(entries: List.of(weekdayEntries)));
                    }
                  },
                  child: Text(_asTimeOfDay(entry.timeOfDay).format(context)),
                ),
                if (weekdayEntries.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error),
                    onPressed: () {
                      setState(() => weekdayEntries.removeAt(index));
                      widget.onScheduleChanged(WeekdaySchedule(entries: List.of(weekdayEntries)));
                    },
                  ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() {
              weekdayEntries.add(const WeekdayEntry(weekday: 1, timeOfDay: Duration(hours: 8)));
            });
          },
          icon: const Icon(Icons.add_circle_outline),
          label: Text(widget.l10n.addEntry),
        ),
      ],
    );
  }

  @override
  Widget buildMonthlyByWeekdayDetails() {
    return Column(
      children: [
        ...monthlyWeekdayEntries.asMap().entries.map((e) {
          final index = e.key;
          final entry = e.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 16),
                DropdownButton<int>(
                  value: entry.occurrence,
                  items: List.generate(
                    4,
                    (i) => DropdownMenuItem(value: i + 1, child: Text(occurrenceNameFor(i + 1))),
                  ),
                  onChanged: (occ) {
                    if (occ == null) return;
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
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: entry.weekday,
                  items: List.generate(
                    7,
                    (i) => DropdownMenuItem(value: i + 1, child: Text(weekdayNameFor(i + 1))),
                  ),
                  onChanged: (wd) {
                    if (wd == null) return;
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
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final t = await _pickTime(_asTimeOfDay(entry.timeOfDay));
                    if (t != null) {
                      setState(() {
                        monthlyWeekdayEntries[index] = MonthlyWeekdayEntry(
                          occurrence: entry.occurrence,
                          weekday: entry.weekday,
                          timeOfDay: _todToDuration(t),
                        );
                      });
                      widget.onScheduleChanged(MonthlyByWeekdaySchedule(entries: List.of(monthlyWeekdayEntries)));
                    }
                  },
                  child: Text(_asTimeOfDay(entry.timeOfDay).format(context)),
                ),
                if (monthlyWeekdayEntries.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error),
                    onPressed: () {
                      setState(() => monthlyWeekdayEntries.removeAt(index));
                      widget.onScheduleChanged(MonthlyByWeekdaySchedule(entries: List.of(monthlyWeekdayEntries)));
                    },
                  ),
                const SizedBox(width: 8),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() {
              monthlyWeekdayEntries
                  .add(const MonthlyWeekdayEntry(occurrence: 1, weekday: 1, timeOfDay: Duration(hours: 8)));
            });
          },
          icon: const Icon(Icons.add_circle_outline),
          label: Text(widget.l10n.addEntry),
        ),
      ],
    );
  }

  @override
  Widget buildMonthlyByDateDetails() {
    return Column(
      children: [
        ...monthlyDateEntries.asMap().entries.map((e) {
          final index = e.key;
          final entry = e.value;
          return ListTile(
            title: DropdownButton<int>(
              value: entry.dayOfMonth,
              items: List.generate(
                31,
                (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
              ),
              onChanged: (day) {
                if (day == null) return;
                setState(() {
                  monthlyDateEntries[index] = MonthlyDateEntry(dayOfMonth: day, timeOfDay: entry.timeOfDay);
                });
                widget.onScheduleChanged(MonthlyByDateSchedule(entries: List.of(monthlyDateEntries)));
              },
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () async {
                    final t = await _pickTime(_asTimeOfDay(entry.timeOfDay));
                    if (t != null) {
                      setState(() {
                        monthlyDateEntries[index] =
                            MonthlyDateEntry(dayOfMonth: entry.dayOfMonth, timeOfDay: _todToDuration(t));
                      });
                      widget.onScheduleChanged(MonthlyByDateSchedule(entries: List.of(monthlyDateEntries)));
                    }
                  },
                  child: Text(_asTimeOfDay(entry.timeOfDay).format(context)),
                ),
                if (monthlyDateEntries.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error),
                    onPressed: () {
                      setState(() => monthlyDateEntries.removeAt(index));
                      widget.onScheduleChanged(MonthlyByDateSchedule(entries: List.of(monthlyDateEntries)));
                    },
                  ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() {
              monthlyDateEntries.add(const MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 8)));
            });
          },
          icon: const Icon(Icons.add_circle_outline),
          label: Text(widget.l10n.addEntry),
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
      showTimePicker: _showMaterialTimePicker,
    );
  }
}
