/// Integration tests for the edit-pact wizard end-to-end flows.
///
/// These tests use real in-memory repositories and real provider wiring so
/// that the full data round-trip (load → edit → save → reload) is exercised.
///
/// Two flows are covered:
///
/// 1. **Edit from pact detail** — [PactDetailScreen] → tap edit icon →
///    [PactEditScreen] → change habit name → swipe to summary → tap
///    "Save Changes" → returns to [PactDetailScreen] showing the new name.
///
/// 2. **Edit from showup detail chain** — [ShowupDetailScreen] → tap "View
///    pact details" → [PactDetailScreen] → tap edit icon → [PactEditScreen]
///    → change habit name → swipe to summary → tap "Save Changes" → returns
///    to [PactDetailScreen] → back to [ShowupDetailScreen] which now shows
///    the updated habit name.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/sync/noop_sync_service.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_service.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_screen.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_edit_view_model.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_screen.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/notifications/fake_notification_service.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _pact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 3, 1),
  endDate: DateTime(2054, 9, 1), // far future so no auto-complete
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
);

final _showup = Showup(
  id: 's1',
  pactId: 'p1',
  // Far future so it never auto-fails on load.
  scheduledAt: DateTime(2099, 1, 1, 8, 0),
  duration: const Duration(minutes: 10),
  status: ShowupStatus.pending,
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds the full provider override list using in-memory repositories.
///
/// All screen types in both flows (pact detail, pact edit, showup detail)
/// compose from the same providers — overriding here covers them all.
List<Override> _overrides({
  required InMemoryPactRepository pactRepo,
  required InMemoryShowupRepository showupRepo,
}) {
  final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
  final statsService = PactStatsService(
    pactRepository: pactRepo,
    showupRepository: showupRepo,
    transactionService: txService,
    syncService: const NoopSyncService(),
  );
  final service = PactService(
    pactRepository: pactRepo,
    showupRepository: showupRepo,
    transactionService: txService,
    syncService: const NoopSyncService(),
    pactStatsService: statsService,
  );
  return [
    pactRepositoryProvider.overrideWithValue(pactRepo),
    showupRepositoryProvider.overrideWithValue(showupRepo),
    pactTransactionServiceProvider.overrideWithValue(txService),
    pactServiceProvider.overrideWithValue(service),
    pactStatsServiceProvider.overrideWithValue(statsService),
    notificationServiceProvider.overrideWithValue(FakeNotificationService()),
    analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
    // Override clock providers so tests are deterministic.
    pactDetailNowProvider.overrideWithValue(DateTime(2026, 5, 1)),
    showupDetailNowProvider.overrideWithValue(DateTime(2026, 5, 1)),
    pactEditTodayProvider.overrideWithValue(DateTime(2026, 5, 1)),
  ];
}

/// Wraps [child] with the localisation and ProviderScope boilerplate needed
/// by all screens under test.
Widget _testApp({required Widget child, required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

/// Swipes the [PageView] in the edit wizard forward by one page.
///
/// Uses a fast fling on the horizontal axis to advance to the next page.
Future<void> _swipeToNextPage(WidgetTester tester) async {
  // Find the edit wizard PageView.
  final pageViewFinder = find.byKey(const Key('pact-edit-pageview-android'));
  expect(pageViewFinder, findsOneWidget);
  await tester.fling(pageViewFinder, const Offset(-400, 0), 800);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Edit pact integration – flow 1: from pact detail', () {
    testWidgets(
      'renaming pact from PactDetailScreen updates the displayed habit name',
      (tester) async {
        // Arrange – seed repos with one active pact (no showups needed here).
        final pactRepo = InMemoryPactRepository([_pact]);
        final showupRepo = InMemoryShowupRepository([]);
        final overrides = _overrides(pactRepo: pactRepo, showupRepo: showupRepo);

        await tester.pumpWidget(
          _testApp(
            overrides: overrides,
            child: const PactDetailScreen(pactId: 'p1'),
          ),
        );
        await tester.pumpAndSettle();

        // The original habit name must be visible after loading.
        expect(find.text('Meditate'), findsAtLeastNWidgets(1));

        // --- Step 1: tap the edit button to open the edit wizard ---
        await tester.tap(find.byKey(const Key('pact-detail-edit-button')));
        await tester.pumpAndSettle();

        // The wizard loaded; the habit-name text field should be visible.
        expect(find.byKey(const Key('pact-creation-habit-name-field')), findsOneWidget);

        // --- Step 2: type a new habit name in the text field ---
        final nameField = find.byKey(const Key('pact-creation-habit-name-field'));
        expect(nameField, findsOneWidget);
        await tester.enterText(nameField, 'Run');
        await tester.pumpAndSettle();

        // --- Step 3: swipe to reminder page, then swipe to summary page ---
        await _swipeToNextPage(tester); // page 0 → 1 (reminder)
        await _swipeToNextPage(tester); // page 1 → 2 (summary)

        // --- Step 4: tap "Save Changes" ---
        final saveButton = find.byKey(const Key('pact-edit-save-button'));
        expect(saveButton, findsOneWidget);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // The wizard popped — we are back on PactDetailScreen.
        // The pact detail screen must reload and show the new name.
        await tester.pumpAndSettle();
        expect(find.text('Run'), findsAtLeastNWidgets(1));
        expect(find.text('Meditate'), findsNothing);
      },
    );
  });

  group('Edit pact integration – flow 2: showup detail → pact detail → edit', () {
    testWidgets(
      'renaming pact via edit wizard updates habit name on ShowupDetailScreen',
      (tester) async {
        // Arrange – seed repos with one active pact and one pending showup.
        final pactRepo = InMemoryPactRepository([_pact]);
        final showupRepo = InMemoryShowupRepository([_showup]);
        final overrides = _overrides(pactRepo: pactRepo, showupRepo: showupRepo);

        // Start on ShowupDetailScreen.
        await tester.pumpWidget(
          _testApp(
            overrides: overrides,
            child: const ShowupDetailScreen(showupId: 's1'),
          ),
        );
        await tester.pumpAndSettle();

        // Verify the original habit name is shown on the showup detail screen.
        expect(find.text('Meditate'), findsAtLeastNWidgets(1));

        // --- Step 1: tap "View pact details" to navigate to PactDetailScreen ---
        final viewPactLink = find.text('View pact details');
        expect(viewPactLink, findsOneWidget);
        await tester.tap(viewPactLink);
        await tester.pumpAndSettle();

        // PactDetailScreen is now on top.
        expect(find.text('Pact Details'), findsOneWidget);
        expect(find.byKey(const Key('pact-detail-edit-button')), findsOneWidget);

        // --- Step 2: tap the edit icon to open the edit wizard ---
        await tester.tap(find.byKey(const Key('pact-detail-edit-button')));
        await tester.pumpAndSettle();

        // The wizard loaded; the habit-name text field should be visible.
        expect(find.byKey(const Key('pact-creation-habit-name-field')), findsOneWidget);

        // --- Step 3: type the new habit name ---
        final nameField = find.byKey(const Key('pact-creation-habit-name-field'));
        expect(nameField, findsOneWidget);
        await tester.enterText(nameField, 'Yoga');
        await tester.pumpAndSettle();

        // --- Step 4: swipe through reminder page to reach summary ---
        await _swipeToNextPage(tester); // page 0 → 1 (reminder)
        await _swipeToNextPage(tester); // page 1 → 2 (summary)

        // --- Step 5: tap "Save Changes" ---
        final saveButton = find.byKey(const Key('pact-edit-save-button'));
        expect(saveButton, findsOneWidget);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Wizard popped → back on PactDetailScreen with the new name.
        expect(find.text('Yoga'), findsAtLeastNWidgets(1));

        // --- Step 6: navigate back to ShowupDetailScreen ---
        final NavigatorState nav = tester.state(find.byType(Navigator).first);
        nav.pop();
        await tester.pumpAndSettle();

        // Showup detail must now show the updated habit name, not the stale one.
        expect(find.text('Yoga'), findsAtLeastNWidgets(1));
        expect(find.text('Meditate'), findsNothing);
      },
    );
  });
}
