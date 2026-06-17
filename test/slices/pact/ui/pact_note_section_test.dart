import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_note_section.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: HabitLoopTheme.materialTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

PactNoteSection _section({
  String? savedNote,
  bool isSaving = false,
  Object? noteError,
}) {
  return PactNoteSection(
    savedNote: savedNote,
    isSaving: isSaving,
    noteError: noteError,
    labelColor: Colors.grey,
    errorColor: Colors.red,
    onSaveNote: (_) async {},
    slots: (
      buildNoteField: (ctx, controller) => TextField(key: const Key('field'), controller: controller),
      buildSaveButton: (ctx, onPressed) => ElevatedButton(
            key: const Key('save'),
            onPressed: onPressed,
            child: const Text('Save'),
          ),
    ),
  );
}

void main() {
  group('PactNoteSection – didUpdateWidget', () {
    testWidgets('syncs controller when savedNote changes externally', (tester) async {
      await tester.pumpWidget(_wrap(_section(savedNote: 'original')));
      expect(find.text('original'), findsOneWidget);

      await tester.pumpWidget(_wrap(_section(savedNote: 'updated externally')));
      await tester.pump();

      expect(find.text('updated externally'), findsOneWidget);
    });

    testWidgets('does not overwrite unsaved user edits when savedNote is unchanged', (tester) async {
      await tester.pumpWidget(_wrap(_section(savedNote: 'saved')));

      await tester.enterText(find.byKey(const Key('field')), 'user is typing');
      await tester.pump();

      // Rebuild with same savedNote — controller must keep user's text.
      await tester.pumpWidget(_wrap(_section(savedNote: 'saved')));
      await tester.pump();

      expect(find.text('user is typing'), findsOneWidget);
    });
  });

  group('PactNoteSection – error state', () {
    testWidgets('shows error text when noteError is non-null', (tester) async {
      await tester.pumpWidget(_wrap(_section(noteError: Exception('save failed'))));
      await tester.pump();

      final l10n = AppLocalizations.of(tester.element(find.byType(PactNoteSection)))!;
      expect(find.text(l10n.pactNoteError), findsOneWidget);
    });

    testWidgets('hides error text when noteError is null', (tester) async {
      await tester.pumpWidget(_wrap(_section()));
      await tester.pump();

      final l10n = AppLocalizations.of(tester.element(find.byType(PactNoteSection)))!;
      expect(find.text(l10n.pactNoteError), findsNothing);
    });
  });
}
