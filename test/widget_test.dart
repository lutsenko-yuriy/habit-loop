import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_loop/main.dart';

void main() {
  testWidgets('App renders Habit Loop text', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HabitLoopApp()));
    await tester.pumpAndSettle();

    expect(find.text('Habit Loop'), findsOneWidget);
  });
}
