import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:habit_loop/crashlytics/data/firebase_crashlytics_service.dart';

/// Adapts the real [FirebaseCrashlytics] SDK to the [FirebaseCrashlyticsClient]
/// interface so [FirebaseCrashlyticsService] never directly imports the SDK.
///
/// Only constructed in `main.dart`; tests use a hand-rolled fake client.
final class FirebaseCrashlyticsClientAdapter implements FirebaseCrashlyticsClient {
  FirebaseCrashlyticsClientAdapter(this._firebase);

  final FirebaseCrashlytics _firebase;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    Iterable<Object> information = const [],
  }) {
    return _firebase.recordError(
      error,
      stack,
      fatal: fatal,
      information: information,
    );
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) {
    return _firebase.recordFlutterError(details, fatal: fatal);
  }

  @override
  Future<void> log(String message) {
    return _firebase.log(message);
  }

  @override
  Future<void> setUserIdentifier(String identifier) {
    return _firebase.setUserIdentifier(identifier);
  }
}
