import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_constants.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/slices/debug/ui/ios/pending_notifications_page_ios.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../../infrastructure/notifications/fake_notification_service.dart';

Widget _buildTestApp(FakeNotificationService notificationService) {
  return ProviderScope(
    overrides: [
      notificationServiceProvider.overrideWithValue(notificationService),
      showupRepositoryProvider.overrideWithValue(InMemoryShowupRepository()),
      pactRepositoryProvider.overrideWithValue(InMemoryPactRepository()),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: PendingNotificationsPageIos(),
    ),
  );
}

void main() {
  testWidgets('iOS — shows an empty state when nothing is pending', (tester) async {
    await tester.pumpWidget(_buildTestApp(FakeNotificationService()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pending-notifications-empty')), findsOneWidget);
  });

  testWidgets('iOS — shows one row per pending notification with title and body', (tester) async {
    final service = FakeNotificationService()
      ..pendingNotifications = const [
        PendingNotificationInfo(id: 1, title: 'Time to meditate', body: 'Meditate for 10 min', payload: null),
        PendingNotificationInfo(id: 2, title: 'Missed it', body: 'You missed a showup', payload: null),
      ];
    await tester.pumpWidget(_buildTestApp(service));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pending-notification-1')), findsOneWidget);
    expect(find.byKey(const Key('pending-notification-2')), findsOneWidget);
    expect(find.text('Time to meditate'), findsOneWidget);
    expect(find.text('Meditate for 10 min'), findsOneWidget);
  });

  testWidgets('iOS — a row with no resolvable fire time shows a placeholder instead of a date', (tester) async {
    final service = FakeNotificationService()
      ..pendingNotifications = const [
        PendingNotificationInfo(id: 1, title: 'Orphan', body: 'No payload', payload: null),
      ];
    await tester.pumpWidget(_buildTestApp(service));
    await tester.pumpAndSettle();

    expect(find.text('No scheduled time'), findsOneWidget);
  });

  testWidgets('iOS — rows are read-only (no dismiss/action affordances)', (tester) async {
    final service = FakeNotificationService()
      ..pendingNotifications = const [
        PendingNotificationInfo(id: NotificationConstants.deadlineRangeStart, title: 'A', body: 'B', payload: null),
      ];
    await tester.pumpWidget(_buildTestApp(service));
    await tester.pumpAndSettle();

    expect(find.byType(Dismissible), findsNothing);
  });
}
