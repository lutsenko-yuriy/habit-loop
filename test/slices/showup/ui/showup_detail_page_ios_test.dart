import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp, Theme;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/checklist/checklist_gate.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';
import 'package:habit_loop/slices/showup/ui/ios/showup_detail_page_ios.dart';
import 'package:habit_loop/theme/colors.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

final _showup = Showup(
  id: 's1',
  pactId: 'p1',
  scheduledAt: DateTime(2026, 3, 29, 8, 0),
  duration: const Duration(minutes: 10),
  status: ShowupStatus.pending,
);

final _redeemableShowup = Showup(
  id: 's2',
  pactId: 'p1',
  scheduledAt: DateTime(2026, 3, 29, 8, 0),
  duration: const Duration(minutes: 10),
  status: ShowupStatus.failed,
  redeemable: true,
);

Widget _buildApp(
  ShowupDetailState state, {
  Future<void> Function()? onRedeemShowup,
  Future<void> Function()? onRunChecklist,
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
    home: ShowupDetailPageIos(
      state: state,
      onMarkDone: () async {},
      onMarkFailed: () async {},
      onSaveNote: (_) async {},
      onRedeemShowup: onRedeemShowup ?? () async {},
      onRunChecklist: onRunChecklist ?? () async {},
    ),
  );
}

