import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/debug/ui/generic/override_badge.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: HabitLoopTheme.materialTheme,
        home: Scaffold(body: child),
      );

  testWidgets('shows OVERRIDE text with override-badge key when overridden', (tester) async {
    await tester.pumpWidget(wrap(const OverrideBadge(isOverridden: true)));

    expect(find.text('OVERRIDE'), findsOneWidget);
    expect(find.byKey(const Key('override-badge')), findsOneWidget);
    expect(find.byKey(const Key('default-badge')), findsNothing);
  });

  testWidgets('shows DEFAULT text with default-badge key when not overridden', (tester) async {
    await tester.pumpWidget(wrap(const OverrideBadge(isOverridden: false)));

    expect(find.text('DEFAULT'), findsOneWidget);
    expect(find.byKey(const Key('default-badge')), findsOneWidget);
    expect(find.byKey(const Key('override-badge')), findsNothing);
  });

  testWidgets('overridden badge uses primary colorScheme colors', (tester) async {
    await tester.pumpWidget(wrap(const OverrideBadge(isOverridden: true)));

    final element = tester.element(find.byType(OverrideBadge));
    final cs = Theme.of(element).colorScheme;

    final container = tester.widget<Container>(find.descendant(
      of: find.byType(OverrideBadge),
      matching: find.byType(Container),
    ));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, cs.primary);
  });
}
