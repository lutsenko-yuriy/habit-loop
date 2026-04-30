import 'package:flutter/foundation.dart';
import 'package:habit_loop/infrastructure/analytics/domain/analytics_event.dart';
import 'package:habit_loop/infrastructure/analytics/domain/analytics_screen.dart';
import 'package:habit_loop/infrastructure/analytics/domain/analytics_service.dart';

/// No-op [AnalyticsService] used as the default when Firebase is not wired in.
///
/// All methods are safe no-ops. This ensures call sites can always call
/// `ref.read(analyticsServiceProvider).logEvent(...)` without null guards,
/// and tests that do not care about analytics remain unaffected.
///
/// In debug and profile builds, each call is logged via [debugPrint] so
/// developers can verify which events are fired during local development.
final class NoopAnalyticsService implements AnalyticsService {
  @override
  Future<void> logEvent(AnalyticsEvent event) async {
    debugPrint('[Analytics] event: ${event.name} ${event.toParameters()}');
  }

  @override
  Future<void> logScreenView(AnalyticsScreen screen) async {
    debugPrint('[Analytics] screen_view: ${screen.name}');
  }
}
