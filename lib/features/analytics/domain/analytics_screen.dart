/// Identifies a screen for Firebase Analytics screen-view tracking.
///
/// Each value maps to a snake_case `screen_name` sent to Firebase.
enum AnalyticsScreen {
  /// The dashboard / home screen.
  dashboard('dashboard'),

  /// The pact creation wizard.
  pactCreation('pact_creation'),

  /// The pact detail screen.
  pactDetail('pact_detail'),

  /// The showup detail screen.
  showupDetail('showup_detail');

  const AnalyticsScreen(this.value);

  /// The snake_case screen name sent to Firebase Analytics.
  final String value;
}
