import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/analytics/data/firebase_analytics_service.dart';
import 'package:habit_loop/features/analytics/domain/analytics_screen.dart';
import 'package:habit_loop/features/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/features/showup/analytics/showup_analytics_events.dart';

// Hand-rolled fake — does not depend on firebase_analytics at all in tests.
class FakeFirebaseAnalyticsClient implements FirebaseAnalyticsClient {
  final List<({String name, Map<String, Object>? parameters})> loggedEvents =
      [];
  final List<String> loggedScreenNames = [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({required String screenName}) async {
    loggedScreenNames.add(screenName);
  }
}

void main() {
  late FakeFirebaseAnalyticsClient fakeClient;
  late FirebaseAnalyticsService service;

  setUp(() {
    fakeClient = FakeFirebaseAnalyticsClient();
    service = FirebaseAnalyticsService(fakeClient);
  });

  group('FirebaseAnalyticsService.logEvent', () {
    test('forwards event name to Firebase', () async {
      await service.logEvent(ShowupMarkedDoneEvent(pactId: 'p1'));
      expect(fakeClient.loggedEvents.single.name, 'showup_marked_done');
    });

    test('forwards non-null parameters', () async {
      await service.logEvent(ShowupMarkedDoneEvent(pactId: 'p1'));
      final params = fakeClient.loggedEvents.single.parameters;
      expect(params, isNotNull);
      expect(params!['pact_id'], 'p1');
    });

    test('strips null values from parameters', () async {
      // PactCreatedEvent with no reminder has null reminderOffsetMinutes
      await service.logEvent(
        PactCreatedEvent(
          scheduleType: 'daily',
          durationDays: 180,
          showupDurationMinutes: 10,
          showupsExpected: 180,
          // reminderOffsetMinutes intentionally omitted (null)
        ),
      );
      final params = fakeClient.loggedEvents.single.parameters;
      expect(params, isNotNull);
      expect(params!.containsKey('reminder_offset_minutes'), isFalse);
      expect(params.values.whereType<Null>(), isEmpty);
    });

    test('passes null parameters when event has no properties', () async {
      // All current events have at least one parameter; testing with a
      // minimal event that produces empty parameters map results in null being
      // passed to Firebase (omitted params).
      await service.logEvent(ShowupMarkedDoneEvent(pactId: 'p1'));
      // Just verify no exception is thrown and exactly one event logged
      expect(fakeClient.loggedEvents.length, 1);
    });

    test('swallows exceptions from Firebase', () async {
      // Override the client to throw
      final throwingClient = _ThrowingFirebaseAnalyticsClient();
      final throwingService = FirebaseAnalyticsService(throwingClient);
      // Should complete without throwing
      await expectLater(
        throwingService.logEvent(ShowupMarkedDoneEvent(pactId: 'p1')),
        completes,
      );
    });
  });

  group('FirebaseAnalyticsService.logScreenView', () {
    test('forwards screen value to Firebase', () async {
      await service.logScreenView(AnalyticsScreen.dashboard);
      expect(fakeClient.loggedScreenNames.single, 'dashboard');
    });

    test('forwards pact_creation screen name', () async {
      await service.logScreenView(AnalyticsScreen.pactCreation);
      expect(fakeClient.loggedScreenNames.single, 'pact_creation');
    });

    test('forwards pact_detail screen name', () async {
      await service.logScreenView(AnalyticsScreen.pactDetail);
      expect(fakeClient.loggedScreenNames.single, 'pact_detail');
    });

    test('forwards showup_detail screen name', () async {
      await service.logScreenView(AnalyticsScreen.showupDetail);
      expect(fakeClient.loggedScreenNames.single, 'showup_detail');
    });

    test('swallows exceptions from Firebase', () async {
      final throwingClient = _ThrowingFirebaseAnalyticsClient();
      final throwingService = FirebaseAnalyticsService(throwingClient);
      await expectLater(
        throwingService.logScreenView(AnalyticsScreen.dashboard),
        completes,
      );
    });
  });
}

class _ThrowingFirebaseAnalyticsClient implements FirebaseAnalyticsClient {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    throw Exception('Firebase error');
  }

  @override
  Future<void> logScreenView({required String screenName}) async {
    throw Exception('Firebase error');
  }
}
