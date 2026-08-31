import 'package:flutter/widgets.dart';

/// Shared between the Android and iOS "Change name" dialogs (HAB-232 WU5) —
/// owns the [TextEditingController] so neither platform body has to
/// re-implement the same setup. Platform bodies differ only in which widgets
/// they render around this controller (`TextField`+`AlertDialog` vs
/// `CupertinoTextField`+`CupertinoAlertDialog`).
///
/// Save is always enabled, including on an empty field — clearing the name
/// and saving is how a user removes it (HAB-232 follow-up); there is no
/// "can save" state to track.
///
/// Call [dispose] from the owning `State.dispose`.
class ChangeNameDialogController {
  ChangeNameDialogController(String currentName)
      : textController = TextEditingController(text: currentName)
          ..selection = TextSelection.collapsed(offset: currentName.length);

  final TextEditingController textController;

  void dispose() {
    textController.dispose();
  }
}
