import 'package:flutter/foundation.dart';

/// Abstract interface for the Crashlytics service.
///
/// Inject via Riverpod (`crashlyticsServiceProvider`) so call sites are
/// decoupled from the Firebase SDK. Tests can override with a fake.
///
/// **No-throw contract:** all implementations must swallow exceptions
/// internally. Call sites may call any method without wrapping in try/catch.
abstract interface class CrashlyticsService {
  /// Records a non-Flutter error.
  ///
  /// [error] is the exception or error object.
  /// [stack] is the associated stack trace (may be null).
  /// [fatal] marks the error as fatal if true.
  /// [information] provides additional context strings.
  ///
  /// Never throws — implementations swallow failures silently.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    Iterable<Object> information = const [],
  });

  /// Records a Flutter framework error (from [FlutterError.onError]).
  ///
  /// [details] contains the exception, stack trace, and context.
  /// [fatal] marks the error as fatal if true.
  ///
  /// Never throws — implementations swallow failures silently.
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  });

  /// Logs a message to Crashlytics for debugging context.
  ///
  /// Never throws — implementations swallow failures silently.
  Future<void> log(String message);

  /// Sets a user identifier to associate with crash reports.
  ///
  /// Never throws — implementations swallow failures silently.
  Future<void> setUserIdentifier(String identifier);
}
