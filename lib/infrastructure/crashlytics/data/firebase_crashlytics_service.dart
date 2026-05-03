import 'package:flutter/foundation.dart';
import 'package:habit_loop/infrastructure/crashlytics/contracts/crashlytics_service.dart';

/// Thin abstraction over the Firebase Crashlytics SDK methods used by this app.
///
/// Exists so tests can inject a fake without depending on the real Firebase SDK.
abstract interface class FirebaseCrashlyticsClient {
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    Iterable<Object> information = const [],
  });

  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  });

  Future<void> log(String message);

  Future<void> setUserIdentifier(String identifier);

  Future<void> setCustomKey(String key, Object value);
}

/// [CrashlyticsService] implementation backed by Firebase Crashlytics.
///
/// All failures are swallowed so a Crashlytics outage never crashes the app.
final class FirebaseCrashlyticsService implements CrashlyticsService {
  FirebaseCrashlyticsService(this._client);

  final FirebaseCrashlyticsClient _client;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {
    try {
      await _client.recordError(
        error,
        stack,
        fatal: fatal,
        information: information,
      );
    } catch (_) {
      // Crashlytics failures must never surface to the user.
    }
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    try {
      await _client.recordFlutterError(details, fatal: fatal);
    } catch (_) {
      // Crashlytics failures must never surface to the user.
    }
  }

  @override
  Future<void> log(String message) async {
    try {
      await _client.log(message);
    } catch (_) {
      // Crashlytics failures must never surface to the user.
    }
  }

  @override
  Future<void> setUserIdentifier(String identifier) async {
    try {
      await _client.setUserIdentifier(identifier);
    } catch (_) {
      // Crashlytics failures must never surface to the user.
    }
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    try {
      await _client.setCustomKey(key, value);
    } catch (_) {
      // Crashlytics failures must never surface to the user.
    }
  }
}
