import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/crashlytics/data/noop_crashlytics_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/contracts/crashlytics_service.dart';

/// Provides the active [CrashlyticsService] to the app.
///
/// Defaults to [NoopCrashlyticsService] so tests and non-Firebase environments
/// work without any additional setup. `main.dart` overrides this with
/// [FirebaseCrashlyticsService] after `Firebase.initializeApp()` completes,
/// but only in release mode.
final crashlyticsServiceProvider = Provider<CrashlyticsService>(
  (ref) => NoopCrashlyticsService(),
);
