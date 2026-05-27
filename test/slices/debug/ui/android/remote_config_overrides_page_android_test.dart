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
      home: RemoteConfigOverridesPageAndroid(),
    ),
  );
}

void main() {
  testWidgets('Android — shows a row for every key in RemoteConfigDefaults.all', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    for (final key in RemoteConfigDefaults.all.keys) {
      expect(find.byKey(Key('rc-entry-$key')), findsOneWidget);
    }
  });

  testWidgets('Android — non-overridden entries show DEFAULT badge', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    expect(find.byKey(const Key('default-badge')), findsNWidgets(RemoteConfigDefaults.all.length));
    expect(find.byKey(const Key('override-badge')), findsNothing);
  });

  testWidgets('Android — overridden entry shows OVERRIDE badge', (tester) async {
    final store = FakeRemoteConfigOverrideStore();
    await store.setOverride('max_active_pacts', '10');
    await tester.pumpWidget(_buildTestApp(store: store));

    expect(find.byKey(const Key('override-badge')), findsOneWidget);
    expect(
      find.byKey(const Key('default-badge')),
      findsNWidgets(RemoteConfigDefaults.all.length - 1),
    );
  });

  testWidgets('Android — Reset all button hidden when no overrides', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    // No overrides → "Reset all" TextButton should not appear.
    expect(find.byKey(const Key('reset-all-button')), findsNothing);
  });

  testWidgets('Android — Reset all button visible when at least one override exists', (tester) async {
    final store = FakeRemoteConfigOverrideStore();
    await store.setOverride('max_active_pacts', '10');
    await tester.pumpWidget(_buildTestApp(store: store));
    await tester.pump();

    expect(find.byKey(const Key('reset-all-button')), findsOneWidget);
  });

  testWidgets('Android — tapping a row opens the edit dialog with the key name', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    final firstKey = RemoteConfigDefaults.all.keys.first;
    await tester.tap(find.byKey(Key('rc-entry-$firstKey')));
    await tester.pumpAndSettle();

    expect(find.text(firstKey), findsWidgets);
    expect(find.byKey(const Key('override-value-field')), findsOneWidget);
    expect(find.byKey(const Key('save-action')), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('Android — edit dialog shows "Use default" only for overridden entry', (tester) async {
    final store = FakeRemoteConfigOverrideStore();
    await store.setOverride('max_active_pacts', '10');
    await tester.pumpWidget(_buildTestApp(store: store));
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
    await tester.pumpWidget(_buildTestApp(store: store));
    await tester.pump();

    await tester.tap(find.byKey(const Key('rc-entry-max_active_pacts')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('override-value-field')), '99');
    await tester.tap(find.byKey(const Key('save-action')));
    await tester.pumpAndSettle();

    expect(store.getOverride('max_active_pacts'), '99');
    expect(find.byKey(const Key('override-badge')), findsOneWidget);
  });
}
