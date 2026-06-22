import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';

void main() {
  final _at = DateTime(2024, 6, 1);

  group('PactCreatedMilestone', () {
    test('exposes all fields', () {
      const schedule = DailySchedule(timeOfDay: Duration(hours: 8));
      final m = PactCreatedMilestone(
        sortAt: _at,
        habitName: 'Meditate',
        schedule: schedule,
        plannedEndDate: DateTime(2024, 7, 1),
      );
      expect(m.sortAt, _at);
      expect(m.habitName, 'Meditate');
      expect(m.schedule, schedule);
      expect(m.plannedEndDate, DateTime(2024, 7, 1));
    });
  });

  group('CurrentStateMilestone', () {
    test('exposes required fields; nextScheduledAt defaults to null', () {
      final m = CurrentStateMilestone(
        sortAt: _at,
        showupsRemaining: 5,
        plannedEndDate: DateTime(2024, 7, 1),
      );
      expect(m.sortAt, _at);
      expect(m.showupsRemaining, 5);
      expect(m.plannedEndDate, DateTime(2024, 7, 1));
      expect(m.nextScheduledAt, isNull);
    });

    test('accepts optional nextScheduledAt', () {
      final next = DateTime(2024, 6, 3);
      final m = CurrentStateMilestone(
        sortAt: _at,
        showupsRemaining: 3,
        plannedEndDate: DateTime(2024, 7, 1),
        nextScheduledAt: next,
      );
      expect(m.nextScheduledAt, next);
    });
  });

  group('PactConcludedMilestone', () {
    test('exposes required fields; note defaults to null', () {
      final m = PactConcludedMilestone(
        sortAt: _at,
        concludedAt: _at,
        finalStatus: PactStatus.completed,
      );
      expect(m.sortAt, _at);
      expect(m.concludedAt, _at);
      expect(m.finalStatus, PactStatus.completed);
      expect(m.note, isNull);
    });

    test('accepts optional note', () {
      final m = PactConcludedMilestone(
        sortAt: _at,
        concludedAt: _at,
        finalStatus: PactStatus.stopped,
        note: 'Not for me right now',
      );
      expect(m.note, 'Not for me right now');
      expect(m.finalStatus, PactStatus.stopped);
    });
  });
}
