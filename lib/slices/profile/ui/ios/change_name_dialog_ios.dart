import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/profile/ui/generic/enter_name_constants.dart';

/// Shows a [CupertinoAlertDialog] pre-filled with [currentName] (HAB-232 WU5),
/// returning the trimmed new name on Save, or `null` if cancelled/dismissed.
/// Save stays disabled while the field is empty/whitespace-only.
Future<String?> showCupertinoChangeNameDialog(
  BuildContext context,
  String currentName,
  AppLocalizations l10n,
) {
  return showCupertinoDialog<String>(
    context: context,
    builder: (ctx) => _ChangeNameDialogIos(currentName: currentName, l10n: l10n),
  );
}

class _ChangeNameDialogIos extends StatefulWidget {
  const _ChangeNameDialogIos({required this.currentName, required this.l10n});

  final String currentName;
  final AppLocalizations l10n;

  @override
  State<_ChangeNameDialogIos> createState() => _ChangeNameDialogIosState();
}

class _ChangeNameDialogIosState extends State<_ChangeNameDialogIos> {
  late final TextEditingController _controller;
  late bool _canSave;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName)
      ..selection = TextSelection.collapsed(offset: widget.currentName.length);
    _canSave = _controller.text.trim().isNotEmpty;
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final canSave = _controller.text.trim().isNotEmpty;
    if (canSave != _canSave) setState(() => _canSave = canSave);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return CupertinoAlertDialog(
      title: Text(l10n.changeNameTitle),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: CupertinoTextField(
          key: const Key('change-name-text-field'),
          controller: _controller,
          autofocus: true,
          placeholder: l10n.enterNameHint,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [LengthLimitingTextInputFormatter(enterNameMaxLength)],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          key: const Key('change-name-cancel-button'),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        CupertinoDialogAction(
          key: const Key('change-name-save-button'),
          isDefaultAction: true,
          onPressed: _canSave ? () => Navigator.pop(context, _controller.text.trim()) : null,
          child: Text(l10n.changeNameSave),
        ),
      ],
    );
  }
}
