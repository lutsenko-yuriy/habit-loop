import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_screen.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_creation_view_model.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

void main() {
  final pactRepo = InMemoryPactRepository();

  runApp(
    ProviderScope(
      overrides: [
        pactRepositoryProvider.overrideWithValue(pactRepo),
        pactCreationRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider
            .overrideWithValue(InMemoryShowupRepository()),
      ],
      child: const HabitLoopApp(),
    ),
  );
}

class HabitLoopApp extends StatelessWidget {
  const HabitLoopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Loop',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const DashboardScreen(),
    );
  }
}
