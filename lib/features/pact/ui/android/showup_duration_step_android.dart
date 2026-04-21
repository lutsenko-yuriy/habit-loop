import 'package:flutter/material.dart';
import 'package:habit_loop/features/pact/domain/pact_creation_state.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

class ShowupDurationStepAndroid extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<Duration> onChanged;

  const ShowupDurationStepAndroid({
    super.key,
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
        Text(l10n.showupDurationStep, style: Theme.of(context).textTheme.headlineSmall),
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
