import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:habit_loop/analytics/data/firebase_analytics_service.dart';

/// Adapts the real [FirebaseAnalytics] SDK to the [FirebaseAnalyticsClient]
/// interface so [FirebaseAnalyticsService] never directly imports the SDK.
///
/// Only constructed in `main.dart`; tests use [FakeFirebaseAnalyticsClient].
final class FirebaseAnalyticsClientAdapter implements FirebaseAnalyticsClient {
  FirebaseAnalyticsClientAdapter(this._firebase);

  final FirebaseAnalytics _firebase;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) {
    return _firebase.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> logScreenView({required String screenName}) {
    return _firebase.logScreenView(screenName: screenName);
  }
}
