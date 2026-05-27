// Integration test for the debug Remote Config override layer.
//
// Verifies end-to-end that:
// - SharedPreferencesRemoteConfigOverrideStore persists and serves overrides
// - OverridableRemoteConfigService reads from the store before the inner service
// - remoteConfigServiceProvider and remoteConfigOverrideStoreProvider are wired
//   together correctly via AppContainer.overrides
//
// Run with: flutter test integration_test/remote_config_overrides_flow_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_container.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/infrastructure/remote_config/data/noop_remote_config_service.dart';
import 'package:habit_loop/infrastructure/remote_config/data/overridable_remote_config_service.dart';
import 'package:habit_loop/infrastructure/remote_config/data/shared_preferences_remote_config_override_store.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Remote Config override layer — service integration', () {
    late InMemoryPactRepository pactRepo;
    late InMemoryShowupRepository showupRepo;
    late InMemoryPactTransactionService txService;

    setUp(() {
      pactRepo = InMemoryPactRepository();
      showupRepo = InMemoryShowupRepository();
      txService = InMemoryPactTransactionService(pactRepo, showupRepo);
    });

    test('remoteConfigOverrideStoreProvider defaults to noop — getOverride returns null', () async {
      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      final store = container.read(remoteConfigOverrideStoreProvider);
      expect(store.getOverride('max_active_pacts'), isNull);
      expect(store.getAllOverrides(), isEmpty);
    });

    test('remoteConfigServiceProvider returns in-code defaults when no overrides are set', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesRemoteConfigOverrideStore(prefs);
      final service = OverridableRemoteConfigService(
        inner: NoopRemoteConfigService(),
        store: store,
      );

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        remoteConfigService: service,
        remoteConfigOverrideStore: store,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(
        container.read(remoteConfigServiceProvider).getInt('max_active_pacts'),
        RemoteConfigDefaults.maxActivePacts,
      );
      expect(
        container.read(remoteConfigServiceProvider).getString('notification_text_variant'),
        RemoteConfigDefaults.notificationTextVariant,
      );
    });

    test('override flows from store through service provider to callers', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesRemoteConfigOverrideStore(prefs);
      await store.setOverride('max_active_pacts', '10');

      final service = OverridableRemoteConfigService(
        inner: NoopRemoteConfigService(),
        store: store,
      );

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        remoteConfigService: service,
        remoteConfigOverrideStore: store,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(
        container.read(remoteConfigServiceProvider).getInt('max_active_pacts'),
        10,
      );
    });

    test('override store writes are reflected immediately in subsequent service reads', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesRemoteConfigOverrideStore(prefs);
      final service = OverridableRemoteConfigService(
        inner: NoopRemoteConfigService(),
        store: store,
      );

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        remoteConfigService: service,
        remoteConfigOverrideStore: store,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      // Before override: in-code default.
      expect(
        container.read(remoteConfigServiceProvider).getInt('max_active_pacts'),
        RemoteConfigDefaults.maxActivePacts,
      );

      // Write override via the store provider (same instance the service holds).
      await container.read(remoteConfigOverrideStoreProvider).setOverride('max_active_pacts', '7');

      // After override: new value served without app restart.
      expect(
        container.read(remoteConfigServiceProvider).getInt('max_active_pacts'),
        7,
      );
    });

    test('clearing an override reverts to the inner service default', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesRemoteConfigOverrideStore(prefs);
      await store.setOverride('max_active_pacts', '10');

      final service = OverridableRemoteConfigService(
        inner: NoopRemoteConfigService(),
        store: store,
      );

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        remoteConfigService: service,
        remoteConfigOverrideStore: store,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      // Override is active.
      expect(container.read(remoteConfigServiceProvider).getInt('max_active_pacts'), 10);

      // Clear it via the store provider.
      await container.read(remoteConfigOverrideStoreProvider).clearOverride('max_active_pacts');

      // Reverts to in-code default.
      expect(
        container.read(remoteConfigServiceProvider).getInt('max_active_pacts'),
        RemoteConfigDefaults.maxActivePacts,
      );
    });

    test('multiple key types can be overridden independently', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesRemoteConfigOverrideStore(prefs);
      await store.setOverride('max_active_pacts', '5');
      await store.setOverride('notification_text_variant', 'deadline');

      final service = OverridableRemoteConfigService(
        inner: NoopRemoteConfigService(),
        store: store,
      );

      final overrides = await AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        remoteConfigService: service,
        remoteConfigOverrideStore: store,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(remoteConfigServiceProvider).getInt('max_active_pacts'), 5);
      expect(container.read(remoteConfigServiceProvider).getString('notification_text_variant'), 'deadline');
    });
  });
}
