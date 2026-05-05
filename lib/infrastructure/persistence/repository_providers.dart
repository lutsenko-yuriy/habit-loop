import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';

/// Canonical [PactRepository] provider.
///
/// Throws [UnimplementedError] by default — must be overridden in `main.dart`
/// with the SQLite-backed [SqlitePactRepository] instance, and in tests with an
/// [InMemoryPactRepository].
///
/// Lives in `lib/infrastructure/persistence/` so that application-layer services
/// (e.g. [PactStatsService], [PactService]) can import it without creating a
/// cross-layer dependency on a UI-layer file.
final pactRepositoryProvider = Provider<PactRepository>((ref) {
  throw UnimplementedError('pactRepositoryProvider must be overridden in main.dart');
});

/// Canonical [ShowupRepository] provider.
///
/// Throws [UnimplementedError] by default — must be overridden in `main.dart`
/// with the SQLite-backed [SqliteShowupRepository] instance, and in tests with
/// an [InMemoryShowupRepository].
final showupRepositoryProvider = Provider<ShowupRepository>((ref) {
  throw UnimplementedError('showupRepositoryProvider must be overridden in main.dart');
});
