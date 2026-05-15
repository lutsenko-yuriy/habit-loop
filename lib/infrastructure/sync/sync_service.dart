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

  /// Marks every local record as dirty and then calls [flushDirtyRecords].
  ///
  /// Use this after a Firebase UID change (e.g. upgrading from anonymous to a
  /// Google-linked account via `signInWithCredential`) so that records
  /// previously synced under the old UID are re-uploaded under the new one.
  ///
  /// No-throw contract: swallows all exceptions internally.
  Future<void> forceSyncAll();

  /// Fetches all remote pacts and showups for the current user from Firestore
  /// and merges them into the local SQLite database.
  ///
  /// Merge rules (per record):
  /// - Not in local DB → insert as new, mark synced.
  /// - Local record is dirty (unsync'd local changes) → keep local, skip.
  /// - Remote `updated_at` > local `synced_at` → overwrite local with remote.
  /// - Remote `updated_at` ≤ local `synced_at` (or missing) → keep local.
  ///
  /// **No-throw contract:** swallows all exceptions so a pull failure can never
  /// crash the app. Individual record errors are also isolated — one bad
  /// document never blocks the rest.
  ///
  /// **Circuit-breaker gate:** only runs when the CB is in the
  /// [SyncCircuitBreakerState.closed] state. Failure transitions the CB to
  /// half-open. No [recordSuccess] is emitted for read operations.
  ///
  /// Called fire-and-forget from `main.dart` after auth initialises.
  Future<void> pullRemoteChanges();
}
