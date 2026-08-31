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
        canSave = ValueNotifier<bool>(true);

  final TextEditingController textController;

  /// Always `true` — Save is enabled unconditionally, including for an empty
  /// field: clearing the name and saving is how a user removes it (HAB-232
  /// follow-up). `openChangeNameDialog` already treats an empty result as a
  /// deliberate clear, not a validation failure. Kept as a [ValueNotifier]
  /// rather than a plain `bool` so the platform bodies' existing
  /// `ValueListenableBuilder<bool>` wiring doesn't need to change if a future
  /// requirement reintroduces conditional disabling.
  final ValueNotifier<bool> canSave;

  void dispose() {
    textController.dispose();
    canSave.dispose();
  }
}
