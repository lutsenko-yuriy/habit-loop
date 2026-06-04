import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_constants.dart';

void main() {
  group('NotificationConstants', () {
    test('markDoneActionId is the expected string', () {
      expect(NotificationConstants.markDoneActionId, 'mark_done');
    });

    group('reminderNotificationId', () {
      test('returns a non-negative value within the 32-bit signed int range', () {
        for (final id in _sampleIds) {
          final result = NotificationConstants.reminderNotificationId(id);
          expect(result, greaterThanOrEqualTo(0));
          expect(result, lessThan(2147483647));
        }
      });
    });

    group('deadlineNotificationId', () {
      test('returns a value within the upper half of the 32-bit signed int range', () {
        for (final id in _sampleIds) {
          final result = NotificationConstants.deadlineNotificationId(id);
          expect(result, greaterThanOrEqualTo(1073741824));
          expect(result, lessThanOrEqualTo(2147483646));
        }
      });
    });

    test('reminder and deadline ID ranges are disjoint for all sample inputs', () {
      for (final id in _sampleIds) {
        final reminderId = NotificationConstants.reminderNotificationId(id);
        final deadlineId = NotificationConstants.deadlineNotificationId(id);
        expect(
          reminderId,
          isNot(equals(deadlineId)),
          reason: 'Reminder and deadline IDs must be different for showupId="$id"',
        );
        // Reminder IDs are in [0, 1073741823]; deadline IDs are in [1073741824, 2147483646].
        // Any reminderId < 1073741824 guarantees it is disjoint from any deadlineId >= 1073741824.
        expect(
          reminderId,
          lessThan(1073741824),
          reason: 'Reminder ID for "$id" must be in the lower range [0, 1073741823]',
        );
        expect(
          deadlineId,
          greaterThanOrEqualTo(1073741824),
          reason: 'Deadline ID for "$id" must be in the upper range [1073741824, 2147483646]',
        );
      }
    });

    test('IDs are stable across Dart VM restarts — hardcoded FNV-1a expected values', () {
      // These values are locked in. If they ever change, the hash formula
      // changed and all in-flight notifications become uncancellable after a
      // cold restart. Do not update them without scheduling a migration.
      expect(NotificationConstants.reminderNotificationId('a1b2c3d4-e5f6-7890-abcd-ef1234567890'), 112419231);
      expect(NotificationConstants.deadlineNotificationId('a1b2c3d4-e5f6-7890-abcd-ef1234567890'), 1186161058);
      expect(NotificationConstants.reminderNotificationId('showup-id-001'), 1049301351);
      expect(NotificationConstants.deadlineNotificationId('showup-id-001'), 2123043176);
    });

    test('two different showup IDs produce different reminder IDs (no collision on sample)', () {
      final reminderIds = _sampleIds.map(NotificationConstants.reminderNotificationId).toList();
      final deadlineIds = _sampleIds.map(NotificationConstants.deadlineNotificationId).toList();
      // Check uniqueness within each set for the sample — not guaranteed universally
      // due to the modulo hash, but the sample should not collide.
      expect(reminderIds.toSet().length, reminderIds.length);
      expect(deadlineIds.toSet().length, deadlineIds.length);
    });
  });
}

/// A sample of showup UUIDs used to verify ID formula properties.
const _sampleIds = [
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  'ffffffff-ffff-ffff-ffff-ffffffffffff',
  '00000000-0000-0000-0000-000000000000',
  '11111111-1111-1111-1111-111111111111',
  'deadbeef-dead-beef-dead-beefdeadbeef',
  'cafebabe-cafe-babe-cafe-babecafebabe',
  '12345678-1234-1234-1234-123456781234',
  'showup-id-001',
  'showup-id-002',
  'very-long-showup-identifier-that-exceeds-typical-uuid-length-for-stress-testing',
];
