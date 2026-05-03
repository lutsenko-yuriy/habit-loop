import 'package:habit_loop/infrastructure/logging/contracts/log_service.dart';

/// Silent no-op [LogService] used as the default in tests and whenever
/// logging is not needed.
///
/// All methods complete immediately without side effects.
final class NoopLogService implements LogService {
  @override
  Future<void> debug(String message) async {}

  @override
  Future<void> info(String message) async {}

  @override
  Future<void> warning(String message) async {}

  @override
  Future<void> error(String message, {Object? exception, StackTrace? stackTrace}) async {}

  @override
  Future<void> logLocal(String message, {String? tag}) async {}
}
