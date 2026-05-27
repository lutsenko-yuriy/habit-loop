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

void main() {
  testWidgets('iOS — shows a row for every key in RemoteConfigDefaults.all', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    for (final key in RemoteConfigDefaults.all.keys) {
      expect(find.byKey(Key('rc-entry-$key')), findsOneWidget);
    }
  });

  testWidgets('iOS — non-overridden entries show DEFAULT badge', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    expect(find.byKey(const Key('default-badge')), findsNWidgets(RemoteConfigDefaults.all.length));
    expect(find.byKey(const Key('override-badge')), findsNothing);
  });

  testWidgets('iOS — overridden entry shows OVERRIDE badge', (tester) async {
    final store = FakeRemoteConfigOverrideStore();
    await store.setOverride('max_active_pacts', '10');
    await tester.pumpWidget(_buildTestApp(store: store));

    expect(find.byKey(const Key('override-badge')), findsOneWidget);
    expect(
      find.byKey(const Key('default-badge')),
      findsNWidgets(RemoteConfigDefaults.all.length - 1),
    );
  });

  testWidgets('iOS — Reset all button hidden when no overrides', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    final resetButton = tester.widget<CupertinoButton>(find.byKey(const Key('reset-all-button')));
    expect(resetButton.onPressed, isNull);
  });

  testWidgets('iOS — Reset all button active when at least one override exists', (tester) async {
    final store = FakeRemoteConfigOverrideStore();
    await store.setOverride('max_active_pacts', '10');
    await tester.pumpWidget(_buildTestApp(store: store));
    await tester.pump();

    final resetButton = tester.widget<CupertinoButton>(find.byKey(const Key('reset-all-button')));
    expect(resetButton.onPressed, isNotNull);
  });

  testWidgets('iOS — free-text key opens edit dialog with text field', (tester) async {
    await tester.pumpWidget(_buildTestApp());
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
    await tester.pumpWidget(_buildTestApp());
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

  testWidgets('iOS — saving a free-text value updates the badge to OVERRIDE', (tester) async {
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
