import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/pact/ui/ios/cupertino_picker_sheet.dart';

Widget _wrap({required String doneLabel, required WidgetBuilder pickerBuilder}) {
  return CupertinoApp(
    home: Builder(
      builder: (context) => CupertinoButton(
        onPressed: () => unawaited(showCupertinoPickerSheet(
          context: context,
          doneLabel: doneLabel,
          pickerBuilder: pickerBuilder,
        )),
        child: const Text('Open'),
      ),
    ),
  );
}

void main() {
  testWidgets('opens a modal popup showing the picker content', (tester) async {
    await tester.pumpWidget(_wrap(
      doneLabel: 'Done',
      pickerBuilder: (ctx) => const Text('Picker content'),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Picker content'), findsOneWidget);
  });

  testWidgets('shows a Done button with the given label', (tester) async {
    await tester.pumpWidget(_wrap(
      doneLabel: 'Finish',
      pickerBuilder: (ctx) => const SizedBox.shrink(),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(CupertinoButton, 'Finish'), findsOneWidget);
  });

  testWidgets('tapping Done dismisses the sheet', (tester) async {
    await tester.pumpWidget(_wrap(
      doneLabel: 'Done',
      pickerBuilder: (ctx) => const Text('Picker content'),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Picker content'), findsOneWidget);

    await tester.tap(find.widgetWithText(CupertinoButton, 'Done'));
    await tester.pumpAndSettle();

    expect(find.text('Picker content'), findsNothing);
  });

  testWidgets('picker content area has a fixed height of 216', (tester) async {
    await tester.pumpWidget(_wrap(
      doneLabel: 'Done',
      pickerBuilder: (ctx) => const SizedBox.shrink(),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate((w) => w is SizedBox && w.height == 216), findsOneWidget);
  });

  testWidgets('the returned future completes only once the sheet is dismissed', (tester) async {
    var completed = false;
    await tester.pumpWidget(CupertinoApp(
      home: Builder(
        builder: (context) => CupertinoButton(
          onPressed: () {
            unawaited(showCupertinoPickerSheet(
              context: context,
              doneLabel: 'Done',
              pickerBuilder: (ctx) => const SizedBox.shrink(),
            ).then((_) => completed = true));
          },
          child: const Text('Open'),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(completed, isFalse);

    await tester.tap(find.widgetWithText(CupertinoButton, 'Done'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });

  testWidgets('pickerBuilder receives a BuildContext usable for MediaQuery lookups', (tester) async {
    BuildContext? receivedContext;
    await tester.pumpWidget(_wrap(
      doneLabel: 'Done',
      pickerBuilder: (ctx) {
        receivedContext = ctx;
        return const SizedBox.shrink();
      },
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(receivedContext, isNotNull);
    expect(MediaQuery.maybeOf(receivedContext!), isNotNull);
  });
}
