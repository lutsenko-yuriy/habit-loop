/// A typed analytics event sent via [AnalyticsService].
///
/// Subclasses live in per-vertical `analytics/` subdirectories so each event
/// is co-located with the domain it describes. The domain layer is SDK-free —
/// Firebase is only referenced in the data layer.
abstract class AnalyticsEvent {
  /// The Firebase event name (snake_case).
  String get name;

  /// Event parameters. Null values are excluded before sending to Firebase.
  Map<String, Object?> toParameters();
}
