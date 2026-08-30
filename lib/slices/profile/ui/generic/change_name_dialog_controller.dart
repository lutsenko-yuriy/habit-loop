import 'package:flutter/widgets.dart';

/// Shared between the Android and iOS "Change name" dialogs (HAB-232 WU5) —
/// owns the [TextEditingController] and the derived "can Save" state so
/// neither platform body has to re-implement the same listener/setState
/// boilerplate. Platform bodies differ only in which widgets they render
/// around this controller (`TextField`+`AlertDialog` vs
/// `CupertinoTextField`+`CupertinoAlertDialog`).
///
/// Call [dispose] from the owning `State.dispose`.
class ChangeNameDialogController {
  ChangeNameDialogController(String currentName)
      : textController = TextEditingController(text: currentName)
          ..selection = TextSelection.collapsed(offset: currentName.length),
        canSave = ValueNotifier<bool>(currentName.trim().isNotEmpty) {
    textController.addListener(_onTextChanged);
  }

  final TextEditingController textController;

  /// `true` once the field holds non-empty, non-whitespace-only text.
  final ValueNotifier<bool> canSave;

  void _onTextChanged() {
    final value = textController.text.trim().isNotEmpty;
    if (value != canSave.value) canSave.value = value;
  }

  void dispose() {
    textController.removeListener(_onTextChanged);
    textController.dispose();
    canSave.dispose();
  }
}
