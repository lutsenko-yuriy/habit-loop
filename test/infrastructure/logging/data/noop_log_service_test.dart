import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/logging/data/noop_log_service.dart';

void main() {
  late NoopLogService service;

  setUp(() {
    service = NoopLogService();
  });

  group('NoopLogService', () {
    test('debug completes without throwing', () async {
      await expectLater(service.debug('debug message'), completes);
    });

    test('info completes without throwing', () async {
      await expectLater(service.info('info message'), completes);
    });

    test('warning completes without throwing', () async {
      await expectLater(service.warning('warning message'), completes);
    });

    test('error completes without throwing', () async {
      await expectLater(service.error('error message'), completes);
    });

    test('error with exception completes without throwing', () async {
      await expectLater(
        service.error('error message', exception: Exception('test'), stackTrace: StackTrace.current),
        completes,
      );
    });

    test('logLocal completes without throwing', () async {
      await expectLater(service.logLocal('local message'), completes);
    });

    test('logLocal with tag completes without throwing', () async {
      await expectLater(service.logLocal('local message', tag: 'TAG'), completes);
    });
  });
}
