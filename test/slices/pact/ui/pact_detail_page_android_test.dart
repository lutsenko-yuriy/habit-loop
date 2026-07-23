import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_detail_page_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_state.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _activePact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 3, 1),
  endDate: DateTime(2026, 9, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
  reminderOffset: const Duration(minutes: 5),
);

final _stoppedPact = _activePact.copyWith(
  status: PactStatus.stopped,
  stoppedAt: DateTime(2026, 4, 1),
);

final _completedPact = _activePact.copyWith(status: PactStatus.completed);

final _stats = PactStats(
  showupsDone: 5,
  showupsFailed: 2,
  showupsRemaining: 10,
  totalShowups: 17,
  currentStreak: 3,
  startDate: DateTime(2026, 3, 1),
  endDate: DateTime(2026, 9, 1),
);

PactDetailState _loadedState(Pact pact) => PactDetailState(
      pact: pact,
      stats: _stats,
      isLoading: false,
    );

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _testApp({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PactDetailPageAndroid – edit button visibility', () {
    testWidgets('shows edit button when pact is active and onEditPact is provided', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: _loadedState(_activePact),
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onEditPact: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-edit-button')), findsOneWidget);
    });

    testWidgets('hides edit button when pact is active but onEditPact is null', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: _loadedState(_activePact),
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            // onEditPact intentionally omitted
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-edit-button')), findsNothing);
    });

    testWidgets('hides edit button when pact is stopped', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: _loadedState(_stoppedPact),
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onEditPact: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-edit-button')), findsNothing);
    });

    testWidgets('hides edit button when pact is completed', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: _loadedState(_completedPact),
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onEditPact: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-edit-button')), findsNothing);
    });

    testWidgets('edit button invokes onEditPact when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: _loadedState(_activePact),
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onEditPact: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pact-detail-edit-button')));
      expect(tapped, isTrue);
    });
  });

  group('PactDetailPageAndroid – note save button', () {
    testWidgets('save-note button is a FilledButton (not ElevatedButton)', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: _loadedState(_stoppedPact),
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down — the extra "stopped on" date row pushes the note section
      // below the default test viewport height.
      final saveButtonFinder = find.byKey(const Key('pact-note-save-button'));
      await tester.scrollUntilVisible(saveButtonFinder, 200);

      expect(saveButtonFinder, findsOneWidget);
      expect(tester.widget<FilledButton>(saveButtonFinder), isA<FilledButton>());
    });
  });

  group('PactDetailPageAndroid – showup duration and reminder rows', () {
    testWidgets('shows showup duration row with correct value', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: _loadedState(_activePact),
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // _activePact.showupDuration = 10 minutes → "10 min"
      expect(find.text('10 min'), findsOneWidget);
    });

    testWidgets('shows reminder row with offset when reminder is set', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: _loadedState(_activePact),
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // _activePact.reminderOffset = 5 minutes → "5 min before"
      expect(find.textContaining('5'), findsAtLeastNWidgets(1));
      // Reminder label is present
      expect(find.text('Reminder'), findsOneWidget);
    });

    testWidgets('shows "No reminder" when reminderOffset is null', (tester) async {
      final pactNoReminder = _activePact.copyWith(clearReminderOffset: true);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: _loadedState(pactNoReminder),
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No reminder'), findsOneWidget);
    });
  });
}
