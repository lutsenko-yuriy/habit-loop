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

  group('ChangeNameAnalyticsScreen', () {
    test('implements AnalyticsScreen', () {
      expect(const ChangeNameAnalyticsScreen(), isA<AnalyticsScreen>());
    });

    test('name is change_name', () {
      expect(const ChangeNameAnalyticsScreen().name, 'change_name');
    });
  });

  group('DisplayNameChangedEvent', () {
    test('has correct name', () {
      const event = DisplayNameChangedEvent(nameLength: 3, hadPreviousName: true);
      expect(event.name, 'display_name_changed');
    });

    test('toParameters includes name_length and had_previous_name', () {
      const event = DisplayNameChangedEvent(nameLength: 3, hadPreviousName: true);
      final params = event.toParameters();
      expect(params['name_length'], 3);
      expect(params['had_previous_name'], isTrue);
    });

    test('had_previous_name is false when there was no prior name', () {
      const event = DisplayNameChangedEvent(nameLength: 5, hadPreviousName: false);
      expect(event.toParameters()['had_previous_name'], isFalse);
    });
  });
}
