import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/slices/debug/ui/ios/remote_config_overrides_page_ios.dart';

import '../../../../infrastructure/remote_config/fake_remote_config_override_store.dart';
import '../../../../infrastructure/remote_config/fake_remote_config_service.dart';

Widget _buildTestApp({
  FakeRemoteConfigOverrideStore? store,
  FakeRemoteConfigService? service,
}) {
  return ProviderScope(
    overrides: [
      if (store != null) remoteConfigOverrideStoreProvider.overrideWithValue(store),
      if (service != null) remoteConfigServiceProvider.overrideWithValue(service),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: RemoteConfigOverridesPageIos(),
    ),
  );
}

/// Pumps the test app with a tall viewport so all RC entries are rendered
/// without scrolling. Registers a teardown to reset the view afterwards.
Future<void> pumpWithTallView(
  WidgetTester tester, {
  FakeRemoteConfigOverrideStore? store,
  FakeRemoteConfigService? service,
}) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_buildTestApp(store: store, service: service));
}

void main() {
  testWidgets('iOS — shows a row for every key in RemoteConfigDefaults.all', (tester) async {
    await pumpWithTallView(tester);

    for (final key in RemoteConfigDefaults.all.keys) {
      expect(find.byKey(Key('rc-entry-$key')), findsOneWidget);
    }
  });

  testWidgets('iOS — non-overridden entries show DEFAULT badge', (tester) async {
    await pumpWithTallView(tester);

    expect(find.byKey(const Key('default-badge')), findsNWidgets(RemoteConfigDefaults.all.length));
    expect(find.byKey(const Key('override-badge')), findsNothing);
  });

  testWidgets('iOS — overridden entry shows OVERRIDE badge', (tester) async {
    final store = FakeRemoteConfigOverrideStore();
    await store.setOverride('max_active_pacts', '10');
    await pumpWithTallView(tester, store: store);

    expect(find.byKey(const Key('override-badge')), findsOneWidget);
    expect(
      find.byKey(const Key('default-badge')),
      findsNWidgets(RemoteConfigDefaults.all.length - 1),
    );
  });

  testWidgets('iOS — Reset all button hidden when no overrides', (tester) async {
    await pumpWithTallView(tester);
    await tester.pump();

    final resetButton = tester.widget<CupertinoButton>(find.byKey(const Key('reset-all-button')));
    expect(resetButton.onPressed, isNull);
  });

  testWidgets('iOS — Reset all button active when at least one override exists', (tester) async {
    final store = FakeRemoteConfigOverrideStore();
    await store.setOverride('max_active_pacts', '10');
    await pumpWithTallView(tester, store: store);
    await tester.pump();

    final resetButton = tester.widget<CupertinoButton>(find.byKey(const Key('reset-all-button')));
    expect(resetButton.onPressed, isNotNull);
  });

  testWidgets('iOS — free-text key opens edit dialog with text field', (tester) async {
    await pumpWithTallView(tester);
    await tester.pump();

    // max_active_pacts has no allowed values → text field.
    await tester.tap(find.byKey(const Key('rc-entry-max_active_pacts')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('override-value-field')), findsOneWidget);
    expect(find.byKey(const Key('override-value-picker')), findsNothing);
    expect(find.byKey(const Key('save-action')), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('iOS — constrained key opens edit dialog with segmented picker', (tester) async {
    await pumpWithTallView(tester);
    await tester.pump();

    // post_deadline_notification_behavior has allowed values → picker.
    await tester.tap(find.byKey(const Key('rc-entry-post_deadline_notification_behavior')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('override-value-picker')), findsOneWidget);
    expect(find.byKey(const Key('override-value-field')), findsNothing);
    expect(find.text('dismiss'), findsWidgets);
    expect(find.text('encourage'), findsWidgets);
  });

  testWidgets('iOS — edit dialog shows "Use default" only for overridden entry', (tester) async {
    final store = FakeRemoteConfigOverrideStore();
    await store.setOverride('max_active_pacts', '10');
    await pumpWithTallView(tester, store: store);
    await tester.pump();

    await tester.tap(find.byKey(const Key('rc-entry-max_active_pacts')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('use-default-action')), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('rc-entry-${RemoteConfigDefaults.all.keys.last}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('use-default-action')), findsNothing);
  });

  testWidgets('iOS — saving a free-text value updates the badge to OVERRIDE', (tester) async {
    final store = FakeRemoteConfigOverrideStore();
    await pumpWithTallView(tester, store: store);
    await tester.pump();

    await tester.tap(find.byKey(const Key('rc-entry-max_active_pacts')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('override-value-field')), '99');
    await tester.tap(find.byKey(const Key('save-action')));
    await tester.pumpAndSettle();

    expect(store.getOverride('max_active_pacts'), '99');
    expect(find.byKey(const Key('override-badge')), findsOneWidget);
  });

  testWidgets('iOS — int-range key opens edit dialog with slider, not text field or picker', (tester) async {
    await pumpWithTallView(tester);
    await tester.pump();

    // debug_connectivity_stability_percent has intRange (0–100) → slider.
    await tester.tap(find.byKey(const Key('rc-entry-debug_connectivity_stability_percent')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('override-value-slider')), findsOneWidget);
    expect(find.byKey(const Key('override-value-field')), findsNothing);
    expect(find.byKey(const Key('override-value-picker')), findsNothing);
    expect(find.byKey(const Key('save-action')), findsOneWidget);
  });

  testWidgets('iOS — saving slider value persists integer string to store', (tester) async {
    final store = FakeRemoteConfigOverrideStore();
    await pumpWithTallView(tester, store: store);
    await tester.pump();

    await tester.tap(find.byKey(const Key('rc-entry-debug_connectivity_stability_percent')));
    await tester.pumpAndSettle();

    // Verify slider is shown, then save current default value.
    expect(find.byKey(const Key('override-value-slider')), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-action')));
    await tester.pumpAndSettle();

    // The saved value must be parseable as an integer.
    final saved = store.getOverride('debug_connectivity_stability_percent');
    expect(saved, isNotNull);
    expect(int.tryParse(saved!), isNotNull);
    expect(find.byKey(const Key('override-badge')), findsAtLeastNWidgets(1));
  });

  testWidgets('iOS — no restart banner when debug_backend is not overridden', (tester) async {
    await pumpWithTallView(tester);

    expect(find.byKey(const Key('debug-backend-restart-banner')), findsNothing);
  });

  testWidgets('iOS — shows restart banner when debug_backend is overridden', (tester) async {
    final store = FakeRemoteConfigOverrideStore();
    await store.setOverride('debug_backend', 'local');
    await pumpWithTallView(tester, store: store);

    expect(find.byKey(const Key('debug-backend-restart-banner')), findsOneWidget);
    expect(find.textContaining('restart'), findsOneWidget);
  });

  testWidgets('iOS — debug_backend opens picker (allowedValues trumps intRange)', (tester) async {
    await pumpWithTallView(tester);
    await tester.pump();

    await tester.tap(find.byKey(const Key('rc-entry-debug_backend')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('override-value-picker')), findsOneWidget);
    expect(find.byKey(const Key('override-value-slider')), findsNothing);
    expect(find.byKey(const Key('override-value-field')), findsNothing);
    expect(find.text('real'), findsWidgets);
    expect(find.text('local'), findsWidgets);
  });
}
