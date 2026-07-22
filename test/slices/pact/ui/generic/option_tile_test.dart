import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/pact/ui/generic/option_tile.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows label text', (tester) async {
    await tester.pumpWidget(wrap(OptionTile(
      isSelected: false,
      label: 'No reminder',
      onTap: () {},
      selectedColor: Colors.teal,
      unselectedColor: Colors.grey,
    )));

    expect(find.text('No reminder'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var called = false;
    await tester.pumpWidget(wrap(OptionTile(
      isSelected: false,
      label: 'Option',
      onTap: () => called = true,
      selectedColor: Colors.teal,
      unselectedColor: Colors.grey,
    )));

    await tester.tap(find.byType(OptionTile));
    expect(called, isTrue);
  });

  testWidgets('shows check_circle icon when selected', (tester) async {
    await tester.pumpWidget(wrap(OptionTile(
      isSelected: true,
      label: 'Option',
      onTap: () {},
      selectedColor: Colors.teal,
      unselectedColor: Colors.grey,
    )));

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
  });

  testWidgets('shows radio_button_unchecked icon when not selected', (tester) async {
    await tester.pumpWidget(wrap(OptionTile(
      isSelected: false,
      label: 'Option',
      onTap: () {},
      selectedColor: Colors.teal,
      unselectedColor: Colors.grey,
    )));

    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('selected tile has border with selectedColor', (tester) async {
    const color = Colors.teal;
    await tester.pumpWidget(wrap(OptionTile(
      isSelected: true,
      label: 'Option',
      onTap: () {},
      selectedColor: color,
      unselectedColor: Colors.grey,
    )));

    final container = tester.widget<Container>(find.descendant(
      of: find.byType(OptionTile),
      matching: find.byType(Container),
    ));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
  });

  testWidgets('uses custom selectedIcon when provided', (tester) async {
    await tester.pumpWidget(wrap(OptionTile(
      isSelected: true,
      label: 'Option',
      onTap: () {},
      selectedColor: Colors.teal,
      unselectedColor: Colors.grey,
      selectedIcon: Icons.star,
      unselectedIcon: Icons.star_border,
    )));

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('uses custom unselectedIcon when provided', (tester) async {
    await tester.pumpWidget(wrap(OptionTile(
      isSelected: false,
      label: 'Option',
      onTap: () {},
      selectedColor: Colors.teal,
      unselectedColor: Colors.grey,
      selectedIcon: Icons.star,
      unselectedIcon: Icons.star_border,
    )));

    expect(find.byIcon(Icons.star_border), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
  });

  testWidgets('unselected tile has no border', (tester) async {
    await tester.pumpWidget(wrap(OptionTile(
      isSelected: false,
      label: 'Option',
      onTap: () {},
      selectedColor: Colors.teal,
      unselectedColor: Colors.grey,
    )));

    final container = tester.widget<Container>(find.descendant(
      of: find.byType(OptionTile),
      matching: find.byType(Container),
    ));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.border, isNull);
  });

  group('accessibility', () {
    testWidgets('exposes a Semantics label with selected state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(OptionTile(
        isSelected: true,
        label: 'Daily',
        onTap: () {},
        selectedColor: Colors.teal,
        unselectedColor: Colors.grey,
      )));

      expect(
        tester.getSemantics(find.byType(OptionTile)),
        matchesSemantics(label: 'Daily', isButton: true, isSelected: true, hasSelectedState: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('unselected tile exposes isSelected: false', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(OptionTile(
        isSelected: false,
        label: 'Weekdays',
        onTap: () {},
        selectedColor: Colors.teal,
        unselectedColor: Colors.grey,
      )));

      expect(
        tester.getSemantics(find.byType(OptionTile)),
        matchesSemantics(
          label: 'Weekdays',
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('meets the Android and iOS tap-target guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(OptionTile(
        isSelected: false,
        label: 'Option',
        onTap: () {},
        selectedColor: Colors.teal,
        unselectedColor: Colors.grey,
      )));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });
  });
}
