import 'package:flutter/material.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/theme/spacing.dart';

class EnterNameBodyAndroid extends StatelessWidget {
  const EnterNameBodyAndroid({super.key, required this.controller, required this.onSave, required this.onSkip});

  final TextEditingController controller;
  final Future<void> Function() onSave;
  final Future<void> Function() onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.enterNameTitle, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.s12),
              Text(l10n.enterNameBody, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.s24),
              TextField(
                key: const Key('enter-name-text-field'),
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(hintText: l10n.enterNameHint, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: AppSpacing.s24),
              FilledButton(
                key: const Key('enter-name-save-button'),
                onPressed: () => onSave(),
                child: Text(l10n.enterNameContinue),
              ),
              const SizedBox(height: AppSpacing.s8),
              TextButton(
                key: const Key('enter-name-skip-button'),
                onPressed: () => onSkip(),
                child: Text(l10n.enterNameSkip),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
