import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/tail_zone.dart';

void main() {
  // Anchored on: now = 2026-06-15 14:30 (mid-day), days = 7.
  // today = 2026-06-15 00:00, cutoff = 2026-06-08 00:00.
  // In-tail: scheduledAt >= cutoff (i.e. NOT before cutoff).
  final now = DateTime(2026, 6, 15, 14, 30);
  const days = 7;

  group('TailZone.contains', () {
    test('showup on today is in-tail', () {
      final scheduledAt = DateTime(2026, 6, 15, 8, 0);
      expect(TailZone.contains(scheduledAt: scheduledAt, now: now, days: days), isTrue);
    });

    test('showup exactly on cutoff date is in-tail (inclusive boundary)', () {
      final scheduledAt = DateTime(2026, 6, 8, 8, 0); // cutoff = 2026-06-08
      expect(TailZone.contains(scheduledAt: scheduledAt, now: now, days: days), isTrue);
    });

    test('showup one day before cutoff is out-of-tail', () {
      final scheduledAt = DateTime(2026, 6, 7, 8, 0);
      expect(TailZone.contains(scheduledAt: scheduledAt, now: now, days: days), isFalse);
    });

    test('showup far in the past is out-of-tail', () {
      final scheduledAt = DateTime(2026, 1, 1, 8, 0);
      expect(TailZone.contains(scheduledAt: scheduledAt, now: now, days: days), isFalse);
    });

    test('future showup is in-tail', () {
      final scheduledAt = DateTime(2026, 6, 20, 8, 0);
      expect(TailZone.contains(scheduledAt: scheduledAt, now: now, days: days), isTrue);
    });

    test('cutoff is calendar-day-based: time-of-day on now does not shift the boundary', () {
      // now = midnight vs mid-day should produce the same cutoff.
      final nowMidnight = DateTime(2026, 6, 15, 0, 0);
      final nowMidDay = DateTime(2026, 6, 15, 12, 0);
      final scheduledAt = DateTime(2026, 6, 8, 8, 0); // on the cutoff date
      expect(
        TailZone.contains(scheduledAt: scheduledAt, now: nowMidnight, days: days),
        equals(TailZone.contains(scheduledAt: scheduledAt, now: nowMidDay, days: days)),
      );
    });

    test('days=0 means only today and future are in-tail', () {
      final onCutoff = DateTime(2026, 6, 15, 8, 0); // today
      final yesterday = DateTime(2026, 6, 14, 8, 0);
      expect(TailZone.contains(scheduledAt: onCutoff, now: now, days: 0), isTrue);
      expect(TailZone.contains(scheduledAt: yesterday, now: now, days: 0), isFalse);
    });

    test('larger window includes more days', () {
      final scheduledAt = DateTime(2026, 6, 1, 8, 0); // 14 days before today
      expect(TailZone.contains(scheduledAt: scheduledAt, now: now, days: 7), isFalse);
      expect(TailZone.contains(scheduledAt: scheduledAt, now: now, days: 14), isTrue);
      expect(TailZone.contains(scheduledAt: scheduledAt, now: now, days: 21), isTrue);
    });
  });
}
