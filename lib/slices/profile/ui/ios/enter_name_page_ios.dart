import 'package:flutter/cupertino.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/theme/spacing.dart';

class EnterNamePageIos extends StatelessWidget {
  const EnterNamePageIos({super.key, required this.controller, required this.onSave, required this.onSkip});

  final TextEditingController controller;
  final Future<void> Function() onSave;
  final Future<void> Function() onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoPageScaffold(
      child: SafeArea(
        // Scrollable: the field is autofocused, so the keyboard is up on the very
        // first frame and shrinks the body (resizeToAvoidBottomInset) — an
        // unscrollable Column can overflow past the Continue/Skip buttons on a
        // short device or with longer translated copy.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.enterNameTitle, style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle),
              const SizedBox(height: AppSpacing.s12),
              Text(l10n.enterNameBody, style: CupertinoTheme.of(context).textTheme.textStyle),
              const SizedBox(height: AppSpacing.s24),
              CupertinoTextField(
                key: const Key('enter-name-text-field'),
                controller: controller,
                placeholder: l10n.enterNameHint,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.s24),
              CupertinoButton.filled(
                key: const Key('enter-name-save-button'),
                onPressed: () => onSave(),
                child: Text(l10n.enterNameContinue),
              ),
              CupertinoButton(
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
