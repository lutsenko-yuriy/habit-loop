import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/debug/ui/generic/debug_seed_data_view_model.dart';
import 'package:habit_loop/slices/debug/ui/generic/seed_section.dart';

SeedSectionSlots _stubSlots() => (
      buildHeader: (ctx) => const Text('SEED DATA', key: Key('seed-header')),
      buildButton: (ctx, key, label, isBusy, onPressed) => TextButton(
            key: key,
            onPressed: isBusy ? null : onPressed,
            child: Text(label),
          ),
      buildButtonContainer: (ctx, buttons) => Column(mainAxisSize: MainAxisSize.min, children: buttons),
      buildStatusText: (ctx, key, message, status) => Text(message, key: key),
    );

Widget _wrap({
  DebugSeedDataState state = const DebugSeedDataState(),
  bool hasFakeBackend = false,
  VoidCallback? onSeedLocal,
  VoidCallback? onSeedRemote,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SeedSection(
          state: state,
          hasFakeBackend: hasFakeBackend,
          onSeedLocal: onSeedLocal ?? () {},
          onSeedRemote: onSeedRemote ?? () {},
          slots: _stubSlots(),
        ),
      ),
    );

void main() {
  testWidgets('renders seed-local-button', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byKey(const Key('seed-local-button')), findsOneWidget);
  });

  testWidgets('does not render seed-remote-button without fake backend', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byKey(const Key('seed-remote-button')), findsNothing);
  });

  testWidgets('renders seed-remote-button when hasFakeBackend is true', (tester) async {
    await tester.pumpWidget(_wrap(hasFakeBackend: true));
    expect(find.byKey(const Key('seed-local-button')), findsOneWidget);
    expect(find.byKey(const Key('seed-remote-button')), findsOneWidget);
  });

  testWidgets('buttons are disabled when state is busy', (tester) async {
    await tester.pumpWidget(_wrap(
      state: const DebugSeedDataState(status: DebugSeedState.busy),
      hasFakeBackend: true,
    ));
    final local = tester.widget<TextButton>(find.byKey(const Key('seed-local-button')));
    final remote = tester.widget<TextButton>(find.byKey(const Key('seed-remote-button')));
    expect(local.onPressed, isNull);
    expect(remote.onPressed, isNull);
  });

  testWidgets('buttons are enabled when state is idle', (tester) async {
    await tester.pumpWidget(_wrap(hasFakeBackend: true));
    final local = tester.widget<TextButton>(find.byKey(const Key('seed-local-button')));
    final remote = tester.widget<TextButton>(find.byKey(const Key('seed-remote-button')));
    expect(local.onPressed, isNotNull);
    expect(remote.onPressed, isNotNull);
  });

  testWidgets('does not show seed-status-text when idle', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byKey(const Key('seed-status-text')), findsNothing);
  });

  testWidgets('shows seed-status-text with message when not idle', (tester) async {
    await tester.pumpWidget(_wrap(
      state: const DebugSeedDataState(status: DebugSeedState.done, message: 'All done!'),
    ));
    expect(find.byKey(const Key('seed-status-text')), findsOneWidget);
    expect(find.text('All done!'), findsOneWidget);
  });

  testWidgets('invokes onSeedLocal when local button is tapped', (tester) async {
    var called = false;
    await tester.pumpWidget(_wrap(onSeedLocal: () => called = true));
    await tester.tap(find.byKey(const Key('seed-local-button')));
    expect(called, isTrue);
  });

  testWidgets('invokes onSeedRemote when remote button is tapped', (tester) async {
    var called = false;
    await tester.pumpWidget(_wrap(hasFakeBackend: true, onSeedRemote: () => called = true));
    await tester.tap(find.byKey(const Key('seed-remote-button')));
    expect(called, isTrue);
  });
}
