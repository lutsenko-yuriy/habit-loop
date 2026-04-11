import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/features/analytics/data/firebase_analytics_client_adapter.dart';
import 'package:habit_loop/features/analytics/data/firebase_analytics_service.dart';
import 'package:habit_loop/features/analytics/ui/generic/analytics_providers.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_screen.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_creation_view_model.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_list_view_model.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/features/showup/ui/generic/showup_detail_view_model.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final analytics = FirebaseAnalyticsService(
    FirebaseAnalyticsClientAdapter(FirebaseAnalytics.instance),
  );

  final pactRepo = InMemoryPactRepository();
  final showupRepo = InMemoryShowupRepository();

  runApp(
    ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(analytics),
        pactRepositoryProvider.overrideWithValue(pactRepo),
        pactCreationRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactCreationShowupRepositoryProvider.overrideWithValue(showupRepo),
        pactDetailRepositoryProvider.overrideWithValue(pactRepo),
        pactDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
        pactListRepositoryProvider.overrideWithValue(pactRepo),
        pactListShowupRepositoryProvider.overrideWithValue(showupRepo),
        showupDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
        showupDetailPactRepositoryProvider.overrideWithValue(pactRepo),
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
