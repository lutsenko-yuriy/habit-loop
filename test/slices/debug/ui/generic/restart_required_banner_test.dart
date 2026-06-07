import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/debug/ui/generic/restart_required_banner.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows restart message text', (tester) async {
    await tester.pumpWidget(wrap(const RestartRequiredBanner(color: Colors.amber)));

    expect(find.textContaining('restart'), findsOneWidget);
  });

  testWidgets('shows default warning icon when none provided', (tester) async {
    await tester.pumpWidget(wrap(const RestartRequiredBanner(color: Colors.amber)));

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('shows custom icon when provided', (tester) async {
    await tester.pumpWidget(wrap(const RestartRequiredBanner(
      color: Colors.amber,
      icon: Icons.info_outline,
    )));

    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('applies color to icon and border', (tester) async {
    const color = Colors.amber;
    await tester.pumpWidget(wrap(const RestartRequiredBanner(color: color)));

    final icon = tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded));
    expect(icon.color, color);

    final container = tester.widget<Container>(find.descendant(
      of: find.byType(RestartRequiredBanner),
      matching: find.byType(Container),
    ));
    final decoration = container.decoration as BoxDecoration;
    final border = decoration.border as Border;
    expect(border.top.color, color);
  });
}
