import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_screen.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/main.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

void main() {
  testWidgets('HabitLoopApp applies the shared Habit Loop brand color', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pactRepositoryProvider.overrideWithValue(InMemoryPactRepository()),
          showupRepositoryProvider.overrideWithValue(
            InMemoryShowupRepository(),
          ),
        ],
        child: const HabitLoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      materialApp.theme?.colorScheme.primary,
      HabitLoopColors.primary,
    );

    final dashboardContext = tester.element(find.byType(DashboardScreen));
    expect(
      CupertinoTheme.of(dashboardContext).primaryColor,
      HabitLoopColors.primary,
    );
  });
}
