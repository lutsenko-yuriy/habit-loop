import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';

/// Fired when the user taps the ⋯ button and the kebab menu opens.
///
/// Not fired when the single-item shortcut is active — the menu is
/// never shown when only one item is eligible.
final class KebabMenuOpenedEvent implements AnalyticsEvent {
  const KebabMenuOpenedEvent();

  @override
  String get name => 'kebab_menu_opened';

  @override
  Map<String, Object?> toParameters() => {};
}
