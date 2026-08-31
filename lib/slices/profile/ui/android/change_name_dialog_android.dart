import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/profile/ui/generic/change_name_dialog_controller.dart';
import 'package:habit_loop/slices/profile/ui/generic/enter_name_constants.dart';

/// Shows an [AlertDialog] pre-filled with [currentName] (HAB-232 WU5),
/// returning the trimmed new name on Save, or `null` if cancelled/dismissed.
/// Save is always enabled; saving an empty field clears the name (HAB-232).
Future<String?> showMaterialChangeNameDialog(
  BuildContext context,
  String currentName,
  AppLocalizations l10n,
) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _ChangeNameDialogAndroid(currentName: currentName, l10n: l10n),
  );
}

class _ChangeNameDialogAndroid extends StatefulWidget {
  const _ChangeNameDialogAndroid({required this.currentName, required this.l10n});

  final String currentName;
  final AppLocalizations l10n;

  @override
  State<_ChangeNameDialogAndroid> createState() => _ChangeNameDialogAndroidState();
}

class _ChangeNameDialogAndroidState extends State<_ChangeNameDialogAndroid> {
  late final _controller = ChangeNameDialogController(widget.currentName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.changeNameTitle),
      content: TextField(
        key: const Key('change-name-text-field'),
        controller: _controller.textController,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        inputFormatters: [LengthLimitingTextInputFormatter(enterNameMaxLength)],
        decoration: InputDecoration(hintText: l10n.enterNameHint, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          key: const Key('change-name-cancel-button'),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('change-name-save-button'),
          onPressed: () => Navigator.pop(context, _controller.textController.text.trim()),
          child: Text(l10n.changeNameSave),
        ),
      ],
    );
  }
}
