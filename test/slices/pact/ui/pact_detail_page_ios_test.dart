import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator, MaterialApp, Theme;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_state.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_detail_page_ios.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

final _pact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 3, 1),
  endDate: DateTime(2026, 9, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
);

final _stoppedPact = _pact.copyWith(
  status: PactStatus.stopped,
  stoppedAt: DateTime(2026, 4, 1),
);

final _completedPact = _pact.copyWith(status: PactStatus.completed);

final _stats = PactStats(
  showupsDone: 5,
  showupsFailed: 2,
  showupsRemaining: 10,
  totalShowups: 17,
  currentStreak: 3,
  startDate: DateTime(2026, 3, 1),
  endDate: DateTime(2026, 9, 1),
);

Widget _buildApp(
  PactDetailState state, {
  bool pactTimelineEnabled = false,
  VoidCallback? onOpenTimeline,
  VoidCallback? onStartBreak,
  Future<void> Function()? onStopBreak,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: brightness == Brightness.dark ? HabitLoopTheme.darkMaterialTheme : HabitLoopTheme.materialTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: PactDetailPageIos(
      state: state,
      onStopPact: (_) async {},
      onSaveNote: (_) async {},
      onArchivePact: (_) async {},
      pactTimelineEnabled: pactTimelineEnabled,
      onOpenTimeline: onOpenTimeline,
      onStartBreak: onStartBreak,
      onStopBreak: onStopBreak ?? () async {},
    ),
  );
}

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

PactDetailState _loadedState(Pact pact) => PactDetailState(pact: pact, stats: _stats, isLoading: false);

