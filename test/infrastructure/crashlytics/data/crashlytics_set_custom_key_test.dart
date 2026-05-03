import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/crashlytics/data/firebase_crashlytics_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/data/noop_crashlytics_service.dart';

// ---------------------------------------------------------------------------
// Fake client that also tracks setCustomKey calls.
// ---------------------------------------------------------------------------
class FakeFirebaseCrashlyticsClientWithCustomKey implements FirebaseCrashlyticsClient {
  final List<({String key, Object value})> customKeys = [];

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {}

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details, {bool fatal = false}) async {}

  @override
  Future<void> log(String message) async {}

  @override
  Future<void> setUserIdentifier(String identifier) async {}

  @override
  Future<void> setCustomKey(String key, Object value) async {
    customKeys.add((key: key, value: value));
  }
}

class _ThrowingClient implements FirebaseCrashlyticsClient {
  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {}

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details, {bool fatal = false}) async {}

  @override
  Future<void> log(String message) async {}

  @override
  Future<void> setUserIdentifier(String identifier) async {}

  @override
  Future<void> setCustomKey(String key, Object value) async {
    throw Exception('Firebase error');
  }
}

void main() {
  group('FirebaseCrashlyticsService.setCustomKey', () {
    late FakeFirebaseCrashlyticsClientWithCustomKey fakeClient;
    late FirebaseCrashlyticsService service;

    setUp(() {
      fakeClient = FakeFirebaseCrashlyticsClientWithCustomKey();
      service = FirebaseCrashlyticsService(fakeClient);
    });

    test('forwards key and string value to the client', () async {
      await service.setCustomKey('current_screen', 'dashboard');
      expect(fakeClient.customKeys.single.key, 'current_screen');
      expect(fakeClient.customKeys.single.value, 'dashboard');
    });

    test('forwards key and int value to the client', () async {
      await service.setCustomKey('active_pacts_count', 3);
      expect(fakeClient.customKeys.single.key, 'active_pacts_count');
      expect(fakeClient.customKeys.single.value, 3);
    });

    test('swallows exceptions from the client', () async {
      final throwingService = FirebaseCrashlyticsService(_ThrowingClient());
      await expectLater(throwingService.setCustomKey('key', 'value'), completes);
    });
  });

  group('NoopCrashlyticsService.setCustomKey', () {
    test('completes without throwing', () async {
      final service = NoopCrashlyticsService();
      await expectLater(service.setCustomKey('active_pacts_count', 3), completes);
    });

    test('completes with string value without throwing', () async {
      final service = NoopCrashlyticsService();
      await expectLater(service.setCustomKey('current_screen', 'dashboard'), completes);
    });
  });
}
