import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp, Theme;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
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

Widget _buildApp(PactDetailState state) {
  return MaterialApp(
    theme: HabitLoopTheme.materialTheme,
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
    ),
  );
}

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
}
