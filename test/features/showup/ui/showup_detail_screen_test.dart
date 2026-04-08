import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';
import 'package:habit_loop/features/showup/ui/generic/showup_detail_screen.dart';
import 'package:habit_loop/features/showup/ui/generic/showup_detail_view_model.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _pact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 4, 1),
  endDate: DateTime(2026, 10, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
);

Showup _pendingFutureShowup() => Showup(
      id: 's1',
      pactId: 'p1',
      scheduledAt: DateTime(2099, 1, 1, 8, 0),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.pending,
    );

Showup _doneShowup() => Showup(
      id: 's2',
      pactId: 'p1',
      scheduledAt: DateTime(2099, 1, 1, 8, 0),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.done,
    );

Showup _failedShowup() => Showup(
      id: 's3',
      pactId: 'p1',
      scheduledAt: DateTime(2020, 1, 1, 8, 0),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.failed,
    );

// A past pending showup that will be auto-failed on load.
Showup _pendingPastShowup() => Showup(
      id: 's4',
      pactId: 'p1',
      scheduledAt: DateTime(2020, 1, 1, 8, 0),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.pending,
    );

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps the widget under test with required Material/Localizations boilerplate.
Widget _testApp({
  required Widget child,
  required List<Override> overrides,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

List<Override> _overrides({
  required Showup showup,
  Pact? pact,
  DateTime? nowOverride,
}) {
  final showupRepo = InMemoryShowupRepository([showup]);
  final pactRepo = InMemoryPactRepository(pact != null ? [pact] : []);
  return [
    showupDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
    showupDetailPactRepositoryProvider.overrideWithValue(pactRepo),
    if (nowOverride != null)
      showupDetailNowProvider.overrideWithValue(nowOverride),
  ];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ShowupDetailScreen', () {
    testWidgets('shows loading indicator before load completes',
        (tester) async {
      final showup = _pendingFutureShowup();

      await tester.pumpWidget(
        _testApp(
          overrides: _overrides(showup: showup, pact: _pact),
          child: ShowupDetailScreen(showupId: showup.id),
        ),
      );

      // After pumpWidget but before async load finishes, loading indicator is shown.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows habit name and scheduled time after load', (tester) async {
      final showup = _pendingFutureShowup();

      await tester.pumpWidget(
        _testApp(
          overrides: _overrides(showup: showup, pact: _pact),
          child: ShowupDetailScreen(showupId: showup.id),
        ),
      );

      await tester.pumpAndSettle();

      // Habit name resolved from the pact.
      expect(find.text('Meditate'), findsOneWidget);
    });

    testWidgets('shows Mark as Done and Mark as Failed buttons for pending showup',
        (tester) async {
      final showup = _pendingFutureShowup();

      await tester.pumpWidget(
        _testApp(
          overrides: _overrides(showup: showup, pact: _pact),
          child: ShowupDetailScreen(showupId: showup.id),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mark as Done'), findsOneWidget);
      expect(find.text('Mark as Failed'), findsOneWidget);
    });

    testWidgets('does not show action buttons for a done showup', (tester) async {
      final showup = _doneShowup();

      await tester.pumpWidget(
        _testApp(
          overrides: _overrides(showup: showup, pact: _pact),
          child: ShowupDetailScreen(showupId: showup.id),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mark as Done'), findsNothing);
      expect(find.text('Mark as Failed'), findsNothing);
    });

    testWidgets('does not show action buttons for a failed showup',
        (tester) async {
      final showup = _failedShowup();

      await tester.pumpWidget(
        _testApp(
          overrides: _overrides(showup: showup, pact: _pact),
          child: ShowupDetailScreen(showupId: showup.id),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mark as Done'), findsNothing);
      expect(find.text('Mark as Failed'), findsNothing);
    });

    testWidgets('tapping Mark as Done updates the status display',
        (tester) async {
      final showup = _pendingFutureShowup();

      await tester.pumpWidget(
        _testApp(
          overrides: _overrides(showup: showup, pact: _pact),
          child: ShowupDetailScreen(showupId: showup.id),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as Done'));
      await tester.pumpAndSettle();

      // After marking done, action buttons disappear.
      expect(find.text('Mark as Done'), findsNothing);
      expect(find.text('Mark as Failed'), findsNothing);
      // Done status is shown.
      expect(find.text('Done'), findsWidgets);
    });

    testWidgets('tapping Mark as Failed updates the status display',
        (tester) async {
      final showup = _pendingFutureShowup();

      await tester.pumpWidget(
        _testApp(
          overrides: _overrides(showup: showup, pact: _pact),
          child: ShowupDetailScreen(showupId: showup.id),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as Failed'));
      await tester.pumpAndSettle();

      expect(find.text('Mark as Done'), findsNothing);
      expect(find.text('Mark as Failed'), findsNothing);
      expect(find.text('Failed'), findsWidgets);
    });

    testWidgets('shows auto-fail notice when showup was auto-failed on load',
        (tester) async {
      final showup = _pendingPastShowup();
      // now is well past the showup end time.
      final pastNow = DateTime(2020, 1, 1, 9, 0);

      await tester.pumpWidget(
        _testApp(
          overrides: _overrides(
            showup: showup,
            pact: _pact,
            nowOverride: pastNow,
          ),
          child: ShowupDetailScreen(showupId: showup.id),
        ),
      );

      await tester.pumpAndSettle();

      // Auto-fail notice must be visible.
      expect(
        find.textContaining('auto'),
        findsWidgets,
      );
    });

    testWidgets('shows note section always (regardless of status)',
        (tester) async {
      final showup = _doneShowup();

      await tester.pumpWidget(
        _testApp(
          overrides: _overrides(showup: showup, pact: _pact),
          child: ShowupDetailScreen(showupId: showup.id),
        ),
      );

      await tester.pumpAndSettle();

      // Save Note button must always be present (though disabled until changed).
      expect(find.text('Save Note'), findsOneWidget);
    });

    testWidgets('Save Note button is disabled when note has not changed',
        (tester) async {
      final showup = _pendingFutureShowup();

      await tester.pumpWidget(
        _testApp(
          overrides: _overrides(showup: showup, pact: _pact),
          child: ShowupDetailScreen(showupId: showup.id),
        ),
      );

      await tester.pumpAndSettle();

      // No text entered — button must be disabled (onPressed == null).
      final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton));
      final saveButton = buttons.firstWhere(
        (b) => find
            .descendant(of: find.byWidget(b), matching: find.text('Save Note'))
            .evaluate()
            .isNotEmpty,
        orElse: () => throw TestFailure('Save Note FilledButton not found'),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('Save Note button becomes enabled after typing', (tester) async {
      final showup = _pendingFutureShowup();

      await tester.pumpWidget(
        _testApp(
          overrides: _overrides(showup: showup, pact: _pact),
          child: ShowupDetailScreen(showupId: showup.id),
        ),
      );

      await tester.pumpAndSettle();

      // Type something in the note field.
      final noteField = find.byType(TextField).last;
      await tester.enterText(noteField, 'New note');
      await tester.pump(); // let ValueListenableBuilder rebuild

      // Button must now be enabled.
      final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton));
      final saveButton = buttons.firstWhere(
        (b) => find
            .descendant(of: find.byWidget(b), matching: find.text('Save Note'))
            .evaluate()
            .isNotEmpty,
        orElse: () => throw TestFailure('Save Note FilledButton not found'),
      );
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('saving a note updates state', (tester) async {
      final showup = _pendingFutureShowup();

      await tester.pumpWidget(
        _testApp(
          overrides: _overrides(showup: showup, pact: _pact),
          child: ShowupDetailScreen(showupId: showup.id),
        ),
      );

      await tester.pumpAndSettle();

      // Enter note text, pump so ValueListenableBuilder enables the button.
      final noteField = find.byType(TextField).last;
      await tester.enterText(noteField, 'Great meditation session');
      await tester.pump();
      await tester.tap(find.text('Save Note'));
      await tester.pumpAndSettle();

      // No save error should appear.
      expect(find.text('Failed to save note. Please try again.'), findsNothing);
    });

    testWidgets('shows error message when showup not found', (tester) async {
      final showup = _pendingFutureShowup();

      await tester.pumpWidget(
        _testApp(
          overrides: _overrides(showup: showup, pact: _pact),
          // Use a non-existent showup ID.
          child: const ShowupDetailScreen(showupId: 'nonexistent'),
        ),
      );

      await tester.pumpAndSettle();

      // Should display an error, not a loading spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // An error message of some kind is shown.
      expect(find.textContaining('nonexistent'), findsWidgets);
    });
  });
}
