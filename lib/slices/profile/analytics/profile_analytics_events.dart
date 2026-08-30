import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_screen.dart';

class EnterNameAnalyticsScreen implements AnalyticsScreen {
  const EnterNameAnalyticsScreen();

  @override
  String get name => 'enter_name';
}

/// Screen view for the "Change name" dialog opened from the ⋯ menu (HAB-232 WU5).
class ChangeNameAnalyticsScreen implements AnalyticsScreen {
  const ChangeNameAnalyticsScreen();

  @override
  String get name => 'change_name';
}

/// Fired when the user saves a new name via the "Change name" dialog.
class DisplayNameChangedEvent implements AnalyticsEvent {
  const DisplayNameChangedEvent({required this.nameLength, required this.hadPreviousName});

  /// Character count of the new name (grapheme clusters). Never the name
  /// itself (PII rule).
  final int nameLength;

  /// Whether a name was already on file before this change.
  final bool hadPreviousName;

  @override
  String get name => 'display_name_changed';

  @override
  Map<String, Object?> toParameters() => {
        'name_length': nameLength,
        'had_previous_name': hadPreviousName,
      };
}

class DisplayNameEntryCompletedEvent implements AnalyticsEvent {
  const DisplayNameEntryCompletedEvent({required this.action, this.nameLength});

  /// `'saved'` or `'skipped'`.
  final String action;

  /// Character count of the saved name. Never the name itself (PII rule).
  final int? nameLength;

  @override
  String get name => 'display_name_entry_completed';

  @override
  Map<String, Object?> toParameters() => {
        'action': action,
        if (nameLength != null) 'name_length': nameLength,
      };
}
