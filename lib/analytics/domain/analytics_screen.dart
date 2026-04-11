/// Identifies a screen for Firebase Analytics screen-view tracking.
/// Implementations live in per-vertical `analytics/` subdirectories.
abstract class AnalyticsScreen {
  /// The snake_case screen name sent to Firebase Analytics.
  String get name;
}
