import 'package:habit_loop/infrastructure/logging/contracts/log_service.dart';

/// A fake [LogService] that records all calls made to it.
/// Use in tests that need to assert on log calls without touching Talker.
class FakeLogService implements LogService {
  final List<String> debugMessages = [];
  final List<String> infoMessages = [];
  final List<String> warningMessages = [];
  final List<({String message, Object? exception, StackTrace? stackTrace})> errorCalls = [];
  final List<({String message, String? tag})> localMessages = [];

  @override
  Future<void> debug(String message) async {
    debugMessages.add(message);
  }

  @override
  Future<void> info(String message) async {
    infoMessages.add(message);
  }

  @override
  Future<void> warning(String message) async {
    warningMessages.add(message);
  }

  @override
  Future<void> error(String message, {Object? exception, StackTrace? stackTrace}) async {
    errorCalls.add((message: message, exception: exception, stackTrace: stackTrace));
  }

  @override
  Future<void> logLocal(String message, {String? tag}) async {
    localMessages.add((message: message, tag: tag));
  }

  void reset() {
    debugMessages.clear();
    infoMessages.clear();
    warningMessages.clear();
    errorCalls.clear();
    localMessages.clear();
  }
}
