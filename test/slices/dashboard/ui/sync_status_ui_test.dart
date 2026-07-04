import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/android/dashboard_page_android.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_state.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_ui_state.dart';
import 'package:habit_loop/slices/dashboard/ui/ios/dashboard_page_ios.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';

// ---------------------------------------------------------------------------
// Fake SyncStatusViewModel — returns a fixed state, actions are no-ops
// ---------------------------------------------------------------------------

class _FakeSyncStatusViewModel extends AutoDisposeNotifier<SyncUiState> implements SyncStatusViewModel {
  _FakeSyncStatusViewModel(this._fixedState);
  final SyncUiState _fixedState;

  @override
  SyncUiState build() => _fixedState;

  @override
  Future<void> triggerManualSync() async {}

  @override
  Future<void> linkWithGoogle() async {}

  @override
  Future<int> fullSync() async => 0;

  @override
  Future<void> signOut() async {}
}

// Fake pact list VM from existing tests
class _EmptyPactListViewModel extends PactListViewModel {
  @override
  PactListState build() => const PactListState();
}

// ---------------------------------------------------------------------------
// Test app builders
// ---------------------------------------------------------------------------

Widget _buildIosApp({
  SyncUiState syncState = SyncUiState.synced,
  FakeAnalyticsService? analytics,
}) {
  return ProviderScope(
    overrides: [
      pactListViewModelProvider.overrideWith(_EmptyPactListViewModel.new),
      syncStatusViewModelProvider.overrideWith(() => _FakeSyncStatusViewModel(syncState)),
      if (analytics != null) analyticsServiceProvider.overrideWithValue(analytics),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(bottom: 34),
          viewPadding: EdgeInsets.only(bottom: 34),
        ),
        child: DashboardPageIos(
          state: const DashboardState(isLoading: false),
          hasPacts: true,
          showCarousel: false,
          onDaySelected: (_) {},
          onCreatePact: () async {},
          onShowupTapped: (_) async {},
          onAbout: () async {},
        ),
      ),
    ),
  );
}

Widget _buildAndroidApp({
  SyncUiState syncState = SyncUiState.synced,
  FakeAnalyticsService? analytics,
}) {
  return ProviderScope(
    overrides: [
      pactListViewModelProvider.overrideWith(_EmptyPactListViewModel.new),
      syncStatusViewModelProvider.overrideWith(() => _FakeSyncStatusViewModel(syncState)),
      if (analytics != null) analyticsServiceProvider.overrideWithValue(analytics),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: DashboardPageAndroid(
        state: const DashboardState(isLoading: false),
        hasPacts: true,
        showCarousel: false,
        onDaySelected: (_) {},
        onCreatePact: () async {},
        onShowupTapped: (_) async {},
        onAbout: () async {},
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests — iOS
// ---------------------------------------------------------------------------

void main() {
  group('iOS sync status button', () {
    testWidgets('button present in nav bar', (tester) async {
      await tester.pumpWidget(_buildIosApp());
      await tester.pump();

      expect(find.byKey(const Key('sync-status-button')), findsOneWidget);
    });

    testWidgets('button shows cloud-done icon when synced', (tester) async {
      await tester.pumpWidget(_buildIosApp(syncState: SyncUiState.synced));
      await tester.pump();

      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    });

    testWidgets('button shows wifi-off icon when noInternet', (tester) async {
      await tester.pumpWidget(_buildIosApp(syncState: SyncUiState.noInternet));
      await tester.pump();

      expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);
    });

    testWidgets('tapping button shows Cupertino sync dialog', (tester) async {
      await tester.pumpWidget(_buildIosApp(syncState: SyncUiState.synced));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sync-status-button')));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('Sync status'), findsOneWidget);
      expect(find.text('Up to date'), findsOneWidget);
    });

    testWidgets('iOS dialog shows Sign in with Google for notLinked state', (tester) async {
      await tester.pumpWidget(_buildIosApp(syncState: SyncUiState.notLinked));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sync-status-button')));
      await tester.pumpAndSettle();

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('iOS dialog shows Sync now for suspended state', (tester) async {
      await tester.pumpWidget(_buildIosApp(syncState: SyncUiState.suspended));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sync-status-button')));
      await tester.pumpAndSettle();

      expect(find.text('Sync now'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('iOS dialog shows Sync now for degraded state', (tester) async {
      await tester.pumpWidget(_buildIosApp(syncState: SyncUiState.degraded));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sync-status-button')));
      await tester.pumpAndSettle();

      expect(find.text('Sync now'), findsOneWidget);
    });

    testWidgets('iOS dialog shows only Not now for noInternet state', (tester) async {
      await tester.pumpWidget(_buildIosApp(syncState: SyncUiState.noInternet));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sync-status-button')));
      await tester.pumpAndSettle();

      expect(find.text('Not now'), findsOneWidget);
      expect(find.text('Sync now'), findsNothing);
      expect(find.text('Sign in with Google'), findsNothing);
    });

    testWidgets('iOS dialog dismisses on Not now tap', (tester) async {
      await tester.pumpWidget(_buildIosApp(syncState: SyncUiState.noInternet));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sync-status-button')));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    testWidgets('iOS dialog dismisses on Sync now tap', (tester) async {
      await tester.pumpWidget(_buildIosApp(syncState: SyncUiState.suspended));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sync-status-button')));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);

      await tester.tap(find.text('Sync now'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Tests — Android
  // -------------------------------------------------------------------------

  group('Android sync status button', () {
    testWidgets('button present in app bar actions', (tester) async {
      await tester.pumpWidget(_buildAndroidApp());
      await tester.pump();

      expect(find.byKey(const Key('sync-status-button')), findsOneWidget);
    });

    testWidgets('button shows cloud-done icon when synced', (tester) async {
      await tester.pumpWidget(_buildAndroidApp(syncState: SyncUiState.synced));
      await tester.pump();

      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    });

    testWidgets('button shows sync_problem icon when degraded', (tester) async {
      await tester.pumpWidget(_buildAndroidApp(syncState: SyncUiState.degraded));
      await tester.pump();

      expect(find.byIcon(Icons.sync_problem_outlined), findsOneWidget);
    });

    testWidgets('tapping button shows Material sync dialog', (tester) async {
      await tester.pumpWidget(_buildAndroidApp(syncState: SyncUiState.synced));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sync-status-button')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Sync status'), findsOneWidget);
      expect(find.text('Up to date'), findsOneWidget);
    });

    testWidgets('Android dialog shows Sign in with Google for notLinked state', (tester) async {
      await tester.pumpWidget(_buildAndroidApp(syncState: SyncUiState.notLinked));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sync-status-button')));
      await tester.pumpAndSettle();

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('Android dialog shows Sync now for suspended state', (tester) async {
      await tester.pumpWidget(_buildAndroidApp(syncState: SyncUiState.suspended));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sync-status-button')));
      await tester.pumpAndSettle();

      expect(find.text('Sync now'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('Android dialog dismisses on Not now tap', (tester) async {
      await tester.pumpWidget(_buildAndroidApp(syncState: SyncUiState.suspended));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sync-status-button')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Android dialog dismisses on Sync now tap', (tester) async {
      await tester.pumpWidget(_buildAndroidApp(syncState: SyncUiState.suspended));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sync-status-button')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Sync now'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
