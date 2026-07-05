import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';
import 'package:habit_loop/slices/dashboard/analytics/kebab_analytics_events.dart';

void main() {
  group('KebabMenuOpenedEvent', () {
    test('implements AnalyticsEvent', () {
      expect(const KebabMenuOpenedEvent(), isA<AnalyticsEvent>());
    });

    test('event name is kebab_menu_opened', () {
      expect(const KebabMenuOpenedEvent().name, 'kebab_menu_opened');
    });

    test('parameters map is empty', () {
      expect(const KebabMenuOpenedEvent().toParameters(), isEmpty);
    });
  });
}
