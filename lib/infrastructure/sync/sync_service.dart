import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';

/// Abstract interface for the write-through sync service.
///
/// No-throw contract: all implementations must swallow exceptions internally
/// so a sync failure can never crash the app or surface to the user.
///
/// **Callers:**
/// - [PactService] and [PactStatsService] call [uploadPact] / [uploadShowup]
///   fire-and-forget after every local write.
/// - WU6 sync-status UI calls [triggerManualSync] when the user taps the
///   retry button.
abstract class SyncService {
  /// Uploads [pact] to Firestore if the circuit breaker allows requests.
  ///
  /// On success: marks the pact synced in SQLite and reports success to the
  /// circuit breaker. On failure: reports the failure to the circuit breaker.
  /// No-op when the circuit breaker is [SyncCircuitBreakerState.open].
  Future<void> uploadPact(Pact pact);

  /// Uploads [showup] to Firestore if the circuit breaker allows requests.
  ///
  /// Same success/failure semantics as [uploadPact].
  Future<void> uploadShowup(Showup showup);

  /// Loads all locally-dirty records and uploads them to Firestore.
  ///
  /// Processes pacts and showups sequentially; stops early if the circuit
  /// breaker transitions to [SyncCircuitBreakerState.open] mid-flush.
  /// Capped at 400 items per invocation to stay below the Firestore 500-write
  /// batch limit.
  Future<void> flushDirtyRecords();

  /// Transitions the circuit breaker from open to half-open and immediately
  /// fires [flushDirtyRecords] as a fire-and-forget probe pass.
  ///
  /// Called by WU6 when the user manually requests a sync retry. No-op when
  /// the circuit breaker is not in [SyncCircuitBreakerState.open].
  void triggerManualSync();
}
