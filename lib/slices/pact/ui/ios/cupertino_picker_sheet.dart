import 'package:flutter/cupertino.dart';

/// Shows the shared Cupertino picker-sheet scaffold used by every wheel/date
/// picker in the iOS pact-creation wizard: a modal popup with a top-right
/// "Done" button, a fixed-height picker area, and safe-area bottom padding.
///
/// [pickerBuilder] receives the popup's own [BuildContext] and must return
/// the picker widget to place inside the fixed-height area (a
/// [CupertinoDatePicker] or [CupertinoPicker]). Callers that need the
/// selected value after the sheet closes should capture it via the picker's
/// own change callback and read it after awaiting the returned future.
Future<void> showCupertinoPickerSheet({
  required BuildContext context,
  required String doneLabel,
  required WidgetBuilder pickerBuilder,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (popupContext) => ColoredBox(
      color: CupertinoColors.systemBackground.resolveFrom(popupContext),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(
                onPressed: () => Navigator.pop(popupContext),
                child: Text(doneLabel),
              ),
            ],
          ),
          SizedBox(
            height: 216,
            child: pickerBuilder(popupContext),
          ),
          SizedBox(height: MediaQuery.of(popupContext).viewPadding.bottom),
        ],
      ),
    ),
  );
}
