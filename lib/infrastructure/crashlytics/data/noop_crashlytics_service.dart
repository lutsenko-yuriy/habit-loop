import 'package:flutter/foundation.dart';
import 'package:habit_loop/infrastructure/crashlytics/contracts/crashlytics_service.dart';

/// No-op [CrashlyticsService] used as the default when Firebase is not wired in.
///
/// All methods are safe no-ops. This ensures call sites can always call
/// `ref.read(crashlyticsServiceProvider).recordError(...)` without null guards,
/// and tests that do not care about Crashlytics remain unaffected.
///
/// In debug and profile builds, each call is logged via [debugPrint] so
/// developers can verify which errors and messages would be reported to Firebase.
final class NoopCrashlyticsService implements CrashlyticsService {
  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {
    debugPrint('[Crashlytics] recordError (fatal: $fatal): $error');
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    debugPrint(
      '[Crashlytics] recordFlutterError (fatal: $fatal): '
      '${details.exceptionAsString()}',
    );
  }

  @override
  Future<void> log(String message) async {
    debugPrint('[Crashlytics] log: $message');
  }

  @override
  Future<void> setUserIdentifier(String identifier) async {
    debugPrint('[Crashlytics] setUserIdentifier: $identifier');
  }
}
