import 'package:habit_loop/infrastructure/analytics/domain/analytics_event.dart';
import 'package:habit_loop/infrastructure/analytics/domain/analytics_screen.dart';

/// Abstract interface for the analytics service.
///
/// Inject via Riverpod (`analyticsServiceProvider`) so call sites are
/// decoupled from the Firebase SDK. Tests can override with a fake.
///
/// **No-throw contract:** all implementations must swallow exceptions
/// internally. Call sites may call [logEvent] and [logScreenView] without
/// wrapping them in try/catch blocks.
abstract interface class AnalyticsService {
  /// Logs a typed [event] to the analytics backend.
  ///
  /// Never throws — implementations swallow failures silently.
  Future<void> logEvent(AnalyticsEvent event);

  /// Logs a screen view for [screen].
  ///
  /// Never throws — implementations swallow failures silently.
  Future<void> logScreenView(AnalyticsScreen screen);
}
