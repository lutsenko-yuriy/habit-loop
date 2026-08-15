import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_constants.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/slices/debug/ui/generic/pending_notification_row.dart';
import 'package:habit_loop/slices/debug/ui/generic/pending_notifications_view_model.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../../infrastructure/notifications/fake_notification_service.dart';

final _pact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2026, 6, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
  reminderOffset: const Duration(minutes: 15),
);

final _showup = Showup(
  id: 's1',
  pactId: 'p1',
  scheduledAt: DateTime(2026, 3, 1, 8),
  duration: const Duration(minutes: 10),
  status: ShowupStatus.pending,
);

String _payload({String? showupId, String? pactId}) =>
    jsonEncode({if (showupId != null) 'showupId': showupId, if (pactId != null) 'pactId': pactId});

void main() {
  late FakeNotificationService notificationService;
  late InMemoryShowupRepository showupRepo;
  late InMemoryPactRepository pactRepo;
  late ProviderContainer container;

  setUp(() {
    notificationService = FakeNotificationService();
    showupRepo = InMemoryShowupRepository();
    pactRepo = InMemoryPactRepository([_pact]);
    container = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactRepositoryProvider.overrideWithValue(pactRepo),
      ],
    );
    addTearDown(container.dispose);
  });

  test('returns an empty list when nothing is pending', () async {
    final result = await container.read(pendingNotificationsViewModelProvider.future);
    expect(result, isEmpty);
  });

  test('resolves a reminder notification\'s fire time as scheduledAt - reminderOffset', () async {
    await showupRepo.saveShowup(_showup);
    notificationService.pendingNotifications = [
      PendingNotificationInfo(
        id: NotificationConstants.reminderNotificationId('s1'),
        title: 'Time to meditate',
        body: 'Meditate for 10 min',
        payload: _payload(showupId: 's1', pactId: 'p1'),
      ),
    ];

    final result = await container.read(pendingNotificationsViewModelProvider.future);

    expect(result, hasLength(1));
    expect(result.first.title, 'Time to meditate');
    expect(result.first.fireAt, DateTime(2026, 3, 1, 7, 45));
  });

  test('resolves a deadline notification\'s fire time as scheduledAt + duration', () async {
    await showupRepo.saveShowup(_showup);
    notificationService.pendingNotifications = [
      PendingNotificationInfo(
        id: NotificationConstants.deadlineNotificationId('s1'),
        title: 'Missed it',
        body: 'You missed a showup',
        payload: _payload(showupId: 's1', pactId: 'p1'),
      ),
    ];

    final result = await container.read(pendingNotificationsViewModelProvider.future);

    expect(result.first.fireAt, DateTime(2026, 3, 1, 8, 10));
  });

  test('leaves fireAt null when the payload is missing', () async {
    notificationService.pendingNotifications = [
      const PendingNotificationInfo(id: 1, title: 'Orphan', body: 'No payload', payload: null),
    ];

    final result = await container.read(pendingNotificationsViewModelProvider.future);

    expect(result.first.title, 'Orphan');
    expect(result.first.fireAt, isNull);
    expect(result.first.unresolvedReason, UnresolvedFireTimeReason.missingPayload);
  });

  test('leaves fireAt null when the payload is malformed JSON', () async {
    notificationService.pendingNotifications = [
      const PendingNotificationInfo(id: 1, title: 'Bad', body: 'Bad payload', payload: 'not json'),
    ];

    final result = await container.read(pendingNotificationsViewModelProvider.future);

    expect(result.first.fireAt, isNull);
    expect(result.first.unresolvedReason, UnresolvedFireTimeReason.malformedPayload);
  });

  test('leaves fireAt null when the referenced showup no longer exists', () async {
    notificationService.pendingNotifications = [
      PendingNotificationInfo(
        id: NotificationConstants.reminderNotificationId('missing'),
        title: 'Stale',
        body: 'Showup deleted',
        payload: _payload(showupId: 'missing', pactId: 'p1'),
      ),
    ];

    final result = await container.read(pendingNotificationsViewModelProvider.future);

    expect(result.first.fireAt, isNull);
    expect(result.first.unresolvedReason, UnresolvedFireTimeReason.showupNotFound);
  });

  test('leaves fireAt null when the referenced pact no longer exists', () async {
    await showupRepo.saveShowup(Showup(
      id: 's-orphan-pact',
      pactId: 'missing-pact',
      scheduledAt: DateTime(2026, 3, 1, 8),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.pending,
    ));
    notificationService.pendingNotifications = [
      PendingNotificationInfo(
        id: NotificationConstants.reminderNotificationId('s-orphan-pact'),
        title: 'Orphan pact',
        body: 'b',
        payload: _payload(showupId: 's-orphan-pact', pactId: 'missing-pact'),
      ),
    ];

    final result = await container.read(pendingNotificationsViewModelProvider.future);

    expect(result.first.fireAt, isNull);
    expect(result.first.unresolvedReason, UnresolvedFireTimeReason.pactNotFound);
  });

  test('leaves fireAt null for a reminder whose pact no longer has a reminderOffset', () async {
    await pactRepo.updatePact(_pact.copyWith(clearReminderOffset: true));
    await showupRepo.saveShowup(_showup);
    notificationService.pendingNotifications = [
      PendingNotificationInfo(
        id: NotificationConstants.reminderNotificationId('s1'),
        title: 'Time to meditate',
        body: 'Meditate for 10 min',
        payload: _payload(showupId: 's1', pactId: 'p1'),
      ),
    ];

    final result = await container.read(pendingNotificationsViewModelProvider.future);

    expect(result.first.fireAt, isNull);
    expect(result.first.unresolvedReason, UnresolvedFireTimeReason.noReminderOffset);
  });

  test('sorts rows soonest-first, with unresolved fire times last', () async {
    final earlier = _showup;
    final later = Showup(
      id: 's2',
      pactId: 'p1',
      scheduledAt: DateTime(2026, 3, 2, 8),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.pending,
    );
    await showupRepo.saveShowup(earlier);
    await showupRepo.saveShowup(later);
    notificationService.pendingNotifications = [
      PendingNotificationInfo(
        id: NotificationConstants.reminderNotificationId('s2'),
        title: 'Later',
        body: 'b',
        payload: _payload(showupId: 's2', pactId: 'p1'),
      ),
      const PendingNotificationInfo(id: 999, title: 'Unresolved', body: 'b', payload: null),
      PendingNotificationInfo(
        id: NotificationConstants.reminderNotificationId('s1'),
        title: 'Earlier',
        body: 'b',
        payload: _payload(showupId: 's1', pactId: 'p1'),
      ),
    ];

    final result = await container.read(pendingNotificationsViewModelProvider.future);

    expect(result.map((r) => r.title), ['Earlier', 'Later', 'Unresolved']);
  });

  test('breaks ties on id for reproducible ordering (equal fire times, and among unresolved rows)', () async {
    // Reminder and deadline for the same showup fire at different times, so use
    // two distinct showups with identical scheduledAt to force a real fireAt tie.
    await showupRepo.saveShowup(_showup);
    await showupRepo.saveShowup(Showup(
      id: 's-same-time',
      pactId: 'p1',
      scheduledAt: _showup.scheduledAt,
      duration: const Duration(minutes: 10),
      status: ShowupStatus.pending,
    ));
    final idA = NotificationConstants.reminderNotificationId('s1');
    final idB = NotificationConstants.reminderNotificationId('s-same-time');
    final firstId = idA < idB ? idA : idB;
    final firstShowupId = idA < idB ? 's1' : 's-same-time';
    final secondShowupId = idA < idB ? 's-same-time' : 's1';

    notificationService.pendingNotifications = [
      PendingNotificationInfo(
        id: idA < idB ? idB : idA,
        title: 'B',
        body: 'b',
        payload: _payload(showupId: secondShowupId, pactId: 'p1'),
      ),
      PendingNotificationInfo(
          id: firstId, title: 'A', body: 'b', payload: _payload(showupId: firstShowupId, pactId: 'p1')),
      const PendingNotificationInfo(id: 20, title: 'Unresolved 20', body: 'b', payload: null),
      const PendingNotificationInfo(id: 10, title: 'Unresolved 10', body: 'b', payload: null),
    ];

    final result = await container.read(pendingNotificationsViewModelProvider.future);

    expect(result.map((r) => r.title), ['A', 'B', 'Unresolved 10', 'Unresolved 20']);
  });
}
