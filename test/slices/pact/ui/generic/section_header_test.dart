import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/pact/ui/generic/section_header.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders title in uppercase', (tester) async {
    await tester.pumpWidget(wrap(const SectionHeader(title: 'stats', labelColor: Colors.grey)));

    expect(find.text('STATS'), findsOneWidget);
  });

  testWidgets('applies labelColor to the text', (tester) async {
    const color = Color(0xFFABCDEF);
    await tester.pumpWidget(wrap(const SectionHeader(title: 'timeline', labelColor: color)));

    final text = tester.widget<Text>(find.text('TIMELINE'));
    expect(text.style?.color, color);
  });

  testWidgets('has letterSpacing 0.5', (tester) async {
    await tester.pumpWidget(wrap(const SectionHeader(title: 'x', labelColor: Colors.black)));

    final text = tester.widget<Text>(find.text('X'));
    expect(text.style?.letterSpacing, 0.5);
  });
}
