import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/checklist/analytics/checklist_analytics_events.dart';
import 'package:habit_loop/slices/checklist/data/in_memory_pact_checklist_link_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_checklist_section_host.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/checklister/fake_checklister_gateway.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';

final _pact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 3, 1),
  endDate: DateTime(2026, 9, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
);

const _selectKey = Key('pact-checklist-select-button');
const _emptyKey = Key('pact-checklist-empty');

final _link = PactChecklistLink(
  pactId: 'p1',
  checklistId: 'c1',
  checklistName: 'Morning routine',
  linkedAt: DateTime(2026, 5, 1),
);

void main() {
  late InMemoryPactChecklistLinkRepository links;
  late FakeChecklisterGateway gateway;
  late FakeAnalyticsService analytics;

  Future<void> pump(WidgetTester tester, {bool flagOn = true, bool installed = true}) async {
    gateway.installed = installed;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pactRepositoryProvider.overrideWithValue(InMemoryPactRepository([_pact])),
          showupRepositoryProvider.overrideWithValue(InMemoryShowupRepository()),
          pactChecklistLinkRepositoryProvider.overrideWithValue(links),
          checklisterGatewayProvider.overrideWithValue(gateway),
          analyticsServiceProvider.overrideWithValue(analytics),
          remoteConfigServiceProvider.overrideWithValue(
            FakeRemoteConfigService.withTestDefaults(overrides: {'checklister_integration_enabled': flagOn}),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PactChecklistSectionHost(pactId: 'p1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    links = InMemoryPactChecklistLinkRepository();
    gateway = FakeChecklisterGateway();
    analytics = FakeAnalyticsService();
  });

  testWidgets('kill-switch off: renders nothing', (tester) async {
    await pump(tester, flagOn: false);
    expect(find.byKey(_selectKey), findsNothing);
  });

  testWidgets('Checklister not installed: renders nothing', (tester) async {
    await pump(tester, installed: false);
    expect(find.byKey(_selectKey), findsNothing);
  });

  testWidgets('flag on + installed + no link: shows the empty state with "Select checklist"', (tester) async {
    await pump(tester);
    expect(find.byKey(_emptyKey), findsOneWidget);
    expect(find.byKey(_selectKey), findsOneWidget);
  });

  testWidgets(
    'linked name sits left of Change/Remove on one row',
    variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
    (tester) async {
      await links.upsert(_link);
      await pump(tester);

      final name = tester.getCenter(find.text('Morning routine'));
      final change = tester.getCenter(find.byKey(const Key('pact-checklist-change-button')));
      final remove = tester.getCenter(find.byKey(const Key('pact-checklist-remove-button')));
      expect(name.dx, lessThan(change.dx));
      expect(change.dx, lessThan(remove.dx));
      expect((name.dy - remove.dy).abs(), lessThan(2));
    },
  );

  testWidgets('Remove crossfades the linked tile into the empty state', (tester) async {
    await links.upsert(_link);
    await pump(tester);

    await tester.tap(find.byKey(const Key('pact-checklist-remove-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Morning routine'), findsOneWidget, reason: 'outgoing tile still fading');
    expect(find.byKey(_emptyKey), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Morning routine'), findsNothing);
  });

  testWidgets('tapping "Select checklist" opens Checklister and logs selection_started', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(_selectKey));
    await tester.pumpAndSettle();

    expect(gateway.launchedUrls, hasLength(1));
    expect(gateway.launchedUrls.single.scheme, 'checklister');
    expect(analytics.loggedEvents.single, isA<PactChecklistSelectionStartedEvent>());
  });

  testWidgets('existing link: shows its name; Remove clears it and logs unlinked', (tester) async {
    await links.upsert(_link);
    await pump(tester);
    expect(find.text('Morning routine'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pact-checklist-remove-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(_selectKey), findsOneWidget);
    expect(await links.getForPact('p1'), isNull);
    expect(analytics.loggedEvents.whereType<PactChecklistUnlinkedEvent>(), hasLength(1));
  });
}
