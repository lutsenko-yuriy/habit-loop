import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/showup/ui/android/showup_detail_page_android.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

final _pendingShowup = Showup(
  id: 's0',
  pactId: 'p1',
  scheduledAt: DateTime(2026, 3, 29, 8, 0),
  duration: const Duration(minutes: 10),
  status: ShowupStatus.pending,
);

final _redeemableShowup = Showup(
  id: 's1',
  pactId: 'p1',
  scheduledAt: DateTime(2026, 3, 29, 8, 0),
  duration: const Duration(minutes: 10),
  status: ShowupStatus.failed,
  redeemable: true,
);

Widget _buildApp(
  ShowupDetailState state, {
  Future<void> Function()? onRedeemShowup,
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
    home: ShowupDetailPageAndroid(
      state: state,
      onMarkDone: () async {},
      onMarkFailed: () async {},
      onSaveNote: (_) async {},
      onRedeemShowup: onRedeemShowup ?? () async {},
    ),
  );
}

void main() {
  testWidgets('Android: redeem button visible and enabled when canRedeem=true and note is non-empty', (tester) async {
    final state = ShowupDetailState(
      showup: _redeemableShowup.copyWith(note: 'I was there'),
      habitName: 'Meditate',
      isLoading: false,
      uiState: ShowupUiState.failed,
      canRedeem: true,
    );
    await tester.pumpWidget(_buildApp(state));
    await tester.pump();

    final redeemFinder = find.widgetWithText(FilledButton, 'Mark as Done (redeem)');
    expect(redeemFinder, findsOneWidget);
    final btn = tester.widget<FilledButton>(redeemFinder);
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('Android: redeem button visible but disabled when canRedeem=true and note is empty', (tester) async {
    final state = ShowupDetailState(
      showup: _redeemableShowup,
      habitName: 'Meditate',
      isLoading: false,
      uiState: ShowupUiState.failed,
      canRedeem: true,
    );
    await tester.pumpWidget(_buildApp(state));
    await tester.pump();

    final redeemFinder = find.widgetWithText(FilledButton, 'Mark as Done (redeem)');
    expect(redeemFinder, findsOneWidget);
    final btn = tester.widget<FilledButton>(redeemFinder);
    expect(btn.onPressed, isNull);
  });

  testWidgets('Android: hint text visible when canRedeem=true and note is empty', (tester) async {
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

  testWidgets('Android: hint text absent when canRedeem=true and note is non-empty', (tester) async {
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

  testWidgets('Android: redeem button absent when canRedeem=false', (tester) async {
    final state = ShowupDetailState(
      showup: _redeemableShowup,
      habitName: 'Meditate',
      isLoading: false,
      uiState: ShowupUiState.failed,
      canRedeem: false,
    );
    await tester.pumpWidget(_buildApp(state));
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Mark as Done (redeem)'), findsNothing);
  });

  testWidgets('Android: tapping redeem button calls onRedeemShowup', (tester) async {
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

    await tester.tap(find.widgetWithText(FilledButton, 'Mark as Done (redeem)'));
    await tester.pump();

    expect(called, isTrue);
  });

  group('ShowupDetailPageAndroid — Mark Done button on-color pairing', () {
    // Scoped to just this button's foregroundColor rather than a full-screen
    // meetsGuideline(textContrastGuideline) sweep: the sibling "Mark as Failed"
    // button on this same screen has a separate, larger, deferred contrast issue
    // (colorScheme.error used as text-on-surface — HAB-187 debrief notes) that
    // is out of scope here and would make a whole-screen sweep fail regardless
    // of this fix.
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('foregroundColor is onSecondary, pairing with its secondary background (${brightness.name})',
          (tester) async {
        final state = ShowupDetailState(
          showup: _pendingShowup,
          habitName: 'Meditate',
          isLoading: false,
          uiState: ShowupUiState.planned,
        );
        await tester.pumpWidget(_buildApp(state, brightness: brightness));
        await tester.pump();

        final theme = Theme.of(tester.element(find.byType(ShowupDetailPageAndroid)));
        final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Mark as Done'));
        expect(button.style?.foregroundColor?.resolve({}), theme.colorScheme.onSecondary);
      });
    }
  });
}
