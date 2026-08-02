import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_detail_page_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_animated_value.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_state.dart';
import 'package:habit_loop/theme/widgets/section_header.dart';

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

final _predecessorPact = Pact(
  id: 'root',
  habitName: 'Vibe coding',
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2026, 3, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.stopped,
);

final _successorPact = Pact(
  id: 'v2',
  habitName: 'Meditate (v2)',
  startDate: DateTime(2026, 9, 2),
  endDate: DateTime(2027, 3, 2),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
  predecessorPactId: 'p1',
);

final _fixedEndBreak = PactBreak(
  id: 'brk-1',
  pactId: 'p1',
  startDate: DateTime(2026, 3, 10),
  plannedEndDate: DateTime(2026, 3, 20),
  rationale: 'Feeling sick',
);

final _openEndedBreak = PactBreak(
  id: 'brk-2',
  pactId: 'p1',
  startDate: DateTime(2026, 3, 10),
  rationale: 'Travelling',
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

  group('PactDetailPageAndroid – Take a break button (HAB-195)', () {
    testWidgets('shows button for an active pact when onStartBreak is provided', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: _loadedState(_activePact),
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onStartBreak: () {},
          ),
        ),
      );
      await tester.pump();
      // skipOffstage: false — the button now sits far enough down the
      // ListView to be off the default test viewport, and the default
      // (skipOffstage: true) finder used by ensureVisible would find
      // nothing to scroll to in the first place.
      await tester.ensureVisible(find.byKey(const Key('pact-detail-start-break-button'), skipOffstage: false));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pact-detail-start-break-button')), findsOneWidget);
    });

    testWidgets('hides button when onStartBreak is null (flag off or break already active)', (tester) async {
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
      expect(find.byKey(const Key('pact-detail-start-break-button')), findsNothing);
    });

    testWidgets('hides button for a stopped pact even when onStartBreak is provided', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: _loadedState(_stoppedPact),
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onStartBreak: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pact-detail-start-break-button')), findsNothing);
    });

    testWidgets('tapping the button calls onStartBreak', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: _loadedState(_activePact),
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onStartBreak: () => tapped = true,
          ),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('pact-detail-start-break-button'), skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pact-detail-start-break-button')));
      expect(tapped, isTrue);
    });
  });

  group('PactDetailPageAndroid — Resume pact banner (HAB-195 WU5.2)', () {
    testWidgets('shows banner with rationale and end date for a fixed-end break', (tester) async {
      final state = PactDetailState(
          pact: _activePact, stats: _stats, isLoading: false, activeBreak: _fixedEndBreak, isBreakActiveNow: true);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onStopBreak: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-break-banner')), findsOneWidget);
      expect(find.text('Feeling sick'), findsOneWidget);
      expect(find.textContaining(formatLocaleDate(DateTime(2026, 3, 20))), findsOneWidget);
    });

    testWidgets('shows open-ended copy when the break has no planned end date', (tester) async {
      final state = PactDetailState(
          pact: _activePact, stats: _stats, isLoading: false, activeBreak: _openEndedBreak, isBreakActiveNow: true);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onStopBreak: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.breakUntilPactEnds), findsOneWidget);
    });

    testWidgets('hides banner when there is no active break', (tester) async {
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

      expect(find.byKey(const Key('pact-detail-break-banner')), findsNothing);
    });

    testWidgets('tapping Resume pact opens a confirmation dialog; confirming calls onStopBreak', (tester) async {
      var called = false;
      final state = PactDetailState(
          pact: _activePact, stats: _stats, isLoading: false, activeBreak: _fixedEndBreak, isBreakActiveNow: true);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onStopBreak: () async {
              called = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('pact-detail-resume-pact-button'), skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pact-detail-resume-pact-button')));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.resumePactTitle), findsOneWidget);

      await tester.tap(find.text(l10n.resumePactConfirm));
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });

    testWidgets('cancelling the confirmation dialog does not call onStopBreak', (tester) async {
      var called = false;
      final state = PactDetailState(
          pact: _activePact, stats: _stats, isLoading: false, activeBreak: _fixedEndBreak, isBreakActiveNow: true);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onStopBreak: () async {
              called = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('pact-detail-resume-pact-button'), skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pact-detail-resume-pact-button')));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      expect(called, isFalse);
    });

    testWidgets('shows resumePactError text when stopBreakError is set', (tester) async {
      final state = PactDetailState(
        pact: _activePact,
        stats: _stats,
        isLoading: false,
        activeBreak: _fixedEndBreak,
        isBreakActiveNow: true,
        stopBreakError: Exception('boom'),
      );
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onStopBreak: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.scrollUntilVisible(find.text(l10n.resumePactError), 200);
      expect(find.text(l10n.resumePactError), findsOneWidget);
    });

    testWidgets('animates the banner out instead of vanishing instantly when activeBreak becomes null', (tester) async {
      final withBreak = PactDetailState(
          pact: _activePact, stats: _stats, isLoading: false, activeBreak: _fixedEndBreak, isBreakActiveNow: true);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: withBreak,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onStopBreak: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pact-detail-break-banner')), findsOneWidget);

      final withoutBreak = _loadedState(_activePact);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: withoutBreak,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onStopBreak: () async {},
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('pact-detail-break-banner')), findsOneWidget,
          reason: 'The banner must still be visible/fading on the frame right after activeBreak becomes null');

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pact-detail-break-banner')), findsNothing);
    });

    testWidgets('shows a loading indicator on Resume pact while isStoppingBreak is true', (tester) async {
      final state = PactDetailState(
        pact: _activePact,
        stats: _stats,
        isLoading: false,
        activeBreak: _fixedEndBreak,
        isBreakActiveNow: true,
        isStoppingBreak: true,
      );
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onStopBreak: () async {},
          ),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(find.byType(CircularProgressIndicator), 200);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('PactDetailPageAndroid — chain links (HAB-202)', () {
    testWidgets('shows Previous Pact link when predecessor is provided and chaining is enabled', (tester) async {
      final state =
          PactDetailState(pact: _stoppedPact, stats: _stats, isLoading: false, predecessorPact: _predecessorPact);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            pactChainingEnabled: true,
            onOpenPreviousPact: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-previous-pact-link')), findsOneWidget);
      expect(find.textContaining('Vibe coding'), findsOneWidget);
    });

    testWidgets('hides Previous Pact link when predecessor is null', (tester) async {
      final state = PactDetailState(pact: _stoppedPact, stats: _stats, isLoading: false);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            pactChainingEnabled: true,
            onOpenPreviousPact: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-previous-pact-link')), findsNothing);
    });

    testWidgets('hides Previous Pact link when pactChainingEnabled is false, even with a predecessor', (tester) async {
      final state =
          PactDetailState(pact: _stoppedPact, stats: _stats, isLoading: false, predecessorPact: _predecessorPact);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onOpenPreviousPact: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-previous-pact-link')), findsNothing);
    });

    testWidgets('tapping Previous Pact link calls onOpenPreviousPact', (tester) async {
      var tapped = false;
      final state =
          PactDetailState(pact: _stoppedPact, stats: _stats, isLoading: false, predecessorPact: _predecessorPact);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            pactChainingEnabled: true,
            onOpenPreviousPact: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pact-detail-previous-pact-link')));
      expect(tapped, isTrue);
    });

    testWidgets('shows Next Pact link when successor is provided and chaining is enabled', (tester) async {
      final state = PactDetailState(pact: _stoppedPact, stats: _stats, isLoading: false, successorPact: _successorPact);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            pactChainingEnabled: true,
            onOpenNextPact: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-next-pact-link')), findsOneWidget);
      expect(find.textContaining('Meditate (v2)'), findsOneWidget);
    });

    testWidgets('hides Next Pact link when successor is null', (tester) async {
      final state = PactDetailState(pact: _stoppedPact, stats: _stats, isLoading: false);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            pactChainingEnabled: true,
            onOpenNextPact: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-next-pact-link')), findsNothing);
    });

    testWidgets('hides Next Pact link when pactChainingEnabled is false, even with a successor', (tester) async {
      final state = PactDetailState(pact: _stoppedPact, stats: _stats, isLoading: false, successorPact: _successorPact);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onOpenNextPact: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-next-pact-link')), findsNothing);
    });

    testWidgets('tapping Next Pact link calls onOpenNextPact', (tester) async {
      var tapped = false;
      final state = PactDetailState(pact: _stoppedPact, stats: _stats, isLoading: false, successorPact: _successorPact);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            pactChainingEnabled: true,
            onOpenNextPact: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pact-detail-next-pact-link')));
      expect(tapped, isTrue);
    });

    testWidgets('shows both Previous and Next Pact links for a pact with both a predecessor and a successor',
        (tester) async {
      final state = PactDetailState(
        pact: _stoppedPact,
        stats: _stats,
        isLoading: false,
        predecessorPact: _predecessorPact,
        successorPact: _successorPact,
      );
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            pactChainingEnabled: true,
            onOpenPreviousPact: () {},
            onOpenNextPact: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-previous-pact-link')), findsOneWidget);
      expect(find.byKey(const Key('pact-detail-next-pact-link')), findsOneWidget);
      // Same row, Previous to the left of Next.
      final previousPos = tester.getTopLeft(find.byKey(const Key('pact-detail-previous-pact-link')));
      final nextPos = tester.getTopLeft(find.byKey(const Key('pact-detail-next-pact-link')));
      expect(previousPos.dy, nextPos.dy);
      expect(previousPos.dx, lessThan(nextPos.dx));
    });
  });

  group('PactDetailPageAndroid — adjust and start again (HAB-202)', () {
    testWidgets('shows Adjust and start again button on stopped pact with no successor when chaining is enabled',
        (tester) async {
      final state = PactDetailState(pact: _stoppedPact, stats: _stats, isLoading: false);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            pactChainingEnabled: true,
            onAdjustAndStartAgain: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('pact-detail-adjust-and-start-again-button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.byKey(const Key('pact-detail-adjust-and-start-again-button')), findsOneWidget);
    });

    testWidgets('shows Adjust and start again button on completed pact with no successor when chaining is enabled',
        (tester) async {
      final state = PactDetailState(pact: _completedPact, stats: _stats, isLoading: false);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            pactChainingEnabled: true,
            onAdjustAndStartAgain: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('pact-detail-adjust-and-start-again-button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.byKey(const Key('pact-detail-adjust-and-start-again-button')), findsOneWidget);
    });

    testWidgets('hides Adjust and start again button when a successor already exists, shows Next Pact instead',
        (tester) async {
      final state = PactDetailState(pact: _stoppedPact, stats: _stats, isLoading: false, successorPact: _successorPact);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            pactChainingEnabled: true,
            onOpenNextPact: () {},
            onAdjustAndStartAgain: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('pact-detail-next-pact-link')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.byKey(const Key('pact-detail-adjust-and-start-again-button')), findsNothing);
      expect(find.byKey(const Key('pact-detail-next-pact-link')), findsOneWidget);
    });

    testWidgets('hides Adjust and start again button when pactChainingEnabled is false', (tester) async {
      final state = PactDetailState(pact: _stoppedPact, stats: _stats, isLoading: false);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            onAdjustAndStartAgain: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-adjust-and-start-again-button')), findsNothing);
    });

    testWidgets('hides Adjust and start again button when onAdjustAndStartAgain is null', (tester) async {
      final state = PactDetailState(pact: _stoppedPact, stats: _stats, isLoading: false);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            pactChainingEnabled: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-adjust-and-start-again-button')), findsNothing);
    });

    testWidgets('hides Adjust and start again button on an active pact even if onAdjustAndStartAgain is provided',
        (tester) async {
      final state = PactDetailState(pact: _activePact, stats: _stats, isLoading: false);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            pactChainingEnabled: true,
            onAdjustAndStartAgain: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-adjust-and-start-again-button')), findsNothing);
    });

    testWidgets('tapping Adjust and start again button calls onAdjustAndStartAgain', (tester) async {
      var tapped = false;
      final state = PactDetailState(pact: _stoppedPact, stats: _stats, isLoading: false);
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: state,
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            pactChainingEnabled: true,
            onAdjustAndStartAgain: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('pact-detail-adjust-and-start-again-button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.byKey(const Key('pact-detail-adjust-and-start-again-button')));
      expect(tapped, isTrue);
    });
  });

  group('PactDetailPageAndroid — chain navigation content transition (HAB-206 WU3)', () {
    testWidgets('title and stat values animate on chain navigation; section headers do not', (tester) async {
      final pactA = _activePact;
      final pactB = Pact(
        id: 'p2',
        habitName: 'Journal',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 9, 1),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
        status: PactStatus.active,
        reminderOffset: const Duration(minutes: 5),
      );
      final statsB = _stats.copyWith(showupsDone: 9);

      // originalPactId is pinned to pactA.id in BOTH pumps — matching
      // PactDetailScreen's real behavior (stable across a chain-link swap,
      // HAB-206 WU3) rather than defaulting to each state's own pact.id.
      // Without this, the ListView's key would itself differ between the
      // two pumps, tearing down and rebuilding the whole subtree — which
      // exercises PactDetailAnimatedValue's initState path instead of the
      // didUpdateWidget path a stable Element actually takes in production,
      // and would silently fail to catch a regression in the latter.
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: _loadedState(pactA),
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            originalPactId: pactA.id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: PactDetailState(pact: pactB, stats: statsB, isLoading: false),
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            chainNavigationDirection: ChainNavigationDirection.toSuccessor,
            previousState: _loadedState(pactA),
            originalPactId: pactA.id,
          ),
        ),
      );

      // Mid-transition: both habit names visible simultaneously — the value
      // wrapper keeps the outgoing one around until the animation completes.
      await tester.pump(const Duration(milliseconds: 125));
      expect(find.text('Meditate'), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(PactDetailAnimatedValue), matching: find.byType(Opacity)),
        findsWidgets,
      );

      // Section headers are pact-independent chrome — never wrapped, so
      // never mid-animation regardless of what else is transitioning.
      expect(
        find.descendant(of: find.byType(PactDetailAnimatedValue), matching: find.byType(SectionHeader)),
        findsNothing,
      );

      await tester.pumpAndSettle();
      expect(find.text('Meditate'), findsNothing);
      expect(find.text('Journal'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(PactDetailAnimatedValue), matching: find.byType(Opacity)),
        findsNothing,
      );
    });

    testWidgets('shows the outgoing pact\'s own content, not a spinner, while a chain-link reload is in flight',
        (tester) async {
      final pactA = _activePact;

      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: _loadedState(pactA),
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            originalPactId: pactA.id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The incoming pact's own state hasn't resolved yet (isLoading: true,
      // no pact/stats) — this is exactly the gap that used to fall through
      // to the generic spinner. previousState carries the outgoing pact's
      // already-loaded content across it instead (HAB-206 WU3).
      await tester.pumpWidget(
        _testApp(
          child: PactDetailPageAndroid(
            state: const PactDetailState(),
            onStopPact: (_) async {},
            onSaveNote: (_) async {},
            onArchivePact: (_) async {},
            chainNavigationDirection: ChainNavigationDirection.toSuccessor,
            previousState: _loadedState(pactA),
            originalPactId: pactA.id,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Meditate'), findsOneWidget);
    });
  });
}
