import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:habit_loop/features/pact/domain/pact_creation_state.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

class PactCreationPageIos extends StatelessWidget {
  final PactCreationState state;
  final ValueChanged<String> onHabitNameChanged;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<Duration> onShowupDurationChanged;
  final ValueChanged<ScheduleType> onScheduleTypeChanged;
  final ValueChanged<ShowupSchedule> onScheduleChanged;
  final ValueChanged<Duration> onReminderOffsetChanged;
  final VoidCallback onClearReminder;
  final ValueChanged<bool> onCommitmentChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const PactCreationPageIos({
    super.key,
    required this.state,
    required this.onHabitNameChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onShowupDurationChanged,
    required this.onScheduleTypeChanged,
    required this.onScheduleChanged,
    required this.onReminderOffsetChanged,
    required this.onClearReminder,
    required this.onCommitmentChanged,
    required this.onNext,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.pactCreationTitle),
        leading: state.currentStep > 0
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onBack,
                child: Text(l10n.back),
              )
            : null,
      ),
      child: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              _HabitNameField(
                habitName: state.habitName,
                onChanged: onHabitNameChanged,
                l10n: l10n,
              ),
              Expanded(
                child: _buildStep(context, l10n),
              ),
              _BottomBar(
                state: state,
                l10n: l10n,
                onNext: onNext,
                onSubmit: onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, AppLocalizations l10n) {
    switch (state.currentStep) {
      case 0:
        return _PactDurationStep(
          state: state,
          l10n: l10n,
          onStartDateChanged: onStartDateChanged,
          onEndDateChanged: onEndDateChanged,
          onShowupDurationChanged: onShowupDurationChanged,
        );
      case 1:
        return _ShowupDurationStep(
          state: state,
          l10n: l10n,
          onChanged: onShowupDurationChanged,
        );
      case 2:
        return _ScheduleStep(
          state: state,
          l10n: l10n,
          onScheduleTypeChanged: onScheduleTypeChanged,
          onScheduleChanged: onScheduleChanged,
        );
      case 3:
        return _ReminderStep(
          state: state,
          l10n: l10n,
          onReminderOffsetChanged: onReminderOffsetChanged,
          onClearReminder: onClearReminder,
        );
      case 4:
        return _CommitmentStep(
          state: state,
          l10n: l10n,
          onCommitmentChanged: onCommitmentChanged,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _HabitNameField extends StatelessWidget {
  final String habitName;
  final ValueChanged<String> onChanged;
  final AppLocalizations l10n;

  const _HabitNameField({
    required this.habitName,
    required this.onChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: CupertinoTextField(
        placeholder: l10n.habitNameHint,
        prefix: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            l10n.habitNameLabel,
            style: const TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 14,
            ),
          ),
        ),
        controller: TextEditingController(text: habitName)
          ..selection = TextSelection.collapsed(offset: habitName.length),
        onChanged: onChanged,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  const _BottomBar({
    required this.state,
    required this.l10n,
    required this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isLastStep = state.currentStep == PactCreationState.totalSteps - 1;
    final canAdvance = state.canAdvanceFromStep;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: canAdvance
              ? (isLastStep ? onSubmit : onNext)
              : null,
          child: Text(
            isLastStep ? l10n.createPactConfirm : l10n.next,
          ),
        ),
      ),
    );
  }
}

class _PactDurationStep extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<Duration> onShowupDurationChanged;

  const _PactDurationStep({
    required this.state,
    required this.l10n,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onShowupDurationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(
          l10n.pactDurationStep,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        _DateRow(
          label: l10n.startDateLabel,
          date: state.startDate,
          onTap: () => _showDatePicker(
            context,
            state.startDate,
            minimumDate: DateTime.now(),
            onDateChanged: onStartDateChanged,
          ),
        ),
        const SizedBox(height: 16),
        _DateRow(
          label: l10n.endDateLabel,
          date: state.endDate,
          onTap: () => _showDatePicker(
            context,
            state.endDate,
            minimumDate: state.startDate.add(const Duration(days: 1)),
            onDateChanged: onEndDateChanged,
          ),
        ),
      ],
    );
  }

  void _showDatePicker(
    BuildContext context,
    DateTime initialDate, {
    DateTime? minimumDate,
    required ValueChanged<DateTime> onDateChanged,
  }) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 320 + MediaQuery.of(context).padding.bottom,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    child: const Text('Done'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initialDate,
                minimumDate: minimumDate,
                onDateTimeChanged: onDateChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateRow({
    required this.label,
    required this.date,
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
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
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

class _ShowupDurationStep extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<Duration> onChanged;

  const _ShowupDurationStep({
    required this.state,
    required this.l10n,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentMinutes = state.showupDuration?.inMinutes ?? 10;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(
          l10n.showupDurationStep,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.showupDurationLabel),
        const SizedBox(height: 24),
        Center(
          child: Text(
            l10n.showupDurationMinutes(currentMinutes),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: CupertinoPicker(
            scrollController: FixedExtentScrollController(
              initialItem: currentMinutes - 1,
            ),
            itemExtent: 40,
            onSelectedItemChanged: (index) {
              onChanged(Duration(minutes: index + 1));
            },
            children: List.generate(
              120,
              (i) => Center(
                child: Text(l10n.showupDurationMinutes(i + 1)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScheduleStep extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<ScheduleType> onScheduleTypeChanged;
  final ValueChanged<ShowupSchedule> onScheduleChanged;

  const _ScheduleStep({
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
          _ScheduleDetails(
            state: state,
            l10n: l10n,
            onScheduleChanged: onScheduleChanged,
          ),
      ],
    );
  }
}

class _ScheduleDetails extends StatefulWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<ShowupSchedule> onScheduleChanged;

  const _ScheduleDetails({
    required this.state,
    required this.l10n,
    required this.onScheduleChanged,
  });

  @override
  State<_ScheduleDetails> createState() => _ScheduleDetailsState();
}

class _ScheduleDetailsState extends State<_ScheduleDetails> {
  Duration _dailyTime = const Duration(hours: 8);
  // ignore: prefer_final_fields
  List<WeekdayEntry> _weekdayEntries = [
    const WeekdayEntry(weekday: 1, timeOfDay: Duration(hours: 8)),
  ];
  // ignore: prefer_final_fields
  List<MonthlyWeekdayEntry> _monthlyWeekdayEntries = [
    const MonthlyWeekdayEntry(
        occurrence: 1, weekday: 1, timeOfDay: Duration(hours: 8)),
  ];
  // ignore: prefer_final_fields
  List<MonthlyDateEntry> _monthlyDateEntries = [
    const MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 8)),
  ];

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
      builder: (context) => Container(
        height: 320 + MediaQuery.of(context).padding.bottom,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    child: const Text('Done'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime(2026, 1, 1,
                    initial.inHours, initial.inMinutes % 60),
                onDateTimeChanged: (dt) {
                  onChanged(Duration(hours: dt.hour, minutes: dt.minute));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
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
          formatTime: _formatTime,
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
                  formatTime: _formatTime,
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
                      formatTime: _formatTime,
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
                  formatTime: _formatTime,
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
  final String Function(Duration) formatTime;
  final VoidCallback onTap;

  const _TimeRow({
    required this.label,
    required this.time,
    required this.formatTime,
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
              formatTime(time),
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
  final String Function(Duration) formatTime;
  final VoidCallback onTap;

  const _TimeChip({
    required this.time,
    required this.formatTime,
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
          formatTime(time),
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
            height: 280 + MediaQuery.of(ctx).padding.bottom,
            color: CupertinoColors.systemBackground.resolveFrom(ctx),
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CupertinoButton(
                        child: const Text('Done'),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
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
            height: 280 + MediaQuery.of(ctx).padding.bottom,
            color: CupertinoColors.systemBackground.resolveFrom(ctx),
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CupertinoButton(
                        child: const Text('Done'),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
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
          builder: (context) => Container(
            height: 320,
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CupertinoButton(
                        child: const Text('Done'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                        initialItem: value - 1),
                    itemExtent: 40,
                    onSelectedItemChanged: (index) => onChanged(index + 1),
                    children: List.generate(
                      31,
                      (i) => Center(child: Text('${i + 1}')),
                    ),
                  ),
                ),
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

class _ReminderStep extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<Duration> onReminderOffsetChanged;
  final VoidCallback onClearReminder;

  const _ReminderStep({
    required this.state,
    required this.l10n,
    required this.onReminderOffsetChanged,
    required this.onClearReminder,
  });

  @override
  Widget build(BuildContext context) {
    final options = <_ReminderOption>[
      _ReminderOption(label: l10n.reminderNone, offset: null),
      _ReminderOption(
          label: l10n.reminderAtStart, offset: Duration.zero),
      _ReminderOption(
          label: l10n.reminderMinutesBefore(15),
          offset: const Duration(minutes: 15)),
      _ReminderOption(
          label: l10n.reminderMinutesBefore(30),
          offset: const Duration(minutes: 30)),
      _ReminderOption(
          label: l10n.reminderMinutesBefore(60),
          offset: const Duration(minutes: 60)),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(
          l10n.reminderStep,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.reminderLabel),
        const SizedBox(height: 16),
        ...options.map((option) {
          final isSelected = state.reminderOffset == option.offset;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                if (option.offset == null) {
                  onClearReminder();
                } else {
                  onReminderOffsetChanged(option.offset!);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? CupertinoTheme.of(context)
                          .primaryColor
                          .withValues(alpha: 0.1)
                      : CupertinoColors.tertiarySystemFill
                          .resolveFrom(context),
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
                    ),
                    const SizedBox(width: 12),
                    Text(option.label),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ReminderOption {
  final String label;
  final Duration? offset;

  const _ReminderOption({required this.label, required this.offset});
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommitmentStep extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<bool> onCommitmentChanged;

  const _CommitmentStep({
    required this.state,
    required this.l10n,
    required this.onCommitmentChanged,
  });

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _scheduleDescription() {
    final s = state.schedule;
    if (s == null) return '';
    if (s is DailySchedule) {
      final h = s.timeOfDay.inHours.toString().padLeft(2, '0');
      final m = (s.timeOfDay.inMinutes % 60).toString().padLeft(2, '0');
      return '${l10n.scheduleDaily} @ $h:$m';
    }
    if (s is WeekdaySchedule) {
      return '${l10n.scheduleWeekday} (${s.entries.length})';
    }
    if (s is MonthlyByWeekdaySchedule) {
      return '${l10n.scheduleMonthlyByWeekday} (${s.entries.length})';
    }
    if (s is MonthlyByDateSchedule) {
      return '${l10n.scheduleMonthlyByDate} (${s.entries.length})';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final reminderText = state.reminderOffset == null
        ? l10n.reminderNone
        : state.reminderOffset == Duration.zero
            ? l10n.reminderAtStart
            : l10n.reminderMinutesBefore(state.reminderOffset!.inMinutes);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(
          l10n.commitmentStep,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _SummaryRow(label: l10n.summaryHabit, value: state.habitName),
              _SummaryRow(
                label: l10n.summaryDuration,
                value:
                    '${_formatDate(state.startDate)} → ${_formatDate(state.endDate)}',
              ),
              _SummaryRow(
                label: l10n.summaryShowupDuration,
                value: l10n.showupDurationMinutes(
                    state.showupDuration?.inMinutes ?? 0),
              ),
              _SummaryRow(
                  label: l10n.summarySchedule,
                  value: _scheduleDescription()),
              _SummaryRow(label: l10n.summaryReminder, value: reminderText),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemYellow.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l10n.commitmentWarning,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => onCommitmentChanged(!state.commitmentAccepted),
          child: Row(
            children: [
              Icon(
                state.commitmentAccepted
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                color: state.commitmentAccepted
                    ? CupertinoTheme.of(context).primaryColor
                    : CupertinoColors.systemGrey,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.commitmentAccept,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
