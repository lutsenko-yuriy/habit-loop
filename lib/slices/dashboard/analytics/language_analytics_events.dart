import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_screen.dart';

/// Screen identifier for the language picker sheet/dialog.
///
/// Logged when the language picker opens (iOS: [CupertinoActionSheet];
/// Android: [SimpleDialog]).
class LanguagePickerAnalyticsScreen implements AnalyticsScreen {
  const LanguagePickerAnalyticsScreen();

  @override
  String get name => 'language_picker';
}

/// Fired when the user opens the language picker before any selection is made.
///
/// The gap between [LanguageChangeRequestedEvent] count and
/// [LanguageChangedEvent] count is the abandonment rate.
final class LanguageChangeRequestedEvent extends AnalyticsEvent {
  @override
  String get name => 'language_change_requested';

  @override
  Map<String, Object?> toParameters() => {'source': 'dashboard'};
}

/// Fired when the user selects a language from the picker and the change is
/// applied.
///
/// [fromLanguage] and [toLanguage] are ISO 639-1 language codes drawn from the
/// closed set `{en, fr, de, ru}`.
final class LanguageChangedEvent extends AnalyticsEvent {
  LanguageChangedEvent({required this.fromLanguage, required this.toLanguage});

  /// Language code active before the change.
  final String fromLanguage;

  /// Language code selected by the user.
  final String toLanguage;

  @override
  String get name => 'language_changed';

  @override
  Map<String, Object?> toParameters() => {
        'from_language': fromLanguage,
        'to_language': toLanguage,
        'source': 'dashboard',
      };
}
