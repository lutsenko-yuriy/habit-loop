import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_screen.dart';

class EnterNameAnalyticsScreen implements AnalyticsScreen {
  const EnterNameAnalyticsScreen();

  @override
  String get name => 'enter_name';
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
