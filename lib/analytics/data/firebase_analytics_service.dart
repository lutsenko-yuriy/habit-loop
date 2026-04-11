import 'package:habit_loop/analytics/domain/analytics_event.dart';
import 'package:habit_loop/analytics/domain/analytics_screen.dart';
import 'package:habit_loop/analytics/domain/analytics_service.dart';

/// Thin abstraction over the Firebase Analytics SDK methods used by this app.
///
/// Exists so tests can inject a fake without depending on the real Firebase SDK.
abstract interface class FirebaseAnalyticsClient {
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  });

  Future<void> logScreenView({required String screenName});
}

/// [AnalyticsService] implementation backed by Firebase Analytics.
///
/// All failures are swallowed so an analytics outage never crashes the app.
/// Null parameter values are stripped before forwarding to Firebase, which
/// does not accept null as a parameter value.
final class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService(this._client);

  final FirebaseAnalyticsClient _client;

  @override
  Future<void> logEvent(AnalyticsEvent event) async {
    try {
      final rawParams = event.toParameters();
      // Strip null values — FirebaseAnalytics rejects them.
      final params = <String, Object>{
        for (final entry in rawParams.entries)
          if (entry.value != null) entry.key: entry.value!,
      };
      await _client.logEvent(
        name: event.name,
        parameters: params.isEmpty ? null : params,
      );
    } catch (_) {
      // Analytics failures must never surface to the user.
    }
  }

  @override
  Future<void> logScreenView(AnalyticsScreen screen) async {
    try {
      await _client.logScreenView(screenName: screen.name);
    } catch (_) {
      // Analytics failures must never surface to the user.
    }
  }
}