void main() {
  group('PactDetailPageIos – note section visibility', () {
    testWidgets('shows note field for a stopped pact', (tester) async {
      await tester.pumpWidget(_buildApp(_loadedState(_stoppedPact)));
      await tester.pumpAndSettle();

      // Scroll down — the extra "stopped on" date row pushes the note section
      // below the default test viewport height.
      await tester.scrollUntilVisible(find.byKey(const Key('pact-note-field')), 200);

      expect(find.byKey(const Key('pact-note-field')), findsOneWidget);
      expect(find.byKey(const Key('pact-note-save-button')), findsOneWidget);
    });

    testWidgets('shows note field for a completed pact', (tester) async {
      await tester.pumpWidget(_buildApp(_loadedState(_completedPact)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-note-field')), findsOneWidget);
      expect(find.byKey(const Key('pact-note-save-button')), findsOneWidget);
    });

    testWidgets('does not show note field for an active pact', (tester) async {
      final state = PactDetailState(pact: _pact, stats: _stats, isLoading: false);
      await tester.pumpWidget(_buildApp(state));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-note-field')), findsNothing);
      expect(find.byKey(const Key('pact-note-save-button')), findsNothing);
    });
  });

  group('PactDetailPageIos — View Timeline button', () {
    testWidgets('shows timeline button when enabled and callback provided', (tester) async {
      bool tapped = false;
      final state = PactDetailState(pact: _pact, stats: _stats, isLoading: false);
      await tester.pumpWidget(_buildApp(
        state,
        pactTimelineEnabled: true,
        onOpenTimeline: () => tapped = true,
      ));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('pact-detail-timeline-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pact-detail-timeline-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pact-detail-timeline-button')));
      expect(tapped, isTrue);
    });

    testWidgets('hides timeline button when pactTimelineEnabled is false', (tester) async {
      final state = PactDetailState(pact: _pact, stats: _stats, isLoading: false);
      await tester.pumpWidget(_buildApp(
        state,
        pactTimelineEnabled: false,
        onOpenTimeline: () {},
      ));
      await tester.pump();
      expect(find.byKey(const Key('pact-detail-timeline-button')), findsNothing);
    });

    testWidgets('hides timeline button when onOpenTimeline is null', (tester) async {
      final state = PactDetailState(pact: _pact, stats: _stats, isLoading: false);
      await tester.pumpWidget(_buildApp(state, pactTimelineEnabled: true));
      await tester.pump();
      expect(find.byKey(const Key('pact-detail-timeline-button')), findsNothing);
    });
  });

  group('PactDetailPageIos — Take a break button (HAB-195)', () {
    testWidgets('shows button for an active pact when onStartBreak is provided', (tester) async {
      final state = PactDetailState(pact: _pact, stats: _stats, isLoading: false);
      await tester.pumpWidget(_buildApp(state, onStartBreak: () {}));
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
      final state = PactDetailState(pact: _pact, stats: _stats, isLoading: false);
      await tester.pumpWidget(_buildApp(state));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pact-detail-start-break-button')), findsNothing);
    });

    testWidgets('hides button for a stopped pact even when onStartBreak is provided', (tester) async {
      await tester.pumpWidget(_buildApp(_loadedState(_stoppedPact), onStartBreak: () {}));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pact-detail-start-break-button')), findsNothing);
    });

    testWidgets('tapping the button calls onStartBreak', (tester) async {
      bool tapped = false;
      final state = PactDetailState(pact: _pact, stats: _stats, isLoading: false);
      await tester.pumpWidget(_buildApp(state, onStartBreak: () => tapped = true));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('pact-detail-start-break-button'), skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pact-detail-start-break-button')));
      expect(tapped, isTrue);
    });
  });

  group('PactDetailPageIos — Resume pact banner (HAB-195 WU5.2)', () {
    testWidgets('shows banner with rationale and end date for a fixed-end break', (tester) async {
      final state = PactDetailState(
          pact: _pact, stats: _stats, isLoading: false, activeBreak: _fixedEndBreak, currentBreak: _fixedEndBreak);
      await tester.pumpWidget(_buildApp(state));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-break-banner')), findsOneWidget);
      expect(find.text('Feeling sick'), findsOneWidget);
      expect(find.textContaining(formatLocaleDate(DateTime(2026, 3, 20))), findsOneWidget);
    });

    testWidgets('shows open-ended copy when the break has no planned end date', (tester) async {
      final state = PactDetailState(
          pact: _pact, stats: _stats, isLoading: false, activeBreak: _openEndedBreak, currentBreak: _openEndedBreak);
      await tester.pumpWidget(_buildApp(state));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.breakUntilPactEnds), findsOneWidget);
    });

    testWidgets('hides banner and Take a break button area when there is no active break', (tester) async {
      final state = PactDetailState(pact: _pact, stats: _stats, isLoading: false);
      await tester.pumpWidget(_buildApp(state));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pact-detail-break-banner')), findsNothing);
    });

    testWidgets('tapping Resume pact opens a confirmation dialog; confirming calls onStopBreak', (tester) async {
      var called = false;
      final state = PactDetailState(
          pact: _pact, stats: _stats, isLoading: false, activeBreak: _fixedEndBreak, currentBreak: _fixedEndBreak);
      await tester.pumpWidget(_buildApp(state, onStopBreak: () async {
        called = true;
      }));
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
          pact: _pact, stats: _stats, isLoading: false, activeBreak: _fixedEndBreak, currentBreak: _fixedEndBreak);
      await tester.pumpWidget(_buildApp(state, onStopBreak: () async {
        called = true;
      }));
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
        pact: _pact,
        stats: _stats,
        isLoading: false,
        activeBreak: _fixedEndBreak,
        currentBreak: _fixedEndBreak,
        stopBreakError: Exception('boom'),
      );
      await tester.pumpWidget(_buildApp(state));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.scrollUntilVisible(find.text(l10n.resumePactError), 200);
      expect(find.text(l10n.resumePactError), findsOneWidget);
    });

    testWidgets('animates the banner out instead of vanishing instantly when activeBreak becomes null', (tester) async {
      final withBreak = PactDetailState(
          pact: _pact, stats: _stats, isLoading: false, activeBreak: _fixedEndBreak, currentBreak: _fixedEndBreak);
      await tester.pumpWidget(_buildApp(withBreak));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pact-detail-break-banner')), findsOneWidget);

      final withoutBreak = PactDetailState(pact: _pact, stats: _stats, isLoading: false);
      await tester.pumpWidget(_buildApp(withoutBreak));
      await tester.pump();
      expect(find.byKey(const Key('pact-detail-break-banner')), findsOneWidget,
          reason: 'The banner must still be visible/fading on the frame right after activeBreak becomes null');

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pact-detail-break-banner')), findsNothing);
    });

    testWidgets('shows a loading indicator on Resume pact while isStoppingBreak is true', (tester) async {
      final state = PactDetailState(
        pact: _pact,
        stats: _stats,
        isLoading: false,
        activeBreak: _fixedEndBreak,
        currentBreak: _fixedEndBreak,
        isStoppingBreak: true,
      );
      await tester.pumpWidget(_buildApp(state));
      await tester.pump();

      // The break banner is shared Material widgetry across both platforms
      // (HAB-195 WU5.2, `lib/slices/pact/ui/generic/break_banner.dart`), so
      // its loading indicator is a CircularProgressIndicator even on iOS.
      await tester.scrollUntilVisible(find.byType(CircularProgressIndicator), 200);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  testWidgets('iOS pact detail nav bar has explicit surface backgroundColor to prevent white-on-scroll',
      (tester) async {
    final state = PactDetailState(pact: _pact, stats: _stats, isLoading: false);
    await tester.pumpWidget(_buildApp(state));

    final navBar = tester.widget<CupertinoNavigationBar>(find.byType(CupertinoNavigationBar));
    final theme = Theme.of(tester.element(find.byType(PactDetailPageIos)));

    expect(navBar.backgroundColor, theme.colorScheme.surface);
  });

  testWidgets('iOS pact detail scaffold has surface backgroundColor', (tester) async {
    final state = PactDetailState(pact: _pact, stats: _stats, isLoading: false);
    await tester.pumpWidget(_buildApp(state));

    final scaffold = tester.widget<CupertinoPageScaffold>(find.byType(CupertinoPageScaffold));
    final theme = Theme.of(tester.element(find.byType(PactDetailPageIos)));

    expect(scaffold.backgroundColor, theme.colorScheme.surface);
  });

  group('PactDetailPageIos — WCAG AA contrast', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('pact detail text meets AA contrast in ${brightness.name} mode', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_buildApp(_loadedState(_stoppedPact), brightness: brightness));
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });
}
