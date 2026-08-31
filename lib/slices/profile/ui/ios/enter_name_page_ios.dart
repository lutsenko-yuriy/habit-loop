import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/profile/ui/generic/enter_name_constants.dart';
import 'package:habit_loop/theme/spacing.dart';

class EnterNamePageIos extends StatefulWidget {
  const EnterNamePageIos({super.key, required this.controller, required this.onSave, required this.onSkip});

  final TextEditingController controller;
  final Future<void> Function() onSave;
  final Future<void> Function() onSkip;

  @override
  State<EnterNamePageIos> createState() => _EnterNamePageIosState();
}

class _EnterNamePageIosState extends State<EnterNamePageIos> {
  // Local, presentational only — CupertinoTextField has no built-in
  // focused/unfocused decoration swap the way Material's InputDecoration
  // does, so the underline's focus thickening (WU8) is driven by hand.
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = CupertinoTheme.of(context);
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          // Content fills the space above the buttons (WU8) — Expanded +
          // Center, rather than the buttons following the field immediately,
          // so the buttons stay bottom-anchored regardless of content height.
          child: Column(
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
                          style: theme.textTheme.navLargeTitleTextStyle,
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        Text(
                          l10n.enterNameBody,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.textStyle,
                        ),
                        const SizedBox(height: AppSpacing.s24),
                        CupertinoTextField(
                          key: const Key('enter-name-text-field'),
                          controller: widget.controller,
                          focusNode: _focusNode,
                          placeholder: l10n.enterNameHint,
                          textAlign: TextAlign.center,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [LengthLimitingTextInputFormatter(enterNameMaxLength)],
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _focusNode.hasFocus
                                    ? theme.primaryColor
                                    : CupertinoColors.opaqueSeparator.resolveFrom(context),
                                width: _focusNode.hasFocus ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              CupertinoButton.filled(
                key: const Key('enter-name-save-button'),
                onPressed: () => widget.onSave(),
                child: Text(l10n.enterNameContinue),
              ),
              CupertinoButton(
                key: const Key('enter-name-skip-button'),
                onPressed: () => widget.onSkip(),
                child: Text(l10n.enterNameSkip),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