void main() {
  testWidgets('iOS showup detail nav bar has explicit surface backgroundColor to prevent white-on-scroll',
      (tester) async {
    final state = ShowupDetailState(
      showup: _showup,
      habitName: 'Meditate',
      isLoading: false,
      uiState: ShowupUiState.planned,
    );
    await tester.pumpWidget(_buildApp(state));

    final navBar = tester.widget<CupertinoNavigationBar>(find.byType(CupertinoNavigationBar));
    final theme = Theme.of(tester.element(find.byType(ShowupDetailPageIos)));

    expect(navBar.backgroundColor, theme.colorScheme.surface);
  });

  testWidgets('iOS showup detail scaffold has surface backgroundColor', (tester) async {
    final state = ShowupDetailState(
      showup: _showup,
      habitName: 'Meditate',
      isLoading: false,
      uiState: ShowupUiState.planned,
    );
    await tester.pumpWidget(_buildApp(state));

    final scaffold = tester.widget<CupertinoPageScaffold>(find.byType(CupertinoPageScaffold));
    final theme = Theme.of(tester.element(find.byType(ShowupDetailPageIos)));

    expect(scaffold.backgroundColor, theme.colorScheme.surface);
  });

  testWidgets('iOS: redeem button is visible and enabled when canRedeem=true and note is non-empty', (tester) async {
    final state = ShowupDetailState(
      showup: _redeemableShowup.copyWith(note: 'I was there'),
      habitName: 'Meditate',
      isLoading: false,
      uiState: ShowupUiState.failed,
      canRedeem: true,
    );
    await tester.pumpWidget(_buildApp(state));
    await tester.pump();

    final redeemFinder = find.widgetWithText(CupertinoButton, 'Mark as Done (redeem)');
    expect(redeemFinder, findsOneWidget);
    final btn = tester.widget<CupertinoButton>(redeemFinder);
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('iOS: redeem button is visible but disabled when canRedeem=true and note is empty', (tester) async {
    final state = ShowupDetailState(
      showup: _redeemableShowup,
      habitName: 'Meditate',
      isLoading: false,
      uiState: ShowupUiState.failed,
      canRedeem: true,
    );
    await tester.pumpWidget(_buildApp(state));
    await tester.pump();

    final redeemFinder = find.widgetWithText(CupertinoButton, 'Mark as Done (redeem)');
    expect(redeemFinder, findsOneWidget);
    final btn = tester.widget<CupertinoButton>(redeemFinder);
    expect(btn.onPressed, isNull);
  });

  testWidgets('iOS: hint text visible when canRedeem=true and note is empty', (tester) async {
    final state = ShowupDetailState(
      showup: _redeemableShowup,
      habitName: 'Meditate',
      isLoading: false,
      uiState: ShowupUiState.failed,
      canRedeem: true,
    );
    await tester.pumpWidget(_buildApp(state));
    await tester.pump();

    expect(find.text('Add a note to redeem this showup.'), findsOneWidget);
  });

  testWidgets('iOS: hint text absent when canRedeem=true and note is non-empty', (tester) async {
    final state = ShowupDetailState(
      showup: _redeemableShowup.copyWith(note: 'showed up'),
      habitName: 'Meditate',
      isLoading: false,
      uiState: ShowupUiState.failed,
      canRedeem: true,
    );
    await tester.pumpWidget(_buildApp(state));
    await tester.pump();

    expect(find.text('Add a note to redeem this showup.'), findsNothing);
  });

  testWidgets('iOS: redeem button absent when canRedeem=false', (tester) async {
    final state = ShowupDetailState(
      showup: _redeemableShowup,
      habitName: 'Meditate',
      isLoading: false,
      uiState: ShowupUiState.failed,
      canRedeem: false,
    );
    await tester.pumpWidget(_buildApp(state));
    await tester.pump();

    expect(find.widgetWithText(CupertinoButton, 'Mark as Done (redeem)'), findsNothing);
  });

  testWidgets('iOS: tapping redeem button calls onRedeemShowup', (tester) async {
    var called = false;
    final state = ShowupDetailState(
      showup: _redeemableShowup.copyWith(note: 'showed up'),
      habitName: 'Meditate',
      isLoading: false,
      uiState: ShowupUiState.failed,
      canRedeem: true,
    );
    await tester.pumpWidget(_buildApp(state, onRedeemShowup: () async {
      called = true;
    }));
    await tester.pump();

    await tester.tap(find.widgetWithText(CupertinoButton, 'Mark as Done (redeem)'));
    await tester.pump();

    expect(called, isTrue);
  });

  group('ShowupDetailPageIos — on-color pairing', () {
    // Targeted checks rather than a whole-screen meetsGuideline(textContrastGuideline)
    // sweep: the sibling "Save Note" CupertinoButton on this same screen hits a
    // separate, larger, deferred contrast issue (primaryColor used as text-on-surface
    // — HAB-187 debrief notes) that a whole-page sweep would trip regardless of this fix.
    // HabitLoopColors.secondaryText's own AA compliance is verified directly in
    // habit_loop_theme_test.dart.
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('redemption hint uses the AA-compliant secondary text color (${brightness.name})', (tester) async {
        final state = ShowupDetailState(
          showup: _redeemableShowup,
          habitName: 'Meditate',
          isLoading: false,
          uiState: ShowupUiState.failed,
          canRedeem: true,
        );
        await tester.pumpWidget(_buildApp(state, brightness: brightness));
        await tester.pump();

        final ctx = tester.element(find.byType(ShowupDetailPageIos));
        final l10n = AppLocalizations.of(ctx)!;
        final hintText = tester.widget<Text>(find.text(l10n.showupRedeemAddNoteHint));
        expect(hintText.style?.color, HabitLoopColors.secondaryText(ctx));
      });
    }
  });

  group('checklist gate (GH #464)', () {
    ShowupDetailState gated({bool couldNotOpen = false, bool starting = false}) => ShowupDetailState(
          showup: _showup,
          habitName: 'Meditate',
          isLoading: false,
          uiState: ShowupUiState.planned,
          checklistGate: ChecklistGate.runRequired,
          checklistRunCouldNotOpen: couldNotOpen,
          isStartingChecklistRun: starting,
        );

    testWidgets('runRequired: Run checklist replaces Mark as done; Mark as failed stays', (tester) async {
      var runs = 0;
      await tester.pumpWidget(_buildApp(gated(), onRunChecklist: () async => runs++));
      final l10n = AppLocalizations.of(tester.element(find.byType(ShowupDetailPageIos)))!;

      expect(find.text(l10n.markDone), findsNothing);
      expect(find.text(l10n.markFailed), findsOneWidget);
      await tester.tap(find.byKey(const Key('showup-run-checklist-button')));
      expect(runs, 1);
    });

    testWidgets('unlocked: Mark as done is back', (tester) async {
      await tester.pumpWidget(_buildApp(gated().copyWith(checklistGate: ChecklistGate.unlocked)));
      final l10n = AppLocalizations.of(tester.element(find.byType(ShowupDetailPageIos)))!;
      expect(find.text(l10n.markDone), findsOneWidget);
      expect(find.byKey(const Key('showup-run-checklist-button')), findsNothing);
    });

    testWidgets('could not open Checklister: error shown', (tester) async {
      await tester.pumpWidget(_buildApp(gated(couldNotOpen: true)));
      final l10n = AppLocalizations.of(tester.element(find.byType(ShowupDetailPageIos)))!;
      expect(find.text(l10n.checklisterCouldNotOpenError), findsOneWidget);
    });

    testWidgets('while saving: Run checklist keeps its enabled colour (no grey flash)', (tester) async {
      await tester.pumpWidget(_buildApp(gated().copyWith(isSaving: true)));
      final ctx = tester.element(find.byType(ShowupDetailPageIos));
      final button = tester.widget<CupertinoButton>(find.byKey(const Key('showup-run-checklist-button')));
      expect(button.onPressed, isNull);
      expect(button.disabledColor, CupertinoTheme.of(ctx).primaryColor);
    });

    testWidgets('while starting: Run checklist is disabled', (tester) async {
      var runs = 0;
      await tester.pumpWidget(_buildApp(gated(starting: true), onRunChecklist: () async => runs++));
      await tester.tap(find.byKey(const Key('showup-run-checklist-button')), warnIfMissed: false);
      expect(runs, 0);
    });
  });
}
