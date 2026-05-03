/// Abstract interface for the local logging service.
///
/// Inject via Riverpod (`logServiceProvider`) so call sites are decoupled
/// from the Talker SDK. Tests can override with a fake.
///
/// **Split between local and remote:**
/// - `LogService` = local developer visibility (console + in-app overlay).
/// - `CrashlyticsService` = production crash/error reporting.
///
/// View models and services may use both:
/// - `logService.info(...)` for local tracing visible during QA.
/// - `crashlyticsService.log(...)` for production breadcrumbs.
/// - `crashlyticsService.recordError(...)` for non-fatal exceptions.
///
/// **PII rules:**
/// - `debug`, `info`, `warning`, `error` — do NOT include user-entered text
///   (habit names, notes, stop reasons). Log only IDs, lengths, counts, enums.
/// - `logLocal` — MAY include more detail since logs never leave the device.
///   Mark call sites explicitly with a comment: `// LOCAL ONLY — not sent to Crashlytics`.
abstract interface class LogService {
  /// Logs a debug-level message. Use for detailed tracing during development.
  ///
  /// NEVER include user-entered text. Stick to IDs, counts, enum values, lengths.
  Future<void> debug(String message);

  /// Logs an info-level message. Use for significant state transitions.
  ///
  /// NEVER include user-entered text. Stick to IDs, counts, enum values, lengths.
  Future<void> info(String message);

  /// Logs a warning. Use when something unexpected happened but the app recovered.
  ///
  /// NEVER include user-entered text. Stick to IDs, counts, enum values, lengths.
  Future<void> warning(String message);

  /// Logs an error with an optional exception and stack trace.
  ///
  /// NEVER include user-entered text. Stick to IDs, counts, enum values, lengths.
  Future<void> error(String message, {Object? exception, StackTrace? stackTrace});

  /// Logs a message that is LOCAL ONLY — never forwarded to Crashlytics or any
  /// remote service. Use this when you need habit names, notes, or other
  /// PII-adjacent content for local debugging convenience.
  ///
  /// The [tag] parameter helps filter these entries in the Talker overlay.
  Future<void> logLocal(String message, {String? tag});
}
