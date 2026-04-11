import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/analytics/data/noop_analytics_service.dart';
import 'package:habit_loop/analytics/domain/analytics_service.dart';

/// Provides the active [AnalyticsService] to the app.
///
/// Defaults to [NoopAnalyticsService] so tests and non-Firebase environments
/// work without any additional setup. `main.dart` overrides this with
/// [FirebaseAnalyticsService] after `Firebase.initializeApp()` completes.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => NoopAnalyticsService(),
);
