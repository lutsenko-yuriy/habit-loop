import 'package:flutter/foundation.dart';
import 'package:habit_loop/infrastructure/logging/contracts/log_service.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// [LogService] implementation backed by [Talker].
///
/// All calls are synchronous under the hood (Talker does not return Futures),
/// so each method completes immediately.
///
/// This service is only used in debug/profile builds — the [ProviderScope]
/// override in `main.dart` only wires it when `!kReleaseMode`. Release builds
/// use the silent [NoopLogService] default from [logServiceProvider].
///
/// **No-throw contract:** every method body is wrapped in try/catch so that a
/// Talker failure can never crash the app. Logging is best-effort diagnostics.
///
/// **PII rules:** see [LogService] documentation.
final class TalkerLogService implements LogService {
  TalkerLogService(this._talker) : assert(!kReleaseMode, 'TalkerLogService must not be used in release builds');

  final Talker _talker;

  @override
  Future<void> debug(String message) async {
    try {
      _talker.debug(message);
    } catch (_) {}
  }

  @override
  Future<void> info(String message) async {
    try {
      _talker.info(message);
    } catch (_) {}
  }

  @override
  Future<void> warning(String message) async {
    try {
      _talker.warning(message);
    } catch (_) {}
  }

  @override
  Future<void> error(String message, {Object? exception, StackTrace? stackTrace}) async {
    try {
      _talker.error(message, exception, stackTrace);
    } catch (_) {}
  }

  @override
  Future<void> logLocal(String message, {String? tag}) async {
    // LOCAL ONLY — this call site is intentionally not forwarded to Crashlytics
    // or any remote service. It may contain PII-adjacent content (habit names,
    // notes) for developer convenience during local debugging.
    try {
      final prefixed = tag != null ? '[$tag] $message' : message;
      _talker.info(prefixed);
    } catch (_) {}
  }
}
