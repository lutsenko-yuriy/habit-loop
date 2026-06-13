import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/debug/ui/generic/debug_seed_data_view_model.dart';
import 'package:habit_loop/slices/debug/ui/generic/remote_config_overrides_scroll_view.dart';
import 'package:habit_loop/slices/debug/ui/generic/remote_config_overrides_view_model.dart';

RemoteConfigEntry _entry(String key, {bool isFeatureToggle = false}) => RemoteConfigEntry(
      key: key,
      defaultValue: '5',
      overrideValue: null,
      effectiveValue: '5',
      isFeatureToggle: isFeatureToggle,
    );

RemoteConfigOverridesSlots _stubSlots({Widget Function(BuildContext)? buildTopSection}) => (
      buildTopSection: buildTopSection,
      buildEntryTile: (ctx, entry, onTap) => TextButton(
            key: Key('rc-entry-${entry.key}'),
            onPressed: onTap,
            child: Text(entry.key),
          ),
      buildEntrySeparator: (ctx) => const SizedBox(key: Key('entry-sep'), height: 4),
      buildSectionDivider: (ctx) => const Divider(key: Key('section-div')),
      buildSectionHeader: (ctx, title) => Text(title, key: Key('section-header-$title')),
      buildRestartBanner: (ctx) => const Text('restart required', key: Key('debug-backend-restart-banner')),
      seedSlots: (
        buildHeader: (ctx) => const Text('SEED DATA'),
        buildButton: (ctx, key, label, isBusy, onPressed) => TextButton(
              key: key,
              onPressed: isBusy ? null : onPressed,
              child: Text(label),
            ),
        buildButtonContainer: (ctx, buttons) => Column(mainAxisSize: MainAxisSize.min, children: buttons),
        buildStatusText: (ctx, key, message, status) => Text(message, key: key),
      ),
      wrapSeedSection: (ctx, child) => child,
      listPadding: EdgeInsets.zero,
    );

Widget _wrap({
  List<RemoteConfigEntry>? entries,
  bool showRestartBanner = false,
  DebugSeedDataState seedState = const DebugSeedDataState(),
  bool hasFakeBackend = false,
  Widget Function(BuildContext)? buildTopSection,
}) =>
    MaterialApp(
      home: Scaffold(
        body: RemoteConfigOverridesScrollView(
          entries: entries ?? [_entry('alpha')],
          showBackendRestartBanner: showRestartBanner,
          seedState: seedState,
          hasFakeBackend: hasFakeBackend,
          onSeedLocal: () {},
          onSeedRemote: () {},
          onEntryTap: (_) {},
          slots: _stubSlots(buildTopSection: buildTopSection),
        ),
      ),
    );

void main() {
  testWidgets('renders a tile for each entry', (tester) async {
    await tester.pumpWidget(_wrap(entries: [_entry('a'), _entry('b')]));
    expect(find.byKey(const Key('rc-entry-a')), findsOneWidget);
    expect(find.byKey(const Key('rc-entry-b')), findsOneWidget);
  });

  testWidgets('does not show restart banner when showBackendRestartBanner is false', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byKey(const Key('debug-backend-restart-banner')), findsNothing);
  });

  testWidgets('shows restart banner when showBackendRestartBanner is true', (tester) async {
    await tester.pumpWidget(_wrap(showRestartBanner: true));
    expect(find.byKey(const Key('debug-backend-restart-banner')), findsOneWidget);
  });

  testWidgets('shows seed-local-button', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byKey(const Key('seed-local-button')), findsOneWidget);
  });

  testWidgets('shows seed-remote-button when hasFakeBackend', (tester) async {
    await tester.pumpWidget(_wrap(hasFakeBackend: true));
    expect(find.byKey(const Key('seed-remote-button')), findsOneWidget);
  });

  testWidgets('does not show seed-remote-button without fake backend', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byKey(const Key('seed-remote-button')), findsNothing);
  });

  testWidgets('does not show top section when buildTopSection returns null', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byKey(const Key('top-section')), findsNothing);
  });

  testWidgets('shows top section when buildTopSection returns a widget', (tester) async {
    await tester.pumpWidget(_wrap(
      buildTopSection: (ctx) => const Text('top', key: Key('top-section')),
    ));
    expect(find.byKey(const Key('top-section')), findsOneWidget);
  });

  testWidgets('seed section appears before entry tiles', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(entries: [_entry('z')]));

    final seedOffset = tester.getTopLeft(find.byKey(const Key('seed-local-button'))).dy;
    final entryOffset = tester.getTopLeft(find.byKey(const Key('rc-entry-z'))).dy;
    expect(seedOffset, lessThan(entryOffset));
  });

  testWidgets('renders section headers for feature toggle and experiment entries', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(entries: [
      _entry('toggle_key', isFeatureToggle: true),
      _entry('exp_key', isFeatureToggle: false),
    ]));

    expect(find.byKey(const Key('section-header-FEATURE TOGGLES')), findsOneWidget);
    expect(find.byKey(const Key('section-header-A/B TESTS')), findsOneWidget);
  });

  testWidgets('invokes onEntryTap when entry tile is tapped', (tester) async {
    RemoteConfigEntry? tapped;
    final entry = _entry('tap_me');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RemoteConfigOverridesScrollView(
          entries: [entry],
          showBackendRestartBanner: false,
          seedState: const DebugSeedDataState(),
          hasFakeBackend: false,
          onSeedLocal: () {},
          onSeedRemote: () {},
          onEntryTap: (e) => tapped = e,
          slots: _stubSlots(),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('rc-entry-tap_me')));
    expect(tapped?.key, 'tap_me');
  });
}
