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
      buildCountStepper: (ctx, key, count, canDecrement, canIncrement, onDecrement, onIncrement) => Row(
            key: key,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                key: const Key('seed-count-decrement'),
                onPressed: canDecrement ? onDecrement : null,
                child: const Text('-'),
              ),
              Text('$count', key: const Key('seed-count-value')),
              TextButton(
                key: const Key('seed-count-increment'),
                onPressed: canIncrement ? onIncrement : null,
                child: const Text('+'),
              ),
            ],
          ),
    );

Widget _wrap({
  DebugSeedDataState state = const DebugSeedDataState(),
  bool hasFakeBackend = false,
  int pactCount = 5,
  VoidCallback? onSeedLocal,
  VoidCallback? onSeedRemote,
  ValueChanged<int>? onPactCountChanged,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SeedSection(
          state: state,
          hasFakeBackend: hasFakeBackend,
          pactCount: pactCount,
          onSeedLocal: onSeedLocal ?? () {},
          onSeedRemote: onSeedRemote ?? () {},
          onPactCountChanged: onPactCountChanged ?? (_) {},
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

  testWidgets('renders seed-count-stepper with the given count', (tester) async {
    await tester.pumpWidget(_wrap(pactCount: 7));
    expect(find.byKey(const Key('seed-count-stepper')), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('decrement is disabled at count 1', (tester) async {
    await tester.pumpWidget(_wrap(pactCount: 1));
    final decrement = tester.widget<TextButton>(find.byKey(const Key('seed-count-decrement')));
    expect(decrement.onPressed, isNull);
  });

  testWidgets('increment is disabled at count 10', (tester) async {
    await tester.pumpWidget(_wrap(pactCount: 10));
    final increment = tester.widget<TextButton>(find.byKey(const Key('seed-count-increment')));
    expect(increment.onPressed, isNull);
  });

  testWidgets('tapping decrement calls onPactCountChanged with count - 1', (tester) async {
    int? received;
    await tester.pumpWidget(_wrap(pactCount: 5, onPactCountChanged: (v) => received = v));
    await tester.tap(find.byKey(const Key('seed-count-decrement')));
    expect(received, 4);
  });

  testWidgets('tapping increment calls onPactCountChanged with count + 1', (tester) async {
    int? received;
    await tester.pumpWidget(_wrap(pactCount: 5, onPactCountChanged: (v) => received = v));
    await tester.tap(find.byKey(const Key('seed-count-increment')));
    expect(received, 6);
  });
}
