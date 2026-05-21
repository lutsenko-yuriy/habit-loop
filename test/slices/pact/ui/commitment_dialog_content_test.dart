import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/commitment_dialog_content.dart';

// ---------------------------------------------------------------------------
// Helper: pump CommitmentDialogContent inside a minimal app with l10n.
// ---------------------------------------------------------------------------

Widget _wrap({
  required String variant,
  required String habitName,
  required VoidCallback onAccept,
  required VoidCallback onDismiss,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: CommitmentDialogContent(
          variant: variant,
          habitName: habitName,
          onAccept: onAccept,
          onDismiss: onDismiss,
        ),
      ),
    ),
  );
}

void main() {
  group('CommitmentDialogContent — button variant', () {
    testWidgets('shows the commitment rules text', (tester) async {
      await tester.pumpWidget(_wrap(
        variant: 'button',
        habitName: 'Meditate',
        onAccept: () {},
        onDismiss: () {},
      ));

      expect(find.byKey(const Key('commitment-dialog-warning')), findsOneWidget);
    });

    testWidgets('shows I-accept action button', (tester) async {
      await tester.pumpWidget(_wrap(
        variant: 'button',
        habitName: 'Meditate',
        onAccept: () {},
        onDismiss: () {},
      ));

      expect(find.byKey(const Key('commitment-dialog-accept')), findsOneWidget);
    });

    testWidgets('accept button is always enabled', (tester) async {
      await tester.pumpWidget(_wrap(
        variant: 'button',
        habitName: 'Meditate',
        onAccept: () {},
        onDismiss: () {},
      ));

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('commitment-dialog-accept')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping accept button calls onAccept', (tester) async {
      bool accepted = false;
      await tester.pumpWidget(_wrap(
        variant: 'button',
        habitName: 'Meditate',
        onAccept: () => accepted = true,
        onDismiss: () {},
      ));

      await tester.tap(find.byKey(const Key('commitment-dialog-accept')));
      expect(accepted, isTrue);
    });

    testWidgets('tapping cancel calls onDismiss', (tester) async {
      bool dismissed = false;
      await tester.pumpWidget(_wrap(
        variant: 'button',
        habitName: 'Meditate',
        onAccept: () {},
        onDismiss: () => dismissed = true,
      ));

      await tester.tap(find.byKey(const Key('commitment-dialog-cancel')));
      expect(dismissed, isTrue);
    });

    testWidgets('does NOT show checkbox or retype field', (tester) async {
      await tester.pumpWidget(_wrap(
        variant: 'button',
        habitName: 'Meditate',
        onAccept: () {},
        onDismiss: () {},
      ));

      expect(find.byKey(const Key('commitment-dialog-checkbox')), findsNothing);
      expect(find.byKey(const Key('commitment-dialog-retype-field')), findsNothing);
    });
  });

  group('CommitmentDialogContent — checkbox variant', () {
    testWidgets('shows the checkbox', (tester) async {
      await tester.pumpWidget(_wrap(
        variant: 'checkbox',
        habitName: 'Meditate',
        onAccept: () {},
        onDismiss: () {},
      ));

      expect(find.byKey(const Key('commitment-dialog-checkbox')), findsOneWidget);
    });

    testWidgets('accept button is disabled when checkbox is unticked', (tester) async {
      await tester.pumpWidget(_wrap(
        variant: 'checkbox',
        habitName: 'Meditate',
        onAccept: () {},
        onDismiss: () {},
      ));

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('commitment-dialog-accept')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('accept button is enabled after ticking checkbox', (tester) async {
      await tester.pumpWidget(_wrap(
        variant: 'checkbox',
        habitName: 'Meditate',
        onAccept: () {},
        onDismiss: () {},
      ));

      await tester.tap(find.byKey(const Key('commitment-dialog-checkbox')));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('commitment-dialog-accept')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping accept after checking calls onAccept', (tester) async {
      bool accepted = false;
      await tester.pumpWidget(_wrap(
        variant: 'checkbox',
        habitName: 'Meditate',
        onAccept: () => accepted = true,
        onDismiss: () {},
      ));

      await tester.tap(find.byKey(const Key('commitment-dialog-checkbox')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('commitment-dialog-accept')));

      expect(accepted, isTrue);
    });
  });

  group('CommitmentDialogContent — retype variant', () {
    testWidgets('shows the retype text field', (tester) async {
      await tester.pumpWidget(_wrap(
        variant: 'retype',
        habitName: 'Meditate',
        onAccept: () {},
        onDismiss: () {},
      ));

      expect(find.byKey(const Key('commitment-dialog-retype-field')), findsOneWidget);
    });

    testWidgets('accept button is disabled when field is empty', (tester) async {
      await tester.pumpWidget(_wrap(
        variant: 'retype',
        habitName: 'Meditate',
        onAccept: () {},
        onDismiss: () {},
      ));

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('commitment-dialog-accept')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('accept button is disabled when typed text does not match', (tester) async {
      await tester.pumpWidget(_wrap(
        variant: 'retype',
        habitName: 'Meditate',
        onAccept: () {},
        onDismiss: () {},
      ));

      await tester.enterText(find.byKey(const Key('commitment-dialog-retype-field')), 'Wrong');
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('commitment-dialog-accept')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('accept button is enabled when typed text matches exactly', (tester) async {
      await tester.pumpWidget(_wrap(
        variant: 'retype',
        habitName: 'Meditate',
        onAccept: () {},
        onDismiss: () {},
      ));

      await tester.enterText(find.byKey(const Key('commitment-dialog-retype-field')), 'Meditate');
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('commitment-dialog-accept')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('accept button is enabled with different casing', (tester) async {
      await tester.pumpWidget(_wrap(
        variant: 'retype',
        habitName: 'Meditate',
        onAccept: () {},
        onDismiss: () {},
      ));

      await tester.enterText(find.byKey(const Key('commitment-dialog-retype-field')), 'meditate');
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('commitment-dialog-accept')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('accept button is enabled with leading/trailing whitespace', (tester) async {
      await tester.pumpWidget(_wrap(
        variant: 'retype',
        habitName: 'Meditate',
        onAccept: () {},
        onDismiss: () {},
      ));

      await tester.enterText(find.byKey(const Key('commitment-dialog-retype-field')), '  Meditate  ');
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('commitment-dialog-accept')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping accept with matching text calls onAccept', (tester) async {
      bool accepted = false;
      await tester.pumpWidget(_wrap(
        variant: 'retype',
        habitName: 'Meditate',
        onAccept: () => accepted = true,
        onDismiss: () {},
      ));

      await tester.enterText(find.byKey(const Key('commitment-dialog-retype-field')), 'Meditate');
      await tester.pump();
      await tester.tap(find.byKey(const Key('commitment-dialog-accept')));

      expect(accepted, isTrue);
    });
  });
}
