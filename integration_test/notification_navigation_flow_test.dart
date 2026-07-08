// Integration test: dashboard refreshes after marking showup done/failed via
// a notification tap (notification navigation path).
//
// Run on host:   flutter test integration_test/notification_navigation_flow_test.dart
// Run on device: flutter test integration_test/notification_navigation_flow_test.dart -d <device>
import 'dart:async' show unawaited;

import 'package:flutter/material.dart' show Navigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/navigation/notification_navigator.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_refresh_signal.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

// Fixed clock: 5 minutes before the 08:00 showup window, so auto-fail
// never triggers during the test.
final _testNow = DateTime(2099, 6, 15, 7, 55);
final _testToday = DateTime(2099, 6, 15);

const _pactId = 'notif-nav-test-pact-1';
const _showupId = '${_pactId}_20990615T080000_0';

final _pact = buildPact(
  id: _pactId,
  habitName: 'Morning Jog',
  startDate: _testToday,
  showupDuration: const Duration(minutes: 15),
);

final _showup = buildShowup(
  id: _showupId,
  pactId: _pactId,
  scheduledAt: DateTime(2099, 6, 15, 8, 0),
  duration: const Duration(minutes: 15),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Notification navigation flow', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
      'notification_mark_done_updates_dashboard: dashboard reflects done status after marking showup done via notification tap',
      (tester) async {
        h = await AppHarness.create(
          tester,
          extraOverrides: [
            todayProvider.overrideWithValue(_testNow),
            showupDetailNowProvider.overrideWithValue(_testNow),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_pact);
            await h.showupRepo.saveShowups([_showup]);
          },
        );

        final strings = l10n(tester);

        // ── 1. Dashboard shows today's showup as pending ──────────────────
        await waitFor(tester, find.text('Morning Jog'));
        expect(find.textContaining(strings.showupPending), findsOneWidget);

        // ── 2. Simulate notification tap: push ShowupDetailScreen directly
        //       using NotificationNavigator (the production code path).
        //       onReturn increments dashboardRefreshSignalProvider, mirroring
        //       what main.dart does via _container. ─────────────────────────
        final container = ProviderScope.containerOf(tester.element(find.byType(Navigator).first));
        unawaited(
          NotificationNavigator.navigateToShowup(
            navigatorKey: h.navigatorKey,
            showupId: _showupId,
            onReturn: () => container.read(dashboardRefreshSignalProvider.notifier).state++,
          ),
        );
        await tester.pump();

        // ── 3. Mark as done on the showup detail screen ───────────────────
        await waitFor(tester, find.text(strings.markDone));
        await tester.tap(find.text(strings.markDone));
        await tester.pumpAndSettle();
        expect(find.text(strings.showupDone), findsOneWidget);

        // ── 4. Navigate back to dashboard ─────────────────────────────────
        await tester.pageBack();
        await waitFor(tester, find.text('Morning Jog'));
        // Allow the dashboardRefreshSignalProvider listener to trigger load()
        // and the resulting state rebuild to propagate.
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // ── 5. Dashboard tile now shows done status ────────────────────────
        expect(find.textContaining(strings.showupDone), findsOneWidget);
        expect(find.textContaining(strings.showupPending), findsNothing);
      },
    );

    testWidgets(
      'notification_mark_failed_updates_dashboard: dashboard reflects failed status after marking showup failed via notification tap',
      (tester) async {
        h = await AppHarness.create(
          tester,
          extraOverrides: [
            todayProvider.overrideWithValue(_testNow),
            showupDetailNowProvider.overrideWithValue(_testNow),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_pact);
            await h.showupRepo.saveShowups([_showup]);
          },
        );

        final strings = l10n(tester);

        await waitFor(tester, find.text('Morning Jog'));
        expect(find.textContaining(strings.showupPending), findsOneWidget);

        final container = ProviderScope.containerOf(tester.element(find.byType(Navigator).first));
        unawaited(
          NotificationNavigator.navigateToShowup(
            navigatorKey: h.navigatorKey,
            showupId: _showupId,
            onReturn: () => container.read(dashboardRefreshSignalProvider.notifier).state++,
          ),
        );
        await tester.pump();

        await waitFor(tester, find.text(strings.markFailed));
        await tester.tap(find.text(strings.markFailed));
        await tester.pumpAndSettle();
        expect(find.text(strings.showupFailed), findsOneWidget);

        await tester.pageBack();
        await waitFor(tester, find.text('Morning Jog'));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.textContaining(strings.showupFailed), findsOneWidget);
        expect(find.textContaining(strings.showupPending), findsNothing);
      },
    );
  });
}
