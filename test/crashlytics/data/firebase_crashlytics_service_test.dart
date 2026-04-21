import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/crashlytics/data/firebase_crashlytics_service.dart';

// Hand-rolled fake — does not depend on firebase_crashlytics at all in tests.
class FakeFirebaseCrashlyticsClient implements FirebaseCrashlyticsClient {
  final List<
      ({
        Object error,
        StackTrace? stack,
        bool fatal,
        Iterable<Object> information,
      })> recordedErrors = [];
  final List<({FlutterErrorDetails details, bool fatal})>
      recordedFlutterErrors = [];
  final List<String> logs = [];
  final List<String> userIdentifiers = [];

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {
    recordedErrors.add((
      error: error,
      stack: stack,
      fatal: fatal,
      information: information,
    ));
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    recordedFlutterErrors.add((details: details, fatal: fatal));
  }

  @override
  Future<void> log(String message) async {
    logs.add(message);
  }

  @override
  Future<void> setUserIdentifier(String identifier) async {
    userIdentifiers.add(identifier);
  }
}

class _ThrowingFirebaseCrashlyticsClient implements FirebaseCrashlyticsClient {
  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {
    throw Exception('Firebase Crashlytics error');
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    throw Exception('Firebase Crashlytics error');
  }

  @override
  Future<void> log(String message) async {
    throw Exception('Firebase Crashlytics error');
  }

  @override
  Future<void> setUserIdentifier(String identifier) async {
    throw Exception('Firebase Crashlytics error');
  }
}

void main() {
  late FakeFirebaseCrashlyticsClient fakeClient;
  late FirebaseCrashlyticsService service;

  setUp(() {
    fakeClient = FakeFirebaseCrashlyticsClient();
    service = FirebaseCrashlyticsService(fakeClient);
  });

  group('FirebaseCrashlyticsService.recordError', () {
    test('forwards error and stack to the client', () async {
      final error = Exception('test error');
      final stack = StackTrace.current;
      await service.recordError(error, stack);
      expect(fakeClient.recordedErrors.single.error, same(error));
      expect(fakeClient.recordedErrors.single.stack, same(stack));
    });

    test('forwards fatal flag to the client', () async {
      await service.recordError(Exception('e'), StackTrace.current,
          fatal: true);
      expect(fakeClient.recordedErrors.single.fatal, isTrue);
    });

    test('forwards non-fatal flag to the client', () async {
      await service.recordError(
        Exception('e'),
        StackTrace.current,
        fatal: false,
      );
      expect(fakeClient.recordedErrors.single.fatal, isFalse);
    });

    test('forwards information list to the client', () async {
      final info = ['extra info', 42];
      await service.recordError(
        Exception('e'),
        StackTrace.current,
        information: info,
      );
      expect(fakeClient.recordedErrors.single.information, equals(info));
    });

    test('swallows exceptions from the client', () async {
      final throwingService = FirebaseCrashlyticsService(
        _ThrowingFirebaseCrashlyticsClient(),
      );
      await expectLater(
        throwingService.recordError(Exception('e'), StackTrace.current),
        completes,
      );
    });
  });

  group('FirebaseCrashlyticsService.recordFlutterError', () {
    test('forwards FlutterErrorDetails to the client', () async {
      final details = FlutterErrorDetails(
        exception: Exception('flutter error'),
        stack: StackTrace.current,
        library: 'test library',
        context: ErrorDescription('doing something'),
      );
      await service.recordFlutterError(details);
      expect(fakeClient.recordedFlutterErrors.single.details, same(details));
    });

    test('forwards fatal flag to the client', () async {
      final details = FlutterErrorDetails(exception: Exception('e'));
      await service.recordFlutterError(details, fatal: true);
      expect(fakeClient.recordedFlutterErrors.single.fatal, isTrue);
    });

    test('swallows exceptions from the client', () async {
      final throwingService = FirebaseCrashlyticsService(
        _ThrowingFirebaseCrashlyticsClient(),
      );
      final details = FlutterErrorDetails(exception: Exception('e'));
      await expectLater(
        throwingService.recordFlutterError(details),
        completes,
      );
    });
  });

  group('FirebaseCrashlyticsService.log', () {
    test('forwards log message to the client', () async {
      await service.log('hello world');
      expect(fakeClient.logs.single, 'hello world');
    });

    test('swallows exceptions from the client', () async {
      final throwingService = FirebaseCrashlyticsService(
        _ThrowingFirebaseCrashlyticsClient(),
      );
      await expectLater(throwingService.log('msg'), completes);
    });
  });

  group('FirebaseCrashlyticsService.setUserIdentifier', () {
    test('forwards identifier to the client', () async {
      await service.setUserIdentifier('user-abc');
      expect(fakeClient.userIdentifiers.single, 'user-abc');
    });

    test('swallows exceptions from the client', () async {
      final throwingService = FirebaseCrashlyticsService(
        _ThrowingFirebaseCrashlyticsClient(),
      );
      await expectLater(
        throwingService.setUserIdentifier('user-abc'),
        completes,
      );
    });
  });
}
