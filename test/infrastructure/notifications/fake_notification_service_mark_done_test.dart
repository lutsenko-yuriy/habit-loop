import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';

import 'fake_notification_service.dart';

/// Tests for WU5 additions to [FakeNotificationService]:
/// - `includeMarkDoneAction` parameter recording
/// - `markedDoneFromNotificationIds` list
void main() {
  late FakeNotificationService fake;

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
    fake = FakeNotificationService();
  });

  group('FakeNotificationService — includeMarkDoneAction recording', () {
    test('scheduleShowupReminder records includeMarkDoneAction: true', () async {
      await fake.scheduleShowupReminder(
        showup: testShowup,
        pact: testPact,
        titleText: 'Time to Meditate',
        bodyText: 'Your showup starts soon.',
        includeMarkDoneAction: true,
      );

      expect(fake.scheduledReminders, hasLength(1));
      expect(fake.scheduledReminders.first.includeMarkDoneAction, isTrue);
    });

    test('scheduleShowupReminder records includeMarkDoneAction: false', () async {
      await fake.scheduleShowupReminder(
        showup: testShowup,
        pact: testPact,
        titleText: 'Time to Meditate',
        bodyText: 'Your showup starts soon.',
        includeMarkDoneAction: false,
      );

      expect(fake.scheduledReminders, hasLength(1));
      expect(fake.scheduledReminders.first.includeMarkDoneAction, isFalse);
    });

    test('scheduleShowupReminder defaults includeMarkDoneAction to true', () async {
      await fake.scheduleShowupReminder(
        showup: testShowup,
        pact: testPact,
        titleText: 'Time to Meditate',
        bodyText: 'Your showup starts soon.',
      );

      expect(fake.scheduledReminders, hasLength(1));
      expect(fake.scheduledReminders.first.includeMarkDoneAction, isTrue);
    });

    test('markedDoneFromNotificationIds starts empty', () {
      expect(fake.markedDoneFromNotificationIds, isEmpty);
    });

    test('markedDoneFromNotificationIds is a List<String>', () {
      expect(fake.markedDoneFromNotificationIds, isA<List<String>>());
    });

    test('reset clears markedDoneFromNotificationIds', () {
      fake.markedDoneFromNotificationIds.add('su-1');
      fake.reset();
      expect(fake.markedDoneFromNotificationIds, isEmpty);
    });

    test('getPendingNotifications returns correct type', () async {
      final result = await fake.getPendingNotifications();
      expect(result, isA<List<PendingNotificationInfo>>());
    });
  });
}
