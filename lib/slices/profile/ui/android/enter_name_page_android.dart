import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/profile/ui/generic/enter_name_constants.dart';
import 'package:habit_loop/theme/spacing.dart';

class EnterNamePageAndroid extends StatelessWidget {
  const EnterNamePageAndroid({super.key, required this.controller, required this.onSave, required this.onSkip});

  final TextEditingController controller;
  final Future<void> Function() onSave;
  final Future<void> Function() onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          // Buttons stretch to the same inset width as the rest of the page
          // (WU8) — CrossAxisAlignment.stretch on this outer column, not a
          // separate edge-to-edge sibling.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  key: const Key('enter-name-content-area'),
                  // Scrollable: the field is autofocused, so the keyboard is up on
                  // the very first frame and shrinks the available height — an
                  // unscrollable column can overflow on a short device or with
                  // longer translated copy.
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.enterNameTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        Text(
                          l10n.enterNameBody,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.s24),
                        TextField(
                          key: const Key('enter-name-text-field'),
                          controller: controller,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [LengthLimitingTextInputFormatter(enterNameMaxLength)],
                          decoration: InputDecoration(
                            hintText: l10n.enterNameHint,
                            border: const UnderlineInputBorder(),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: theme.colorScheme.outline),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
