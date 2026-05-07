import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/notifications/data/notification_router.dart';

void main() {
  group('NotificationRouter.parsePayload', () {
    test('returns correct record for valid JSON with both fields', () {
      const payload = '{"showupId":"abc-123","pactId":"def-456"}';
      final result = NotificationRouter.parsePayload(payload);
      expect(result, isNotNull);
      expect(result!.showupId, 'abc-123');
      expect(result.pactId, 'def-456');
    });

    test('returns null for null payload', () {
      final result = NotificationRouter.parsePayload(null);
      expect(result, isNull);
    });

    test('returns null for empty string payload', () {
      final result = NotificationRouter.parsePayload('');
      expect(result, isNull);
    });

    test('returns null for valid JSON missing showupId', () {
      const payload = '{"pactId":"def-456"}';
      final result = NotificationRouter.parsePayload(payload);
      expect(result, isNull);
    });

    test('returns null for valid JSON missing pactId', () {
      const payload = '{"showupId":"abc-123"}';
      final result = NotificationRouter.parsePayload(payload);
      expect(result, isNull);
    });

    test('returns null for malformed JSON', () {
      const payload = 'not-valid-json{';
      final result = NotificationRouter.parsePayload(payload);
      expect(result, isNull);
    });

    test('ignores extra fields and returns expected fields', () {
      const payload = '{"showupId":"abc-123","pactId":"def-456","extra":"ignored","another":42}';
      final result = NotificationRouter.parsePayload(payload);
      expect(result, isNotNull);
      expect(result!.showupId, 'abc-123');
      expect(result.pactId, 'def-456');
    });
  });
}
