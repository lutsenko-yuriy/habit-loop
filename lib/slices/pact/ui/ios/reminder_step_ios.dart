import 'package:flutter/cupertino.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/option_tile.dart';

class ReminderStepIos extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<Duration> onReminderOffsetChanged;
  final VoidCallback onClearReminder;

  const ReminderStepIos({
    super.key,
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
      _ReminderOption(label: l10n.reminderMinutesBefore(15), offset: const Duration(minutes: 15)),
      _ReminderOption(label: l10n.reminderMinutesBefore(30), offset: const Duration(minutes: 30)),
      _ReminderOption(label: l10n.reminderMinutesBefore(60), offset: const Duration(minutes: 60)),
    ];

    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final unselectedColor = CupertinoColors.tertiarySystemFill.resolveFrom(context);

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
            child: OptionTile(
              isSelected: isSelected,
              label: option.label,
              onTap: () {
                if (option.offset == null) {
                  onClearReminder();
                } else {
                  onReminderOffsetChanged(option.offset!);
                }
              },
              selectedColor: primaryColor,
              unselectedColor: unselectedColor,
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
