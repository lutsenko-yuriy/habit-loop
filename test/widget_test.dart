import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/main.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import 'infrastructure/remote_config/fake_remote_config_service.dart';

void main() {
  testWidgets('App renders onboarding carousel with empty state', (WidgetTester tester) async {
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
          // Disable auto-advance timer so pumpAndSettle() does not hang.
          remoteConfigServiceProvider.overrideWithValue(
            FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': 0}),
          ),
        ],
        child: HabitLoopApp(navigatorKey: GlobalKey<NavigatorState>()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No pacts yet'), findsNothing);
    expect(find.text('Create a Pact'), findsOneWidget);
  });
}
