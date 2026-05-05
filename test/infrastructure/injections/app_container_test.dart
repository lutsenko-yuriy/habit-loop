import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_container.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

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

    test('returns a non-empty list of overrides', () {
      final overrides = AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );

      // Minimum overrides: pactRepo, showupRepo, txService,
      // plus per-view-model providers (4 slice-local ones).
      expect(overrides, hasLength(greaterThanOrEqualTo(7)));
    });

    test('container with overrides resolves pactRepositoryProvider without throwing', () {
      final overrides = AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(pactRepositoryProvider), returnsNormally);
    });

    test('container with overrides resolves showupRepositoryProvider without throwing', () {
      final overrides = AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(showupRepositoryProvider), returnsNormally);
    });

    test('container with overrides resolves pactTransactionServiceProvider without throwing', () {
      final overrides = AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(pactTransactionServiceProvider), returnsNormally);
    });

    test('container with overrides resolves pactServiceProvider without throwing', () {
      final overrides = AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(pactServiceProvider), returnsNormally);
    });

    test('container with overrides resolves pactStatsServiceProvider without throwing', () {
      final overrides = AppContainer.overrides(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(() => container.read(pactStatsServiceProvider), returnsNormally);
    });

    test('optional services are omitted when null — providers fall back to noop defaults', () {
      final overrides = AppContainer.overrides(
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
  });
}
