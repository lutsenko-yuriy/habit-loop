import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/notifications/data/noop_notification_service.dart';

/// Tests for the WU5 `includeMarkDoneAction` parameter on
/// [NoopNotificationService.scheduleShowupReminder].
void main() {
  late NoopNotificationService service;

  final testShowup = Showup(
    id: 'su-1',
    pactId: 'p-1',
    scheduledAt: DateTime(2026, 6, 1, 8, 0),
    duration: const Duration(minutes: 30),
    status: ShowupStatus.pending,
  );

  final testPact = Pact(
    id: 'p-1',
    habitName: 'Meditate',
    startDate: DateTime(2026, 6, 1),
    endDate: DateTime(2026, 12, 1),
    showupDuration: const Duration(minutes: 30),
    schedule: const DailySchedule(timeOfDay: Duration.zero),
    status: PactStatus.active,
    reminderOffset: const Duration(minutes: 10),
  );

  setUp(() {
    service = NoopNotificationService();
  });

  group('NoopNotificationService — includeMarkDoneAction parameter', () {
    test('scheduleShowupReminder with includeMarkDoneAction: true completes without throwing', () async {
      await expectLater(
        service.scheduleShowupReminder(
          showup: testShowup,
          pact: testPact,
          titleText: 'Time to Meditate',
          bodyText: 'Your showup starts soon.',
          includeMarkDoneAction: true,
        ),
        completes,
      );
    });

    test('scheduleShowupReminder with includeMarkDoneAction: false completes without throwing', () async {
      await expectLater(
        service.scheduleShowupReminder(
          showup: testShowup,
          pact: testPact,
          titleText: 'Time to Meditate',
          bodyText: 'Your showup starts soon.',
          includeMarkDoneAction: false,
        ),
        completes,
      );
    });

    test('scheduleShowupReminder defaults includeMarkDoneAction to true', () async {
      // Should compile and complete without specifying includeMarkDoneAction.
      await expectLater(
        service.scheduleShowupReminder(
          showup: testShowup,
          pact: testPact,
          titleText: 'Time to Meditate',
          bodyText: 'Your showup starts soon.',
        ),
        completes,
      );
    });
  });
}
