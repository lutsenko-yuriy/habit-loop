import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp, Theme;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';
import 'package:habit_loop/slices/showup/ui/ios/showup_detail_page_ios.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

final _showup = Showup(
  id: 's1',
  pactId: 'p1',
  scheduledAt: DateTime(2026, 3, 29, 8, 0),
  duration: const Duration(minutes: 10),
  status: ShowupStatus.pending,
);

Widget _buildApp(ShowupDetailState state) {
  return MaterialApp(
    theme: HabitLoopTheme.materialTheme,
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
}
