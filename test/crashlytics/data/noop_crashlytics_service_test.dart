import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/crashlytics/data/noop_crashlytics_service.dart';

void main() {
  late NoopCrashlyticsService service;

  setUp(() {
    service = NoopCrashlyticsService();
  });

  group('NoopCrashlyticsService', () {
    test('recordError completes without throwing', () async {
      await expectLater(
        service.recordError(
          Exception('test error'),
          StackTrace.current,
          fatal: false,
        ),
        completes,
      );
    });

    test('recordError with fatal=true completes without throwing', () async {
      await expectLater(
        service.recordError(
          Exception('fatal error'),
          StackTrace.current,
          fatal: true,
        ),
        completes,
      );
    });

    test('recordError with null stack completes without throwing', () async {
      await expectLater(
        service.recordError(Exception('error'), null),
        completes,
      );
    });

    test('recordFlutterError completes without throwing', () async {
      final details = FlutterErrorDetails(
        exception: Exception('flutter error'),
        stack: StackTrace.current,
      );
      await expectLater(
        service.recordFlutterError(details),
        completes,
      );
    });

    test('log completes without throwing', () async {
      await expectLater(service.log('test message'), completes);
    });

    test('setUserIdentifier completes without throwing', () async {
      await expectLater(service.setUserIdentifier('user-123'), completes);
    });
  });
}
