import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_container.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/locale/data/noop_locale_preference_service.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../locale/fake_locale_preference_service.dart';

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
  });
}
