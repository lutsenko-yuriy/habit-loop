import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_screen.dart';
import 'package:habit_loop/slices/profile/analytics/profile_analytics_events.dart';

void main() {
  group('DisplayNameEntryCompletedEvent', () {
    test('has correct name', () {
      const event = DisplayNameEntryCompletedEvent(action: 'saved', nameLength: 4);
      expect(event.name, 'display_name_entry_completed');
    });

    test('toParameters includes action and name_length when saved', () {
      const event = DisplayNameEntryCompletedEvent(action: 'saved', nameLength: 4);
      final params = event.toParameters();
      expect(params['action'], 'saved');
      expect(params['name_length'], 4);
    });

    test('toParameters omits name_length when skipped', () {
      const event = DisplayNameEntryCompletedEvent(action: 'skipped');
      final params = event.toParameters();
      expect(params['action'], 'skipped');
      expect(params.containsKey('name_length'), isFalse);
    });
  });

  group('EnterNameAnalyticsScreen', () {
    test('implements AnalyticsScreen', () {
      expect(const EnterNameAnalyticsScreen(), isA<AnalyticsScreen>());
    });

    test('name is enter_name', () {
      expect(const EnterNameAnalyticsScreen().name, 'enter_name');
    });
  });
}
