import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/pact/ui/generic/wizard_step_indicator.dart';
import 'package:habit_loop/slices/pact/ui/generic/wizard_style.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

const _keyPrefix = 'test-step-indicator';
const _stepCount = 4;

Widget _wrap({required int currentIndex, ValueChanged<int>? onStepTapped}) {
  return MaterialApp(
    theme: HabitLoopTheme.materialTheme,
    home: Scaffold(
      body: Builder(builder: (context) {
        return WizardStepIndicator(
          style: WizardStyle.material(context),
          currentIndex: currentIndex,
          stepCount: _stepCount,
          onStepTapped: onStepTapped ?? (_) {},
          keyPrefix: _keyPrefix,
        );
      }),
    ),
  );
}

void main() {
  testWidgets('renders stepCount segments', (tester) async {
    await tester.pumpWidget(_wrap(currentIndex: 0));
    for (var i = 0; i < _stepCount; i++) {
      expect(find.byKey(Key('$_keyPrefix-segment-$i')), findsOneWidget);
    }
  });

  testWidgets('outer Padding has the keyPrefix key', (tester) async {
    await tester.pumpWidget(_wrap(currentIndex: 0));
    expect(find.byKey(const Key(_keyPrefix)), findsOneWidget);
  });

  testWidgets('tapping segment calls onStepTapped with correct index', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(_wrap(currentIndex: 0, onStepTapped: tapped.add));
    await tester.tap(find.byKey(const Key('$_keyPrefix-segment-2')));
    await tester.pump();
    expect(tapped, [2]);
  });

  testWidgets('current segment uses activeStepColor', (tester) async {
    late WizardStyle style;
    await tester.pumpWidget(MaterialApp(
      theme: HabitLoopTheme.materialTheme,
      home: Scaffold(
        body: Builder(builder: (context) {
          style = WizardStyle.material(context);
          return WizardStepIndicator(
            style: style,
            currentIndex: 2,
            stepCount: _stepCount,
            onStepTapped: (_) {},
            keyPrefix: _keyPrefix,
          );
        }),
      ),
    ));
    final container = tester.widget<Container>(find.byKey(const Key('$_keyPrefix-segment-2')));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, style.activeStepColor);
  });

  testWidgets('past segment uses pastStepColor', (tester) async {
    late WizardStyle style;
    await tester.pumpWidget(MaterialApp(
      theme: HabitLoopTheme.materialTheme,
      home: Scaffold(
        body: Builder(builder: (context) {
          style = WizardStyle.material(context);
          return WizardStepIndicator(
            style: style,
            currentIndex: 2,
            stepCount: _stepCount,
            onStepTapped: (_) {},
            keyPrefix: _keyPrefix,
          );
        }),
      ),
    ));
    final container = tester.widget<Container>(find.byKey(const Key('$_keyPrefix-segment-1')));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, style.pastStepColor);
  });

  testWidgets('future segment uses inactiveStepColor', (tester) async {
    late WizardStyle style;
    await tester.pumpWidget(MaterialApp(
      theme: HabitLoopTheme.materialTheme,
      home: Scaffold(
        body: Builder(builder: (context) {
          style = WizardStyle.material(context);
          return WizardStepIndicator(
            style: style,
            currentIndex: 1,
            stepCount: _stepCount,
            onStepTapped: (_) {},
            keyPrefix: _keyPrefix,
          );
        }),
      ),
    ));
    final container = tester.widget<Container>(find.byKey(const Key('$_keyPrefix-segment-3')));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, style.inactiveStepColor);
  });
}
