import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/auth/data/local_auth_service.dart';
import 'package:habit_loop/infrastructure/firestore/data/fake_firestore_client.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/infrastructure/sync/sync_mapper.dart';

/// Exposes the seed state: idle, busy (with a message), done, or error.
enum DebugSeedState { idle, busy, done, error }

/// State for the debug seed-data screen.
class DebugSeedDataState {
  const DebugSeedDataState({
    this.status = DebugSeedState.idle,
    this.message,
  });

  final DebugSeedState status;
  final String? message;

  bool get isBusy => status == DebugSeedState.busy;

  DebugSeedDataState copyWith({DebugSeedState? status, String? message}) => DebugSeedDataState(
        status: status ?? this.status,
        message: message ?? this.message,
      );
}

/// Fixed list of habit names used for generated test pacts.
///
/// When [RemoteConfigDefaults.maxActivePacts] is N, the first N entries are
/// used. If N > the list length the entries wrap around.
const _kHabitNames = [
  'Meditate',
  'Run',
  'Read',
  'Journal',
  'Stretch',
];

/// ViewModel for the debug seed-data section shown at the bottom of the
/// Remote Config overrides page.
///
/// Provides two actions:
/// - [seedLocalPacts] — clears the local SQLite pacts + showups and inserts
///   fresh test pacts. Updates [hasLocalPacts] after completion.
/// - [seedRemotePacts] — available only when `debug_backend = local`; clears
///   and re-seeds the in-memory [FakeFirestoreClient]. The next
///   `pullRemoteChanges()` will merge the new data into the local DB.
///
/// **Debug/profile only.** Never constructed in release builds.
class DebugSeedDataViewModel extends AutoDisposeNotifier<DebugSeedDataState> {
  @override
  DebugSeedDataState build() => const DebugSeedDataState();

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  /// Returns true when [fakeFirestoreClientProvider] has a live instance,
  /// i.e. when the app started with `debug_backend = local`.
  bool get hasFakeBackend => ref.read(fakeFirestoreClientProvider) is FakeFirestoreClient;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Deletes all local pacts + showups and inserts fresh test pacts.
  ///
  /// The number of pacts is driven by [RemoteConfigDefaults.maxActivePacts]
  /// (read from the active RC service at call time).
  Future<void> seedLocalPacts() async {
    if (state.isBusy) return;
    state = const DebugSeedDataState(
      status: DebugSeedState.busy,
      message: 'Generating local pacts…',
    );
    try {
      final pactService = ref.read(pactServiceProvider);
      final showupRepo = ref.read(showupRepositoryProvider);
      final rc = ref.read(remoteConfigServiceProvider);
      final n = rc.getInt('max_active_pacts').clamp(1, _kHabitNames.length * 2);

      // Clear existing data.
      final existingPacts = await pactService.getAllPacts();
      for (final p in existingPacts) {
        await showupRepo.deleteShowupsForPact(p.id);
        await pactService.deletePact(p.id);
      }

      // Build and persist new test pacts.
      final now = DateTime.now();
      for (var i = 0; i < n; i++) {
        final pact = _buildTestPact(
          id: 'debug-seed-local-$i',
          name: _kHabitNames[i % _kHabitNames.length],
          now: now,
        );
        final showups = _generateShowups(pact, now: now);
        await pactService.createPact(pact, showups);
      }

      state = DebugSeedDataState(
        status: DebugSeedState.done,
        message: 'Local pacts regenerated ($n pacts).',
      );
    } catch (e) {
      state = DebugSeedDataState(
        status: DebugSeedState.error,
        message: 'Error: $e',
      );
    }
  }

  /// Clears and re-seeds the in-memory [FakeFirestoreClient].
  ///
  /// Only callable when [hasFakeBackend] is true. The next
  /// `pullRemoteChanges()` triggered from the sync status dialog will merge
  /// the new remote records into the local DB.
  Future<void> seedRemotePacts() async {
    if (state.isBusy) return;
    final fake = ref.read(fakeFirestoreClientProvider);
    if (fake is! FakeFirestoreClient) return;

    state = const DebugSeedDataState(
      status: DebugSeedState.busy,
      message: 'Generating remote pacts…',
    );
    try {
      final rc = ref.read(remoteConfigServiceProvider);
      final n = rc.getInt('max_active_pacts').clamp(1, _kHabitNames.length * 2);

      // Use localUserId so data appears when LocalAuthService sign-in is complete.
      const userId = LocalAuthService.localUserId;

      // Clear the fake backend for this user.
      fake.clear();

      // Build and seed new test pacts and their showups.
      final now = DateTime.now();
      final pactDocs = <String, Map<String, dynamic>>{};
      final showupDocs = <String, Map<String, dynamic>>{};

      for (var i = 0; i < n; i++) {
        final pact = _buildTestPact(
          id: 'debug-seed-remote-$i',
          name: _kHabitNames[i % _kHabitNames.length],
          now: now,
        );
        final showups = _generateShowups(pact, now: now);
        pactDocs[pact.id] = SyncMapper.pactToDocument(pact, updatedAt: now);
        for (final s in showups) {
          showupDocs[s.id] = SyncMapper.showupToDocument(s, updatedAt: now);
        }
      }

      fake.seed(FakeFirestoreSeedData(
        pacts: {userId: pactDocs},
        showups: {userId: showupDocs},
      ));

      state = DebugSeedDataState(
        status: DebugSeedState.done,
        message: 'Remote pacts seeded ($n pacts). Pull sync to merge.',
      );
    } catch (e) {
      state = DebugSeedDataState(
        status: DebugSeedState.error,
        message: 'Error: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Pact _buildTestPact({
    required String id,
    required String name,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 30));
    // Use 5 months ahead — safe against month overflow via Duration arithmetic.
    final end = today.add(const Duration(days: 150));
    return Pact(
      id: id,
      habitName: name,
      startDate: start,
      endDate: end,
      showupDuration: const Duration(minutes: 10),
      // Mon–Fri at 08:00.
      schedule: SlotSchedule(slots: [
        WeeklySlot(
          weekdays: {1, 2, 3, 4, 5},
          timeOfDay: const Duration(hours: 8),
        ),
      ]),
      status: PactStatus.active,
      reminderOffset: null,
      createdAt: start,
    );
  }

  /// Generates all showups for [pact] and auto-fails past ones.
  List<Showup> _generateShowups(Pact pact, {required DateTime now}) {
    return ShowupGenerator.generateWindow(
      pact,
      from: pact.startDate,
      to: pact.endDate,
    ).map((s) {
      final isPast = s.scheduledAt.add(pact.showupDuration).isBefore(now);
      if (isPast && s.status == ShowupStatus.pending) {
        return Showup(
          id: s.id,
          pactId: s.pactId,
          scheduledAt: s.scheduledAt,
          duration: s.duration,
          status: ShowupStatus.failed,
          note: s.note,
        );
      }
      return s;
    }).toList();
  }
}

final debugSeedDataViewModelProvider = AutoDisposeNotifierProvider<DebugSeedDataViewModel, DebugSeedDataState>(
  DebugSeedDataViewModel.new,
);
