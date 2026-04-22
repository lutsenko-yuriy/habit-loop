import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/pact/ui/generic/summary_row.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('renders both label and value', (tester) async {
    await _pump(
      tester,
      const SummaryRow(label: 'Habit', value: 'Meditate'),
    );
    expect(find.text('Habit'), findsOneWidget);
    expect(find.text('Meditate'), findsOneWidget);
  });

  testWidgets('applies the caller-supplied labelColor to the label', (tester) async {
    await _pump(
      tester,
      const SummaryRow(
        label: 'Habit',
        value: 'Meditate',
        labelColor: CupertinoColors.systemGrey,
      ),
    );
    final labelText = tester.widget<Text>(find.text('Habit'));
    expect(labelText.style?.color, CupertinoColors.systemGrey);
  });

  testWidgets('reserves a 110-wide column for the label', (tester) async {
    await _pump(
      tester,
      const SummaryRow(label: 'Habit', value: 'Meditate'),
    );
    // The SizedBox wrapping the label should have width 110.
    final sizedBox = tester.widget<SizedBox>(
      find.ancestor(of: find.text('Habit'), matching: find.byType(SizedBox)).first,
    );
    expect(sizedBox.width, 110);
  });
}
