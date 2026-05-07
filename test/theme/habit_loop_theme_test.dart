import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/main.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_screen.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

void main() {
  testWidgets('HabitLoopApp applies the shared Habit Loop brand color', (tester) async {
    final pactRepo = InMemoryPactRepository();
    final showupRepo = InMemoryShowupRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactTransactionServiceProvider.overrideWithValue(
            InMemoryPactTransactionService(pactRepo, showupRepo),
          ),
        ],
        child: HabitLoopApp(navigatorKey: GlobalKey<NavigatorState>()),
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
