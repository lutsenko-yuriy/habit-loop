import 'package:flutter/material.dart';
import 'package:habit_loop/features/pact/domain/pact_creation_state.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

class PactCreationPageAndroid extends StatelessWidget {
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

  const PactCreationPageAndroid({
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pactCreationTitle),
        leading: state.currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              )
            : null,
      ),
      body: Column(
        children: [
          _HabitNameField(
            habitName: state.habitName,
            onChanged: onHabitNameChanged,
            l10n: l10n,
          ),
          _StepIndicator(currentStep: state.currentStep),
          Expanded(
            child: _buildStep(context, l10n),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        state: state,
        l10n: l10n,
        onNext: onNext,
        onSubmit: onSubmit,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: TextEditingController(text: habitName)
          ..selection = TextSelection.collapsed(offset: habitName.length),
        decoration: InputDecoration(
          labelText: l10n.habitNameLabel,
          hintText: l10n.habitNameHint,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(PactCreationState.totalSteps, (index) {
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: index <= currentStep
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          );
        }),
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canAdvance
                ? (isLastStep ? onSubmit : onNext)
                : null,
            child: Text(
              isLastStep ? l10n.createPactConfirm : l10n.next,
            ),
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

  const _PactDurationStep({
    required this.state,
    required this.l10n,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(l10n.pactDurationStep,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        _DateTile(
          label: l10n.startDateLabel,
          date: state.startDate,
          onTap: () async {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final picked = await showDatePicker(
              context: context,
              initialDate: state.startDate,
              firstDate: today,
              lastDate: DateTime(2040),
            );
            if (picked != null) onStartDateChanged(picked);
          },
        ),
        const SizedBox(height: 12),
        _DateTile(
          label: l10n.endDateLabel,
          date: state.endDate,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: state.endDate,
              firstDate: state.startDate.add(const Duration(days: 1)),
              lastDate: DateTime(2040),
            );
            if (picked != null) onEndDateChanged(picked);
          },
        ),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      title: Text(label),
      trailing: Text(
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        style: TextStyle(color: Theme.of(context).colorScheme.primary),
      ),
      onTap: onTap,
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
        Text(l10n.showupDurationStep,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(l10n.showupDurationLabel),
        const SizedBox(height: 24),
        Center(
          child: Text(
            l10n.showupDurationMinutes(currentMinutes),
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: 16),
        Slider(
          value: currentMinutes.toDouble(),
          min: 1,
          max: 120,
          divisions: 119,
          label: l10n.showupDurationMinutes(currentMinutes),
          onChanged: (v) => onChanged(Duration(minutes: v.round())),
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
            side: isSelected
                ? BorderSide(color: theme.colorScheme.primary, width: 2)
                : BorderSide.none,
          ),
          tileColor: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : theme.colorScheme.surfaceContainerHighest,
          leading: Icon(
            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isSelected ? theme.colorScheme.primary : Colors.grey,
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
        Text(l10n.scheduleStep,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(l10n.scheduleTypeLabel),
        const SizedBox(height: 16),
        ..._scheduleOptions(context),
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
  late TimeOfDay _dailyTime;
  late List<WeekdayEntry> _weekdayEntries;
  late List<MonthlyWeekdayEntry> _monthlyWeekdayEntries;
  late List<MonthlyDateEntry> _monthlyDateEntries;

  @override
  void initState() {
    super.initState();
    final schedule = widget.state.schedule;
    if (schedule is DailySchedule) {
      _dailyTime = TimeOfDay(
          hour: schedule.timeOfDay.inHours,
          minute: schedule.timeOfDay.inMinutes % 60);
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

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) {
    return showTimePicker(context: context, initialTime: initial);
  }

  Duration _todToDuration(TimeOfDay t) =>
      Duration(hours: t.hour, minutes: t.minute);

  TimeOfDay _durationToTod(Duration d) =>
      TimeOfDay(hour: d.inHours, minute: d.inMinutes % 60);

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
                (i) => DropdownMenuItem(
                    value: i + 1, child: Text(_weekdayName(i + 1))),
              ),
              onChanged: (wd) {
                if (wd == null) return;
                setState(() {
                  _weekdayEntries[index] =
                      WeekdayEntry(weekday: wd, timeOfDay: entry.timeOfDay);
                });
                widget.onScheduleChanged(
                    WeekdaySchedule(entries: List.of(_weekdayEntries)));
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
                        _weekdayEntries[index] = WeekdayEntry(
                            weekday: entry.weekday,
                            timeOfDay: _todToDuration(t));
                      });
                      widget.onScheduleChanged(
                          WeekdaySchedule(entries: List.of(_weekdayEntries)));
                    }
                  },
                  child: Text(_durationToTod(entry.timeOfDay).format(context)),
                ),
                if (_weekdayEntries.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red),
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
        TextButton.icon(
          onPressed: () {
            setState(() {
              _weekdayEntries.add(const WeekdayEntry(
                  weekday: 1, timeOfDay: Duration(hours: 8)));
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
                    (i) => DropdownMenuItem(
                        value: i + 1, child: Text(_occurrenceName(i + 1))),
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
                    widget.onScheduleChanged(MonthlyByWeekdaySchedule(
                        entries: List.of(_monthlyWeekdayEntries)));
                  },
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: entry.weekday,
                  items: List.generate(
                    7,
                    (i) => DropdownMenuItem(
                        value: i + 1, child: Text(_weekdayName(i + 1))),
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
                    widget.onScheduleChanged(MonthlyByWeekdaySchedule(
                        entries: List.of(_monthlyWeekdayEntries)));
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
                      widget.onScheduleChanged(MonthlyByWeekdaySchedule(
                          entries: List.of(_monthlyWeekdayEntries)));
                    }
                  },
                  child: Text(_durationToTod(entry.timeOfDay).format(context)),
                ),
                if (_monthlyWeekdayEntries.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red),
                    onPressed: () {
                      setState(() => _monthlyWeekdayEntries.removeAt(index));
                      widget.onScheduleChanged(MonthlyByWeekdaySchedule(
                          entries: List.of(_monthlyWeekdayEntries)));
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
              _monthlyWeekdayEntries.add(const MonthlyWeekdayEntry(
                  occurrence: 1, weekday: 1, timeOfDay: Duration(hours: 8)));
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
                (i) => DropdownMenuItem(
                    value: i + 1, child: Text('${i + 1}')),
              ),
              onChanged: (day) {
                if (day == null) return;
                setState(() {
                  _monthlyDateEntries[index] = MonthlyDateEntry(
                      dayOfMonth: day, timeOfDay: entry.timeOfDay);
                });
                widget.onScheduleChanged(MonthlyByDateSchedule(
                    entries: List.of(_monthlyDateEntries)));
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
                        _monthlyDateEntries[index] = MonthlyDateEntry(
                            dayOfMonth: entry.dayOfMonth,
                            timeOfDay: _todToDuration(t));
                      });
                      widget.onScheduleChanged(MonthlyByDateSchedule(
                          entries: List.of(_monthlyDateEntries)));
                    }
                  },
                  child: Text(_durationToTod(entry.timeOfDay).format(context)),
                ),
                if (_monthlyDateEntries.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red),
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
        TextButton.icon(
          onPressed: () {
            setState(() {
              _monthlyDateEntries.add(const MonthlyDateEntry(
                  dayOfMonth: 1, timeOfDay: Duration(hours: 8)));
            });
          },
          icon: const Icon(Icons.add_circle_outline),
          label: Text(widget.l10n.addEntry),
        ),
      ],
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
      _ReminderOption(label: l10n.reminderAtStart, offset: Duration.zero),
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
        Text(l10n.reminderStep,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(l10n.reminderLabel),
        const SizedBox(height: 16),
        ...options.map((option) {
          final isSelected = state.reminderOffset == option.offset;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isSelected
                    ? BorderSide(
                        color: Theme.of(context).colorScheme.primary, width: 2)
                    : BorderSide.none,
              ),
              tileColor: isSelected
                  ? Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              leading: Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
              title: Text(option.label),
              onTap: () {
                if (option.offset == null) {
                  onClearReminder();
                } else {
                  onReminderOffsetChanged(option.offset!);
                }
              },
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    if (s is WeekdaySchedule) return '${l10n.scheduleWeekday} (${s.entries.length})';
    if (s is MonthlyByWeekdaySchedule) return '${l10n.scheduleMonthlyByWeekday} (${s.entries.length})';
    if (s is MonthlyByDateSchedule) return '${l10n.scheduleMonthlyByDate} (${s.entries.length})';
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
        Text(l10n.commitmentStep,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _SummaryRow(label: l10n.summaryHabit, value: state.habitName),
              _SummaryRow(
                label: l10n.summaryDuration,
                value: '${_formatDate(state.startDate)} → ${_formatDate(state.endDate)}',
              ),
              _SummaryRow(
                label: l10n.summaryShowupDuration,
                value: l10n.showupDurationMinutes(state.showupDuration?.inMinutes ?? 0),
              ),
              _SummaryRow(label: l10n.summarySchedule, value: _scheduleDescription()),
              _SummaryRow(label: l10n.summaryReminder, value: reminderText),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l10n.commitmentWarning,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: state.commitmentAccepted,
          onChanged: (v) => onCommitmentChanged(v ?? false),
          title: Text(
            l10n.commitmentAccept,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}
