import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/auth/data/noop_auth_service.dart';
import 'package:habit_loop/infrastructure/device/data/noop_device_id_service.dart';
import 'package:habit_loop/infrastructure/firestore/data/fake_firestore_client.dart';
import 'package:habit_loop/infrastructure/firestore/data/fault_injecting_firestore_client.dart';
import 'package:habit_loop/infrastructure/firestore/data/noop_firestore_client.dart';
import 'package:habit_loop/infrastructure/injections/app_container.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/locale/data/noop_locale_preference_service.dart';
import 'package:habit_loop/infrastructure/notifications/data/noop_notification_service.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/infrastructure/remote_config/data/noop_remote_config_override_store.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/pact/data/noop_pact_sync_repository.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/slices/showup/data/noop_showup_sync_repository.dart';

import '../locale/fake_locale_preference_service.dart';
import '../onboarding/fake_onboarding_preference_service.dart';
import '../remote_config/fake_remote_config_service.dart';

void main() {
  group('AppContainer.overrides', () {
    late InMemoryPactRepository pactRepo;
    late InMemoryShowupRepository showupRepo;
    late InMemoryPactTransactionService txService;

    setUp(() {
      pactRepo = InMemoryPactRepository();
      showupRepo = InMemoryShowupRepository();
      txService = InMemoryPactTransactionService(pactRepo, showupRepo);
    });

    test('returns a non-empty list of overrides', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );

      // Minimum overrides: pactRepo, showupRepo, txService (3 required).
      // Slice-local aliases have been removed — only canonical providers are wired.
      expect(overrides, hasLength(greaterThanOrEqualTo(3)));
    });

    test('container with overrides resolves pactRepositoryProvider without throwing', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(pactRepositoryProvider), returnsNormally);
    });

    test('container with overrides resolves showupRepositoryProvider without throwing', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(showupRepositoryProvider), returnsNormally);
    });

    test('container with overrides resolves pactTransactionServiceProvider without throwing', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(pactTransactionServiceProvider), returnsNormally);
    });

    test('container with overrides resolves pactServiceProvider without throwing', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(pactServiceProvider), returnsNormally);
    });

    test('container with overrides resolves pactStatsServiceProvider without throwing', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(pactStatsServiceProvider), returnsNormally);
    });

    test('optional services are omitted when null — providers fall back to noop defaults', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        // analyticsService, crashlyticsService, logService, remoteConfigService all null
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      // These should resolve to their noop defaults without throwing.
      expect(() => container.read(analyticsServiceProvider), returnsNormally);
      expect(() => container.read(crashlyticsServiceProvider), returnsNormally);
      expect(() => container.read(logServiceProvider), returnsNormally);
      expect(() => container.read(remoteConfigServiceProvider), returnsNormally);
      expect(() => container.read(notificationServiceProvider), returnsNormally);
    });

    test('notificationServiceProvider resolves without throwing when not provided', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(notificationServiceProvider), returnsNormally);
    });

    test('notificationServiceProvider override is included when provided', () async {
      final notificationService = NoopNotificationService();

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        notificationService: notificationService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(notificationServiceProvider), same(notificationService));
    });

    test('container with overrides resolves reminderSchedulingServiceProvider without throwing', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(reminderSchedulingServiceProvider), returnsNormally);
    });

    test('localePreferenceServiceProvider resolves to noop default when not provided', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(localePreferenceServiceProvider), returnsNormally);
    });

    test('localeOverrideProvider resolves to null when no locale has been saved', () async {
      // NoopLocalePreferenceService always returns null from getSavedLocale().
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        localePreferenceService: NoopLocalePreferenceService(),
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(localeOverrideProvider), isNull);
    });

    test('localeOverrideProvider resolves to null when localePreferenceService is not provided', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(localeOverrideProvider), isNull);
    });

    test('localePreferenceService override is included when provided', () async {
      final localeService = NoopLocalePreferenceService();

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        localePreferenceService: localeService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(localePreferenceServiceProvider), same(localeService));
    });

    test('localeOverrideProvider reflects saved locale fetched internally from service', () async {
      // Pre-populate the fake service with a saved locale so the internal
      // getSavedLocale() call inside overrides() returns it.
      final localeService = FakeLocalePreferenceService();
      await localeService.saveLocale(const Locale('fr'));

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        localePreferenceService: localeService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(localePreferenceServiceProvider), same(localeService));
      expect(container.read(localeOverrideProvider), equals(const Locale('fr')));
    });

    test('localeOverrideProvider reflects German locale when pre-populated in service', () async {
      final localeService = FakeLocalePreferenceService();
      await localeService.saveLocale(const Locale('de'));

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        localePreferenceService: localeService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(localeOverrideProvider), equals(const Locale('de')));
    });

    test('authServiceProvider resolves to noop default when not provided', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(authServiceProvider), returnsNormally);
    });

    test('deviceIdServiceProvider resolves to noop default when not provided', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(deviceIdServiceProvider), returnsNormally);
    });

    test('authServiceProvider override is included when provided', () async {
      final authService = NoopAuthService();

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        authService: authService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(authServiceProvider), same(authService));
    });

    test('deviceIdServiceProvider override is included when provided', () async {
      final deviceIdService = NoopDeviceIdService();

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        deviceIdService: deviceIdService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(deviceIdServiceProvider), same(deviceIdService));
    });

    test('pactSyncRepositoryProvider resolves to noop default when not provided', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(pactSyncRepositoryProvider), returnsNormally);
    });

    test('showupSyncRepositoryProvider resolves to noop default when not provided', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(showupSyncRepositoryProvider), returnsNormally);
    });

    test('pactSyncRepositoryProvider override is included when provided', () async {
      const syncRepo = NoopPactSyncRepository();

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        pactSyncRepository: syncRepo,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(pactSyncRepositoryProvider), same(syncRepo));
    });

    test('showupSyncRepositoryProvider override is included when provided', () async {
      const syncRepo = NoopShowupSyncRepository();

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        showupSyncRepository: syncRepo,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(showupSyncRepositoryProvider), same(syncRepo));
    });

    test('firestoreClientProvider resolves to noop default when not provided', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(firestoreClientProvider), returnsNormally);
    });

    test('firestoreClientProvider override is included when provided', () async {
      final firestoreClient = NoopFirestoreClient();

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        firestoreClient: firestoreClient,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(firestoreClientProvider), same(firestoreClient));
    });

    test('onboardingPreferenceServiceProvider resolves to noop default when not provided', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(onboardingPreferenceServiceProvider), returnsNormally);
    });

    test('onboardingPreferenceServiceProvider override is included when provided', () async {
      final onboardingService = FakeOnboardingPreferenceService(initialValue: true);

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        onboardingPreferenceService: onboardingService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(onboardingPreferenceServiceProvider), same(onboardingService));
    });

    test('syncCircuitBreakerProvider resolves without throwing', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(syncCircuitBreakerProvider), returnsNormally);
    });

    test('syncServiceProvider resolves without throwing', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(syncServiceProvider), returnsNormally);
    });

    test('remoteConfigOverrideStoreProvider resolves to noop default when not provided', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(remoteConfigOverrideStoreProvider), returnsNormally);
    });

    test('remoteConfigOverrideStoreProvider override is included when provided', () async {
      const store = NoopRemoteConfigOverrideStore();

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        remoteConfigOverrideStore: store,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(remoteConfigOverrideStoreProvider), same(store));
    });

    test('FaultInjectingFirestoreClient with absent connectivity throws on reads via firestoreClientProvider',
        () async {
      final inner = FakeFirestoreClient()
        ..seed(const FakeFirestoreSeedData(
          pacts: {
            'user-1': {
              'pact-1': <String, dynamic>{'id': 'pact-1', 'habit_name': 'Meditate'}
            },
          },
        ));
      final faultClient = FaultInjectingFirestoreClient(
        inner: inner,
        rc: FakeRemoteConfigService(overrides: {'debug_connectivity_state': 'absent'}),
      );

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        firestoreClient: faultClient,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      final client = container.read(firestoreClientProvider);
      await expectLater(() => client.getPacts('user-1'), throwsException);
    });

    test('FaultInjectingFirestoreClient with perfect connectivity passes through to FakeFirestoreClient', () async {
      final inner = FakeFirestoreClient()
        ..seed(const FakeFirestoreSeedData(
          pacts: {
            'user-1': {
              'pact-1': <String, dynamic>{'id': 'pact-1', 'habit_name': 'Meditate'}
            },
          },
        ));
      final faultClient = FaultInjectingFirestoreClient(
        inner: inner,
        rc: FakeRemoteConfigService(overrides: {'debug_connectivity_state': 'perfect'}),
      );

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        firestoreClient: faultClient,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      final client = container.read(firestoreClientProvider);
      final pacts = await client.getPacts('user-1');
      expect(pacts, hasLength(1));
      expect(pacts.first['habit_name'], equals('Meditate'));
    });

    test('debugBackendAtStartupProvider resolves to default when not provided', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      // Falls back to RemoteConfigDefaults.debugBackend ('real').
      expect(container.read(debugBackendAtStartupProvider), equals(RemoteConfigDefaults.debugBackend));
    });

    test('debugBackendAtStartupProvider override is included when provided', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        debugBackendAtStartup: 'local',
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(debugBackendAtStartupProvider), equals('local'));
    });

    test('override count grows by 2 when both authService and deviceIdService are provided', () async {
      final baseOverrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final withAuthOverrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        authService: NoopAuthService(),
        deviceIdService: NoopDeviceIdService(),
      );

      expect(withAuthOverrides.length, equals(baseOverrides.length + 2));
    });
  });
}
