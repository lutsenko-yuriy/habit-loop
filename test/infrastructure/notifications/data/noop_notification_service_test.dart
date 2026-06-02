import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/infrastructure/notifications/data/noop_notification_service.dart';

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

  group('NoopNotificationService', () {
    test('initialize completes without throwing', () async {
      await expectLater(service.initialize(), completes);
    });

    test('requestPermission returns false without throwing', () async {
      final result = await service.requestPermission();
      expect(result, isFalse);
    });

    test('scheduleShowupReminder completes without throwing', () async {
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

    test('scheduleDeadlineNotification completes without throwing', () async {
      await expectLater(
        service.scheduleDeadlineNotification(
          showup: testShowup,
          titleText: 'You missed this one',
          bodyText: "That's okay — show up next time.",
        ),
        completes,
      );
    });

    test('cancelShowupReminder completes without throwing', () async {
      await expectLater(service.cancelShowupReminder('su-1'), completes);
    });

    test('cancelAllRemindersForPact completes without throwing', () async {
      await expectLater(service.cancelAllRemindersForPact('p-1'), completes);
    });

    test('cancelAllRemindersForPact with showupIds completes without throwing', () async {
      await expectLater(
        service.cancelAllRemindersForPact('p-1', showupIds: ['su-1', 'su-2']),
        completes,
      );
    });

    test('getPendingNotifications returns empty list of PendingNotificationInfo', () async {
      final result = await service.getPendingNotifications();
      expect(result, isEmpty);
      expect(result, isA<List<PendingNotificationInfo>>());
    });

    test('getAppLaunchDetails returns null', () async {
      final result = await service.getAppLaunchDetails();
      expect(result, isNull);
    });
  });
}
