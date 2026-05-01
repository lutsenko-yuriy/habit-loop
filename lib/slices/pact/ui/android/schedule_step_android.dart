import 'package:flutter/material.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_formatters.dart' as pf;

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
    final theme = Theme.of(context);
    final options = <(ScheduleType, String)>[
      (ScheduleType.daily, l10n.scheduleDaily),
      (ScheduleType.weekday, l10n.scheduleWeekday),
      (ScheduleType.monthlyByWeekday, l10n.scheduleMonthlyByWeekday),
      (ScheduleType.monthlyByDate, l10n.scheduleMonthlyByDate),
    ];

    return options.map((option) {
      final (type, label) = option;
      final isSelected = state.scheduleType == type;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected ? BorderSide(color: theme.colorScheme.primary, width: 2) : BorderSide.none,
          ),
          tileColor: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : theme.colorScheme.surfaceContainerHighest,
          leading: Icon(
            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(label),
          onTap: () => onScheduleTypeChanged(type),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(l10n.scheduleStep, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
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

class ScheduleDetailsAndroidState extends State<ScheduleDetailsAndroid> {
  late TimeOfDay _dailyTime;
  late List<WeekdayEntry> _weekdayEntries;
  late List<MonthlyWeekdayEntry> _monthlyWeekdayEntries;
  late List<MonthlyDateEntry> _monthlyDateEntries;

  @override
  void initState() {
    super.initState();
    final schedule = widget.state.schedule;
    if (schedule is DailySchedule) {
      _dailyTime = TimeOfDay(hour: schedule.timeOfDay.inHours, minute: schedule.timeOfDay.inMinutes % 60);
    } else {
      _dailyTime = const TimeOfDay(hour: 8, minute: 0);
    }
    if (schedule is WeekdaySchedule) {
      _weekdayEntries = List.of(schedule.entries);
    } else {
      _weekdayEntries = [
        const WeekdayEntry(weekday: 1, timeOfDay: Duration(hours: 8)),
      ];
    }
    if (schedule is MonthlyByWeekdaySchedule) {
      _monthlyWeekdayEntries = List.of(schedule.entries);
    } else {
      _monthlyWeekdayEntries = [
        const MonthlyWeekdayEntry(occurrence: 1, weekday: 1, timeOfDay: Duration(hours: 8)),
      ];
    }
    if (schedule is MonthlyByDateSchedule) {
      _monthlyDateEntries = List.of(schedule.entries);
    } else {
      _monthlyDateEntries = [
        const MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 8)),
      ];
    }
  }

  String _weekdayName(int weekday) => pf.weekdayName(widget.l10n, weekday);

  String _occurrenceName(int occurrence) => pf.occurrenceName(widget.l10n, occurrence);

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) {
    return showTimePicker(context: context, initialTime: initial);
  }

  Duration _todToDuration(TimeOfDay t) => Duration(hours: t.hour, minutes: t.minute);

  TimeOfDay _durationToTod(Duration d) => TimeOfDay(hour: d.inHours, minute: d.inMinutes % 60);

  @override
  Widget build(BuildContext context) {
    switch (widget.state.scheduleType!) {
      case ScheduleType.daily:
        return _buildDaily();
      case ScheduleType.weekday:
        return _buildWeekday();
      case ScheduleType.monthlyByWeekday:
        return _buildMonthlyByWeekday();
      case ScheduleType.monthlyByDate:
        return _buildMonthlyByDate();
    }
  }

  Widget _buildDaily() {
    return ListTile(
      title: Text(widget.l10n.timeOfDayLabel),
      trailing: TextButton(
        onPressed: () async {
          final t = await _pickTime(_dailyTime);
          if (t != null) {
            setState(() => _dailyTime = t);
            widget.onScheduleChanged(DailySchedule(timeOfDay: _todToDuration(t)));
          }
        },
        child: Text(_dailyTime.format(context)),
      ),
    );
  }

  Widget _buildWeekday() {
    return Column(
      children: [
        ..._weekdayEntries.asMap().entries.map((e) {
          final index = e.key;
          final entry = e.value;
          return ListTile(
            title: DropdownButton<int>(
              value: entry.weekday,
              items: List.generate(
                7,
                (i) => DropdownMenuItem(value: i + 1, child: Text(_weekdayName(i + 1))),
              ),
              onChanged: (wd) {
                if (wd == null) return;
                setState(() {
                  _weekdayEntries[index] = WeekdayEntry(weekday: wd, timeOfDay: entry.timeOfDay);
                });
                widget.onScheduleChanged(WeekdaySchedule(entries: List.of(_weekdayEntries)));
              },
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () async {
                    final t = await _pickTime(_durationToTod(entry.timeOfDay));
                    if (t != null) {
                      setState(() {
                        _weekdayEntries[index] = WeekdayEntry(weekday: entry.weekday, timeOfDay: _todToDuration(t));
                      });
                      widget.onScheduleChanged(WeekdaySchedule(entries: List.of(_weekdayEntries)));
                    }
                  },
                  child: Text(_durationToTod(entry.timeOfDay).format(context)),
                ),
                if (_weekdayEntries.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error),
                    onPressed: () {
                      setState(() => _weekdayEntries.removeAt(index));
                      widget.onScheduleChanged(WeekdaySchedule(entries: List.of(_weekdayEntries)));
                    },
                  ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _weekdayEntries.add(const WeekdayEntry(weekday: 1, timeOfDay: Duration(hours: 8)));
            });
          },
          icon: const Icon(Icons.add_circle_outline),
          label: Text(widget.l10n.addEntry),
        ),
      ],
    );
  }

  Widget _buildMonthlyByWeekday() {
    return Column(
      children: [
        ..._monthlyWeekdayEntries.asMap().entries.map((e) {
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
                    (i) => DropdownMenuItem(value: i + 1, child: Text(_occurrenceName(i + 1))),
                  ),
                  onChanged: (occ) {
                    if (occ == null) return;
                    setState(() {
                      _monthlyWeekdayEntries[index] = MonthlyWeekdayEntry(
                        occurrence: occ,
                        weekday: entry.weekday,
                        timeOfDay: entry.timeOfDay,
                      );
                    });
                    widget.onScheduleChanged(MonthlyByWeekdaySchedule(entries: List.of(_monthlyWeekdayEntries)));
                  },
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: entry.weekday,
                  items: List.generate(
                    7,
                    (i) => DropdownMenuItem(value: i + 1, child: Text(_weekdayName(i + 1))),
                  ),
                  onChanged: (wd) {
                    if (wd == null) return;
                    setState(() {
                      _monthlyWeekdayEntries[index] = MonthlyWeekdayEntry(
                        occurrence: entry.occurrence,
                        weekday: wd,
                        timeOfDay: entry.timeOfDay,
                      );
                    });
                    widget.onScheduleChanged(MonthlyByWeekdaySchedule(entries: List.of(_monthlyWeekdayEntries)));
                  },
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final t = await _pickTime(_durationToTod(entry.timeOfDay));
                    if (t != null) {
                      setState(() {
                        _monthlyWeekdayEntries[index] = MonthlyWeekdayEntry(
                          occurrence: entry.occurrence,
                          weekday: entry.weekday,
                          timeOfDay: _todToDuration(t),
                        );
                      });
                      widget.onScheduleChanged(MonthlyByWeekdaySchedule(entries: List.of(_monthlyWeekdayEntries)));
                    }
                  },
                  child: Text(_durationToTod(entry.timeOfDay).format(context)),
                ),
                if (_monthlyWeekdayEntries.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error),
                    onPressed: () {
                      setState(() => _monthlyWeekdayEntries.removeAt(index));
                      widget.onScheduleChanged(MonthlyByWeekdaySchedule(entries: List.of(_monthlyWeekdayEntries)));
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
              _monthlyWeekdayEntries
                  .add(const MonthlyWeekdayEntry(occurrence: 1, weekday: 1, timeOfDay: Duration(hours: 8)));
            });
          },
          icon: const Icon(Icons.add_circle_outline),
          label: Text(widget.l10n.addEntry),
        ),
      ],
    );
  }

  Widget _buildMonthlyByDate() {
    return Column(
      children: [
        ..._monthlyDateEntries.asMap().entries.map((e) {
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
                  _monthlyDateEntries[index] = MonthlyDateEntry(dayOfMonth: day, timeOfDay: entry.timeOfDay);
                });
                widget.onScheduleChanged(MonthlyByDateSchedule(entries: List.of(_monthlyDateEntries)));
              },
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () async {
                    final t = await _pickTime(_durationToTod(entry.timeOfDay));
                    if (t != null) {
                      setState(() {
                        _monthlyDateEntries[index] =
                            MonthlyDateEntry(dayOfMonth: entry.dayOfMonth, timeOfDay: _todToDuration(t));
                      });
                      widget.onScheduleChanged(MonthlyByDateSchedule(entries: List.of(_monthlyDateEntries)));
                    }
                  },
                  child: Text(_durationToTod(entry.timeOfDay).format(context)),
                ),
                if (_monthlyDateEntries.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error),
                    onPressed: () {
                      setState(() => _monthlyDateEntries.removeAt(index));
                      widget.onScheduleChanged(MonthlyByDateSchedule(entries: List.of(_monthlyDateEntries)));
                    },
                  ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _monthlyDateEntries.add(const MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 8)));
            });
          },
          icon: const Icon(Icons.add_circle_outline),
          label: Text(widget.l10n.addEntry),
        ),
      ],
    );
  }
}
