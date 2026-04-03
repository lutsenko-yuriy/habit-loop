import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:habit_loop/features/pact/domain/pact_creation_state.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

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

  List<Widget> _scheduleOptions(BuildContext context, AppLocalizations l10n) {
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
        child: GestureDetector(
          onTap: () => onScheduleTypeChanged(type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? CupertinoTheme.of(context)
                      .primaryColor
                      .withValues(alpha: 0.1)
                  : CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: CupertinoTheme.of(context).primaryColor,
                      width: 2,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.circle,
                  color: isSelected
                      ? CupertinoTheme.of(context).primaryColor
                      : CupertinoColors.systemGrey,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(label),
              ],
            ),
          ),
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
        Text(
          l10n.scheduleStep,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.scheduleTypeLabel),
        const SizedBox(height: 16),
        ..._scheduleOptions(context, l10n),
        const SizedBox(height: 24),
        if (state.scheduleType != null)
          ScheduleDetailsIos(
            state: state,
            l10n: l10n,
            onScheduleChanged: onScheduleChanged,
          ),
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

class ScheduleDetailsIosState extends State<ScheduleDetailsIos> {
  late Duration _dailyTime;
  late List<WeekdayEntry> _weekdayEntries;
  late List<MonthlyWeekdayEntry> _monthlyWeekdayEntries;
  late List<MonthlyDateEntry> _monthlyDateEntries;

