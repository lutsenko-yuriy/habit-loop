import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/analytics/domain/analytics_event.dart';

/// Minimal concrete implementation used only to verify the base class contract.
final class _TestEvent extends AnalyticsEvent {
  @override
  String get name => 'test_event';

  @override
  Map<String, Object?> toParameters() => {'key': 'value'};
}

void main() {
  group('AnalyticsEvent base class', () {
    test('subclass provides a name', () {
      final event = _TestEvent();
      expect(event.name, 'test_event');
    });

    test('subclass provides parameters', () {
      final event = _TestEvent();
      expect(event.toParameters(), {'key': 'value'});
    });

    test('is abstract — cannot be instantiated directly', () {
      // The existence of _TestEvent and its successful construction proves
      // that the abstract class is correctly extensible.
      expect(_TestEvent(), isA<AnalyticsEvent>());
    });
  });
}
