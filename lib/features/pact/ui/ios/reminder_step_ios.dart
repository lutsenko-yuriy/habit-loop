import 'package:flutter/cupertino.dart';
import 'package:habit_loop/features/pact/domain/pact_creation_state.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
