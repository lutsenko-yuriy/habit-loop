import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_content_transition.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_screen.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';

final _predecessorPact = Pact(
  id: 'p1',
  habitName: 'Root Habit',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 2, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.stopped,
);

final _currentPact = Pact(
  id: 'p2',
  habitName: 'Current Habit',
  startDate: DateTime(2099, 2, 2),
  endDate: DateTime(2099, 3, 2),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.stopped,
  predecessorPactId: 'p1',
);

final _successorPact = Pact(
  id: 'p3',
  habitName: 'Next Habit',
  startDate: DateTime(2099, 3, 3),
  endDate: DateTime(2099, 4, 3),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.stopped,
  predecessorPactId: 'p2',
);

Widget _buildApp({
  required List<Pact> pacts,
  required FakeAnalyticsService analytics,
  required Widget child,
}) {
  final pactRepo = InMemoryPactRepository(pacts);
  final showupRepo = InMemoryShowupRepository(const []);
  final txService = InMemoryPactTransactionService(pactRepo, showupRepo);

  return ProviderScope(
    overrides: [
      pactRepositoryProvider.overrideWithValue(pactRepo),
      showupRepositoryProvider.overrideWithValue(showupRepo),
      pactTransactionServiceProvider.overrideWithValue(txService),
      analyticsServiceProvider.overrideWithValue(analytics),
      remoteConfigServiceProvider.overrideWithValue(
        FakeRemoteConfigService(overrides: const {'pact_chaining_enabled': true}),
      ),
    ],
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

Future<void> _pumpLoadedScreen(WidgetTester tester, {required FakeAnalyticsService analytics}) async {
  await tester.pumpWidget(
    _buildApp(
      pacts: [_predecessorPact, _currentPact, _successorPact],
      analytics: analytics,
      child: const PactDetailScreen(pactId: 'p2'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PactDetailScreen chain navigation transition (HAB-206 WU3)', () {
    testWidgets('animates predecessor navigation from left while outgoing content slides right', (tester) async {
      final analytics = FakeAnalyticsService();
      await _pumpLoadedScreen(tester, analytics: analytics);

      expect(find.text('Current Habit'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pact-detail-previous-pact-link')));
      await tester.pump();
      await tester.pump(PactDetailContentTransition.duration ~/ 2);

      final transition = tester.widget<PactDetailContentTransition>(
        find.byKey(const Key('pact-detail-heading-transition')),
      );
      expect(transition.direction, PactDetailTransitionDirection.toPredecessor);

      await tester.pump(PactDetailContentTransition.duration);
      await tester.pumpAndSettle();

      expect(find.text('Root Habit'), findsOneWidget);
      expect(find.text('Current Habit'), findsNothing);
    });

    testWidgets('animates successor navigation from right while outgoing content slides left', (tester) async {
      final analytics = FakeAnalyticsService();
      await _pumpLoadedScreen(tester, analytics: analytics);

      await tester.tap(find.byKey(const Key('pact-detail-next-pact-link')));
      await tester.pump();
      await tester.pump(PactDetailContentTransition.duration ~/ 2);

      final transition = tester.widget<PactDetailContentTransition>(
        find.byKey(const Key('pact-detail-heading-transition')),
      );
      expect(transition.direction, PactDetailTransitionDirection.toSuccessor);

      await tester.pump(PactDetailContentTransition.duration);
      await tester.pumpAndSettle();

      expect(find.text('Next Habit'), findsOneWidget);
      expect(find.text('Current Habit'), findsNothing);
    });

    testWidgets('ignores a second chain-link tap while the first transition is in flight', (tester) async {
      final analytics = FakeAnalyticsService();
      await _pumpLoadedScreen(tester, analytics: analytics);

      final nextLink = find.byKey(const Key('pact-detail-next-pact-link'));
      await tester.tap(nextLink);
      await tester.tap(nextLink);
      await tester.pump();
      await tester.pump(PactDetailContentTransition.duration);

      expect(find.text('Next Habit'), findsOneWidget);
      expect(
        analytics.loggedEvents.where((event) => event.runtimeType.toString() == 'PactChainLinkTappedEvent'),
        hasLength(1),
      );
    });
  });
}
