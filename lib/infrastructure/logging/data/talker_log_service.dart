import 'package:flutter/foundation.dart';
import 'package:habit_loop/infrastructure/logging/contracts/log_service.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// [LogService] implementation backed by [Talker].
///
/// All calls are synchronous under the hood (Talker does not return Futures),
/// so each method completes immediately.
///
/// The in-app Talker overlay is only available in debug mode — the guard is
/// applied at the [ProviderScope] override level in `main.dart`, not here,
/// so this service can be unit-tested without platform concerns.
///
/// **PII rules:** see [LogService] documentation.
final class TalkerLogService implements LogService {
  TalkerLogService(this._talker);

  final Talker _talker;

  @override
  Future<void> debug(String message) async {
    if (!kReleaseMode) {
      _talker.debug(message);
    }
  }

  @override
  Future<void> info(String message) async {
    if (!kReleaseMode) {
      _talker.info(message);
    }
  }

  @override
  Future<void> warning(String message) async {
    if (!kReleaseMode) {
      _talker.warning(message);
    }
  }

  @override
  Future<void> error(String message, {Object? exception, StackTrace? stackTrace}) async {
    if (!kReleaseMode) {
      _talker.error(message, exception, stackTrace);
    }
  }

  @override
  Future<void> logLocal(String message, {String? tag}) async {
    // LOCAL ONLY — this call site is intentionally not forwarded to Crashlytics
    // or any remote service. It may contain PII-adjacent content (habit names,
    // notes) for developer convenience during local debugging.
    if (!kReleaseMode) {
      final prefixed = tag != null ? '[$tag] $message' : message;
      _talker.info(prefixed);
    }
  }
}