  @override
  void initState() {
    super.initState();
    final schedule = widget.state.schedule;
    if (schedule is DailySchedule) {
      _dailyTime = schedule.timeOfDay;
    } else {
      _dailyTime = const Duration(hours: 8);
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
        const MonthlyWeekdayEntry(
            occurrence: 1, weekday: 1, timeOfDay: Duration(hours: 8)),
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

  String _weekdayName(int weekday) {
    final l10n = widget.l10n;
    switch (weekday) {
      case 1: return l10n.weekdayMon;
      case 2: return l10n.weekdayTue;
      case 3: return l10n.weekdayWed;
      case 4: return l10n.weekdayThu;
      case 5: return l10n.weekdayFri;
      case 6: return l10n.weekdaySat;
      case 7: return l10n.weekdaySun;
      default: return '';
    }
  }

  String _occurrenceName(int occurrence) {
    final l10n = widget.l10n;
    switch (occurrence) {
      case 1: return l10n.occurrenceFirst;
      case 2: return l10n.occurrenceSecond;
      case 3: return l10n.occurrenceThird;
      case 4: return l10n.occurrenceFourth;
      default: return '';
    }
  }

  void _showTimePicker(Duration initial, ValueChanged<Duration> onChanged) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            SizedBox(
              height: 216,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime(
                    2026, 1, 1, initial.inHours, initial.inMinutes % 60),
                onDateTimeChanged: (dt) {
                  onChanged(Duration(hours: dt.hour, minutes: dt.minute));
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).viewPadding.bottom),
          ],
        ),
      ),
    );
  }

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimeRow(
          label: widget.l10n.timeOfDayLabel,
          time: _dailyTime,
          onTap: () => _showTimePicker(_dailyTime, (t) {
            setState(() => _dailyTime = t);
            widget.onScheduleChanged(DailySchedule(timeOfDay: t));
          }),
        ),
      ],
    );
  }

  Widget _buildWeekday() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._weekdayEntries.asMap().entries.map((e) {
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
                    weekdayName: _weekdayName,
                    onChanged: (wd) {
                      setState(() {
                        _weekdayEntries[index] = WeekdayEntry(
                            weekday: wd, timeOfDay: entry.timeOfDay);
                      });
                      widget.onScheduleChanged(
                          WeekdaySchedule(entries: List.of(_weekdayEntries)));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                _TimeChip(
                  time: entry.timeOfDay,
                          onTap: () => _showTimePicker(entry.timeOfDay, (t) {
                    setState(() {
                      _weekdayEntries[index] =
                          WeekdayEntry(weekday: entry.weekday, timeOfDay: t);
                    });
                    widget.onScheduleChanged(
                        WeekdaySchedule(entries: List.of(_weekdayEntries)));
                  }),
                ),
                if (_weekdayEntries.length > 1)
                  CupertinoButton(
                    padding: const EdgeInsets.only(left: 4),
                    child: const Icon(CupertinoIcons.minus_circle,
                        color: CupertinoColors.destructiveRed, size: 22),
                    onPressed: () {
                      setState(() => _weekdayEntries.removeAt(index));
                      widget.onScheduleChanged(
                          WeekdaySchedule(entries: List.of(_weekdayEntries)));
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
              _weekdayEntries.add(const WeekdayEntry(
                  weekday: 1, timeOfDay: Duration(hours: 8)));
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

  Widget _buildMonthlyByWeekday() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._monthlyWeekdayEntries.asMap().entries.map((e) {
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
                        occurrenceName: _occurrenceName,
                        onChanged: (occ) {
                          setState(() {
                            _monthlyWeekdayEntries[index] =
                                MonthlyWeekdayEntry(
                              occurrence: occ,
                              weekday: entry.weekday,
                              timeOfDay: entry.timeOfDay,
                            );
                          });
                          widget.onScheduleChanged(MonthlyByWeekdaySchedule(
                              entries: List.of(_monthlyWeekdayEntries)));
                        },
                      ),
                    ),
                    Expanded(
                      child: _DropdownWeekday(
                        value: entry.weekday,
                        weekdayName: _weekdayName,
                        onChanged: (wd) {
                          setState(() {
                            _monthlyWeekdayEntries[index] =
                                MonthlyWeekdayEntry(
                              occurrence: entry.occurrence,
                              weekday: wd,
                              timeOfDay: entry.timeOfDay,
                            );
                          });
                          widget.onScheduleChanged(MonthlyByWeekdaySchedule(
                              entries: List.of(_monthlyWeekdayEntries)));
                        },
                      ),
                    ),
                    _TimeChip(
                      time: entry.timeOfDay,
                                  onTap: () => _showTimePicker(entry.timeOfDay, (t) {
                        setState(() {
                          _monthlyWeekdayEntries[index] =
                              MonthlyWeekdayEntry(
                            occurrence: entry.occurrence,
                            weekday: entry.weekday,
                            timeOfDay: t,
                          );
                        });
                        widget.onScheduleChanged(MonthlyByWeekdaySchedule(
                            entries: List.of(_monthlyWeekdayEntries)));
                      }),
                    ),
                    const Spacer(),
                    if (_monthlyWeekdayEntries.length > 1)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(CupertinoIcons.minus_circle,
                            color: CupertinoColors.destructiveRed, size: 22),
                        onPressed: () {
                          setState(
                              () => _monthlyWeekdayEntries.removeAt(index));
                          widget.onScheduleChanged(MonthlyByWeekdaySchedule(
                              entries: List.of(_monthlyWeekdayEntries)));
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
              _monthlyWeekdayEntries.add(const MonthlyWeekdayEntry(
                  occurrence: 1, weekday: 1, timeOfDay: Duration(hours: 8)));
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

  Widget _buildMonthlyByDate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._monthlyDateEntries.asMap().entries.map((e) {
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
                        _monthlyDateEntries[index] = MonthlyDateEntry(
                            dayOfMonth: day, timeOfDay: entry.timeOfDay);
                      });
                      widget.onScheduleChanged(MonthlyByDateSchedule(
                          entries: List.of(_monthlyDateEntries)));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _TimeChip(
                  time: entry.timeOfDay,
                          onTap: () => _showTimePicker(entry.timeOfDay, (t) {
                    setState(() {
                      _monthlyDateEntries[index] = MonthlyDateEntry(
                          dayOfMonth: entry.dayOfMonth, timeOfDay: t);
                    });
                    widget.onScheduleChanged(MonthlyByDateSchedule(
                        entries: List.of(_monthlyDateEntries)));
                  }),
                ),
                if (_monthlyDateEntries.length > 1)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.minus_circle,
                        color: CupertinoColors.destructiveRed, size: 22),
                    onPressed: () {
                      setState(() => _monthlyDateEntries.removeAt(index));
                      widget.onScheduleChanged(MonthlyByDateSchedule(
                          entries: List.of(_monthlyDateEntries)));
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
              _monthlyDateEntries.add(const MonthlyDateEntry(
                  dayOfMonth: 1, timeOfDay: Duration(hours: 8)));
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
        showCupertinoModalPopup<void>(
          context: context,
          builder: (ctx) => Container(
            color: CupertinoColors.systemBackground.resolveFrom(ctx),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      child: const Text('Done'),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                SizedBox(
                  height: 216,
                  child: CupertinoPicker(
                    scrollController:
                        FixedExtentScrollController(initialItem: value - 1),
                    itemExtent: 40,
                    onSelectedItemChanged: (i) => onChanged(i + 1),
                    children: List.generate(
                      7,
                      (i) => Center(child: Text(weekdayName(i + 1))),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(ctx).viewPadding.bottom),
              ],
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
        showCupertinoModalPopup<void>(
          context: context,
          builder: (ctx) => Container(
            color: CupertinoColors.systemBackground.resolveFrom(ctx),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      child: const Text('Done'),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                SizedBox(
                  height: 216,
                  child: CupertinoPicker(
                    scrollController:
                        FixedExtentScrollController(initialItem: value - 1),
                    itemExtent: 40,
                    onSelectedItemChanged: (i) => onChanged(i + 1),
                    children: List.generate(
                      4,
                      (i) => Center(child: Text(occurrenceName(i + 1))),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(ctx).viewPadding.bottom),
              ],
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
        showCupertinoModalPopup<void>(
          context: context,
          builder: (ctx) => Container(
            color: CupertinoColors.systemBackground.resolveFrom(ctx),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      child: const Text('Done'),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                SizedBox(
                  height: 216,
                  child: CupertinoPicker(
                    scrollController:
                        FixedExtentScrollController(initialItem: value - 1),
                    itemExtent: 40,
                    onSelectedItemChanged: (index) => onChanged(index + 1),
                    children: List.generate(
                      31,
                      (i) => Center(child: Text('${i + 1}')),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(ctx).viewPadding.bottom),
              ],
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
