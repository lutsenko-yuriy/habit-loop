import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/main.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

void main() {
  testWidgets('App renders dashboard with empty state', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pactRepositoryProvider.overrideWithValue(InMemoryPactRepository()),
          showupRepositoryProvider.overrideWithValue(InMemoryShowupRepository()),
        ],
        child: const HabitLoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No pacts yet'), findsOneWidget);
  });
}
