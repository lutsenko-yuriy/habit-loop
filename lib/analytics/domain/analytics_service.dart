import 'package:habit_loop/analytics/domain/analytics_event.dart';
import 'package:habit_loop/analytics/domain/analytics_screen.dart';

/// Abstract interface for the analytics service.
///
/// Inject via Riverpod (`analyticsServiceProvider`) so call sites are
/// decoupled from the Firebase SDK. Tests can override with a fake.
abstract interface class AnalyticsService {
  /// Logs a typed [event] to the analytics backend.
  Future<void> logEvent(AnalyticsEvent event);

  /// Logs a screen view for [screen].
  Future<void> logScreenView(AnalyticsScreen screen);
}
