import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/slices/debug/ui/android/remote_config_overrides_page_android.dart';

import '../../../../infrastructure/remote_config/fake_remote_config_override_store.dart';
import '../../../../infrastructure/remote_config/fake_remote_config_service.dart';

Widget _buildTestApp({
  FakeRemoteConfigOverrideStore? store,
  FakeRemoteConfigService? service,
  String? startupBackend,
}) {
  return ProviderScope(
    overrides: [
      if (store != null) remoteConfigOverrideStoreProvider.overrideWithValue(store),
      if (service != null) remoteConfigServiceProvider.overrideWithValue(service),
      if (startupBackend != null) debugBackendAtStartupProvider.overrideWithValue(startupBackend),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: RemoteConfigOverridesPageAndroid(),
    ),
  );
}

/// Pumps the test app with a tall viewport so all RC entries are rendered
/// without scrolling. Registers a teardown to reset the view afterwards.
Future<void> pumpWithTallView(
  WidgetTester tester, {
  FakeRemoteConfigOverrideStore? store,
  FakeRemoteConfigService? service,
  String? startupBackend,
}) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_buildTestApp(store: store, service: service, startupBackend: startupBackend));
}

void main() {
  testWidgets('Android — shows a row for every key in RemoteConfigDefaults.all', (tester) async {
    await pumpWithTallView(tester);

    for (final key in RemoteConfigDefaults.all.keys) {
      expect(find.byKey(Key('rc-entry-$key')), findsOneWidget);
    }
  });

  testWidgets('Android — non-overridden entries show DEFAULT badge', (tester) async {
    await pumpWithTallView(tester);

    expect(find.byKey(const Key('default-badge')), findsNWidgets(RemoteConfigDefaults.all.length));
    expect(find.byKey(const Key('override-badge')), findsNothing);
  });

  testWidgets('Android — overridden entry shows OVERRIDE badge', (tester) async {
    final store = FakeRemoteConfigOverrideStore();
    await store.setOverride('max_active_pacts', '10');
    await pumpWithTallView(tester, store: store);

    expect(find.byKey(const Key('override-badge')), findsOneWidget);
    expect(
      find.byKey(const Key('default-badge')),
      findsNWidgets(RemoteConfigDefaults.all.length - 1),
    );
  });

  testWidgets('Android — Reset all button hidden when no overrides', (tester) async {
    await pumpWithTallView(tester);
    await tester.pump();

    // No overrides → "Reset all" TextButton should not appear.
    expect(find.byKey(const Key('reset-all-button')), findsNothing);
  });

  testWidgets('Android — Reset all button visible when at least one override exists', (tester) async {
    final store = FakeRemoteConfigOverrideStore();
    await store.setOverride('max_active_pacts', '10');
    await pumpWithTallView(tester, store: store);
    await tester.pump();

    expect(find.byKey(const Key('reset-all-button')), findsOneWidget);
  });

  testWidgets('Android — free-text key opens edit dialog with text field', (tester) async {
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

  testWidgets('Android — constrained key opens edit dialog with radio picker', (tester) async {
    await pumpWithTallView(tester);
    await tester.pump();

    // post_deadline_notification_behavior has allowed values → radio picker.
    await tester.tap(find.byKey(const Key('rc-entry-post_deadline_notification_behavior')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('override-value-picker')), findsOneWidget);
    expect(find.byKey(const Key('override-value-field')), findsNothing);
    expect(find.byKey(const Key('override-option-dismiss')), findsOneWidget);
    expect(find.byKey(const Key('override-option-encourage')), findsOneWidget);
  });

  testWidgets('Android — edit dialog shows "Use default" only for overridden entry', (tester) async {
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

  testWidgets('Android — saving a value from the dialog updates the badge to OVERRIDE', (tester) async {
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

  testWidgets('Android — int-range key opens edit dialog with slider, not text field or picker', (tester) async {
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

  testWidgets('Android — saving slider value persists integer string to store', (tester) async {
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

  testWidgets('Android — no restart banner when debug_backend is not overridden', (tester) async {
    await pumpWithTallView(tester);

    expect(find.byKey(const Key('debug-backend-restart-banner')), findsNothing);
  });

  testWidgets('Android — shows restart banner when debug_backend is overridden', (tester) async {
    final store = FakeRemoteConfigOverrideStore();
    await store.setOverride('debug_backend', 'local');
    await pumpWithTallView(tester, store: store);

    expect(find.byKey(const Key('debug-backend-restart-banner')), findsOneWidget);
    expect(find.textContaining('restart'), findsOneWidget);
  });

  testWidgets('Android — no banner when app started with local and override is also local', (tester) async {
    // Bug 2: after restarting with debug_backend=local the override store still
    // holds 'local'. The banner must not show because the running backend already
    // matches the pending value.
    final store = FakeRemoteConfigOverrideStore();
    await store.setOverride('debug_backend', 'local');
    await pumpWithTallView(tester, store: store, startupBackend: 'local');

    expect(find.byKey(const Key('debug-backend-restart-banner')), findsNothing);
  });

  testWidgets('Android — no banner when override is set to real and app started with real', (tester) async {
    // Bug 3: setting debug_backend back to 'real' (the default) must not show
    // the banner because the running and pending values are both 'real'.
    final store = FakeRemoteConfigOverrideStore();
    await store.setOverride('debug_backend', RemoteConfigDefaults.debugBackend); // 'real'
    await pumpWithTallView(tester, store: store);

    expect(find.byKey(const Key('debug-backend-restart-banner')), findsNothing);
  });

  testWidgets('Android — debug_backend opens radio picker (allowedValues trumps intRange)', (tester) async {
    await pumpWithTallView(tester);
    await tester.pump();

    await tester.tap(find.byKey(const Key('rc-entry-debug_backend')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('override-value-picker')), findsOneWidget);
    expect(find.byKey(const Key('override-value-slider')), findsNothing);
    expect(find.byKey(const Key('override-value-field')), findsNothing);
    expect(find.byKey(const Key('override-option-real')), findsOneWidget);
    expect(find.byKey(const Key('override-option-local')), findsOneWidget);
  });
}
