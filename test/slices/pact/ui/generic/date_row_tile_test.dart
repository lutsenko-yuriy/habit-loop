import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/theme/widgets/date_row_tile.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows label text', (tester) async {
    await tester.pumpWidget(wrap(const DateRowTile(
      label: 'Start date',
      backgroundColor: Colors.grey,
    )));

    expect(find.text('Start date'), findsOneWidget);
  });

  testWidgets('shows value text when provided', (tester) async {
    await tester.pumpWidget(wrap(const DateRowTile(
      label: 'Start date',
      value: 'Jan 1, 2026',
      valueColor: Colors.grey,
      backgroundColor: Colors.white,
    )));

    expect(find.text('Start date'), findsOneWidget);
    expect(find.text('Jan 1, 2026'), findsOneWidget);
  });

  testWidgets('shows only label when value is null', (tester) async {
    await tester.pumpWidget(wrap(const DateRowTile(
      label: '5 days remaining',
      backgroundColor: Colors.white,
    )));

    expect(find.text('5 days remaining'), findsOneWidget);
    expect(find.byType(Row), findsNothing);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(DateRowTile(
      label: 'Pick a date',
      value: 'Jan 1, 2026',
      valueColor: Colors.grey,
      backgroundColor: Colors.white,
      onTap: () => tapped = true,
    )));

    await tester.tap(find.byType(DateRowTile));
    expect(tapped, isTrue);
  });

  testWidgets('applies valueColor to value text', (tester) async {
    const color = Colors.blueGrey;
    await tester.pumpWidget(wrap(const DateRowTile(
      label: 'Start date',
      value: 'Jan 1, 2026',
      valueColor: color,
      backgroundColor: Colors.white,
    )));

    final valueText = tester.widget<Text>(find.text('Jan 1, 2026'));
    expect(valueText.style?.color, color);
  });

  testWidgets('default valueColor meets WCAG AA text contrast against a light background', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(const DateRowTile(
      label: 'Start date',
      value: 'Jan 1, 2026',
      backgroundColor: Colors.white,
    )));

    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
