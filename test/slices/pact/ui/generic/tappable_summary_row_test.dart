import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/pact/ui/generic/tappable_summary_row.dart';

Widget _wrap({
  String tapKey = 'test-tap',
  String label = 'Label',
  String value = 'Value',
  Color labelColor = Colors.grey,
  VoidCallback? onTap,
  Widget? divider,
}) {
  return MaterialApp(
    home: Scaffold(
      body: TappableSummaryRow(
        tapKey: tapKey,
        label: label,
        value: value,
        labelColor: labelColor,
        onTap: onTap ?? () {},
        divider: divider,
      ),
    ),
  );
}

void main() {
  testWidgets('renders label and value via SummaryRow', (tester) async {
    await tester.pumpWidget(_wrap(label: 'Habit', value: 'Meditate'));
    expect(find.text('Habit'), findsOneWidget);
    expect(find.text('Meditate'), findsOneWidget);
  });

  testWidgets('GestureDetector uses tapKey as Key', (tester) async {
    await tester.pumpWidget(_wrap(tapKey: 'summary-row-tap-habit_name'));
    expect(find.byKey(const Key('summary-row-tap-habit_name')), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(onTap: () => tapped = true));
    await tester.tap(find.byType(TappableSummaryRow));
    expect(tapped, isTrue);
  });

  testWidgets('shows divider when divider is not null', (tester) async {
    await tester.pumpWidget(_wrap(divider: const Divider(height: 1)));
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('does not show divider when divider is null', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('shows chevron_right icon', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });
}
