import 'package:flutter/foundation.dart';
import 'package:habit_loop/crashlytics/domain/crashlytics_service.dart';

/// No-op [CrashlyticsService] used as the default when Firebase is not wired in.
///
/// All methods are safe no-ops. This ensures call sites can always call
/// `ref.read(crashlyticsServiceProvider).recordError(...)` without null guards,
/// and tests that do not care about Crashlytics remain unaffected.
final class NoopCrashlyticsService implements CrashlyticsService {
  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {}

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {}

  @override
  Future<void> log(String message) async {}

  @override
  Future<void> setUserIdentifier(String identifier) async {}
}
