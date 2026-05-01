import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp, Theme;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_state.dart';
import 'package:habit_loop/slices/dashboard/ui/ios/dashboard_page_ios.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';

void main() {
  testWidgets('iOS dashboard uses scaffold color without custom home indicator affordances', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pactListViewModelProvider.overrideWith(_LoadedPactListViewModel.new),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(bottom: 34),
              viewPadding: EdgeInsets.only(bottom: 34),
            ),
            child: DashboardPageIos(
              state: const DashboardState(isLoading: false),
              hasPacts: true,
              onDaySelected: (_) {},
              onCreatePact: () async {},
              onShowupTapped: (_) async {},
            ),
          ),
        ),
      ),
    );

    final safeArea = tester.widget<SafeArea>(
      find.byKey(const Key('dashboard-ios-safe-area')),
    );
    final scaffold = tester.widget<CupertinoPageScaffold>(
      find.byType(CupertinoPageScaffold),
    );
    final theme = Theme.of(tester.element(find.byType(DashboardPageIos)));

    expect(scaffold.backgroundColor, theme.colorScheme.surface);
    expect(safeArea.bottom, isFalse);
    expect(find.byKey(const Key('dashboard-ios-bottom-panel-safe-area-fill')), findsNothing);
    expect(find.byKey(const Key('dashboard-ios-bottom-panel-safe-area-ignore-pointer')), findsNothing);
    expect(find.byKey(const Key('dashboard-ios-home-gesture-reserve')), findsNothing);
  });
}

class _LoadedPactListViewModel extends PactListViewModel {
  @override
  PactListState build() => PactListState(entries: [
        PactListEntry(
          pact: Pact(
            id: 'pact-1',
            habitName: 'Meditate',
            startDate: DateTime(2026, 3, 1),
            endDate: DateTime(2026, 9, 1),
            showupDuration: const Duration(minutes: 10),
            schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
            status: PactStatus.active,
          ),
        ),
      ]);
}
