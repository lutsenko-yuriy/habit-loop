import 'package:flutter/foundation.dart';
import 'package:habit_loop/infrastructure/crashlytics/domain/crashlytics_service.dart';

/// A fake [CrashlyticsService] that records all calls made to it.
/// Use in tests that need to assert on Crashlytics calls without touching Firebase.
class FakeCrashlyticsService implements CrashlyticsService {
  final List<
      ({
        Object error,
        StackTrace? stack,
        bool fatal,
        Iterable<Object> information,
      })> recordedErrors = [];

  final List<({FlutterErrorDetails details, bool fatal})> recordedFlutterErrors = [];

  final List<String> logs = [];

  final List<String> userIdentifiers = [];

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {
    recordedErrors.add((
      error: error,
      stack: stack,
      fatal: fatal,
      information: information,
    ));
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    recordedFlutterErrors.add((details: details, fatal: fatal));
  }

  @override
  Future<void> log(String message) async {
    logs.add(message);
  }

  @override
  Future<void> setUserIdentifier(String identifier) async {
    userIdentifiers.add(identifier);
  }

  void reset() {
    recordedErrors.clear();
    recordedFlutterErrors.clear();
    logs.clear();
    userIdentifiers.clear();
  }
}
