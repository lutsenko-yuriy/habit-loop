import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_screen.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/features/showup/ui/generic/showup_detail_view_model.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/remote_config/providers/remote_config_providers.dart';

import '../../../remote_config/fake_remote_config_service.dart';

final _today = DateTime(2026, 3, 29);

/// Builds pacts with a daily schedule for use in Remote Config threshold tests.
Pact _buildPact(String id) => Pact(
      id: id,
      habitName: 'Habit $id',
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 9, 1),
      showupDuration: const Duration(minutes: 10),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
      status: PactStatus.active,
    );

Widget _buildApp({
  required List<Pact> pacts,
  required FakeRemoteConfigService remoteConfig,
}) {
  final pactRepo = InMemoryPactRepository(pacts);
  final showupRepo = InMemoryShowupRepository([]);
  return ProviderScope(
    overrides: [
      pactRepositoryProvider.overrideWithValue(pactRepo),
      showupRepositoryProvider.overrideWithValue(showupRepo),
      todayProvider.overrideWithValue(_today),
      showupDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
      showupDetailPactRepositoryProvider.overrideWithValue(pactRepo),
      remoteConfigServiceProvider.overrideWithValue(remoteConfig),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: DashboardScreen(),
    ),
  );
}

void main() {
  group('DashboardScreen — Remote Config max_active_pacts threshold', () {
    testWidgets('does not show warning dialog when active pact count is below Remote Config threshold', (tester) async {
      // Remote Config says 5 is the max; only 4 pacts exist — no warning.
      final remoteConfig = FakeRemoteConfigService(
        overrides: {'max_active_pacts': 5},
      );
      final pacts = List.generate(4, (i) => _buildPact('$i'));

      await tester.pumpWidget(_buildApp(pacts: pacts, remoteConfig: remoteConfig));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('create-pact-button')));
      await tester.pumpAndSettle();

      expect(find.text('Too many active pacts'), findsNothing);
    });

    testWidgets('shows warning dialog when active pact count meets Remote Config threshold', (tester) async {
      // Remote Config says 3 is the max; exactly 3 pacts exist — warning shown.
      final remoteConfig = FakeRemoteConfigService(
        overrides: {'max_active_pacts': 3},
      );
      final pacts = List.generate(3, (i) => _buildPact('$i'));

      await tester.pumpWidget(_buildApp(pacts: pacts, remoteConfig: remoteConfig));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('create-pact-button')));
      await tester.pumpAndSettle();

      expect(find.text('Too many active pacts'), findsOneWidget);
    });

    testWidgets('does not show warning dialog when pact count is below the raised threshold', (tester) async {
      // Remote Config raises the limit to 5; 3 pacts exist — no warning
      // (whereas the hardcoded value of 3 would have triggered one).
      final remoteConfig = FakeRemoteConfigService(
        overrides: {'max_active_pacts': 5},
      );
      final pacts = List.generate(3, (i) => _buildPact('$i'));

      await tester.pumpWidget(_buildApp(pacts: pacts, remoteConfig: remoteConfig));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('create-pact-button')));
      await tester.pumpAndSettle();

      // With threshold = 5, 3 pacts should NOT trigger the dialog.
      expect(find.text('Too many active pacts'), findsNothing);
    });
  });
}
