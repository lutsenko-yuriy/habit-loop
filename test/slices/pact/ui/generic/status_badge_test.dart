import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/pact/ui/generic/status_badge.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders text', (tester) async {
    await tester.pumpWidget(wrap(const StatusBadge(text: 'Active', color: Colors.teal)));

    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('applies color to text style', (tester) async {
    const color = Colors.teal;
    await tester.pumpWidget(wrap(const StatusBadge(text: 'Active', color: color)));

    final text = tester.widget<Text>(find.text('Active'));
    expect(text.style?.color, color);
  });

  testWidgets('uses color with alpha for background', (tester) async {
    const color = Colors.teal;
    await tester.pumpWidget(wrap(const StatusBadge(text: 'Active', color: color)));

    final container = tester.widget<Container>(find.descendant(
      of: find.byType(StatusBadge),
      matching: find.byType(Container),
    ));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, color.withValues(alpha: 0.15));
  });
}
