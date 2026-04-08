import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/features/pact/data/pact_repository.dart';
import 'package:habit_loop/features/showup/data/showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup_detail_state.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

/// Provides the current time. Overridable in tests to make auto-fail logic
/// deterministic.
final showupDetailNowProvider = Provider<DateTime>((ref) => DateTime.now());

/// Repository provider for showups used by [ShowupDetailViewModel].
/// Must be overridden at the ProviderScope / ProviderContainer level.
final showupDetailShowupRepositoryProvider = Provider<ShowupRepository>((ref) {
  throw UnimplementedError('Override showupDetailShowupRepositoryProvider');
});

/// Repository provider for pacts used by [ShowupDetailViewModel].
/// Must be overridden at the ProviderScope / ProviderContainer level.
final showupDetailPactRepositoryProvider = Provider<PactRepository>((ref) {
  throw UnimplementedError('Override showupDetailPactRepositoryProvider');
});

/// Family provider keyed by showup ID.
final showupDetailViewModelProvider = NotifierProviderFamily<
    ShowupDetailViewModel, ShowupDetailState, String>(
  ShowupDetailViewModel.new,
);

/// View model for the showup detail screen.
///
/// Keyed by showup ID (the [arg]).
///
/// Responsibilities:
/// - [load] fetches the showup, resolves the habit name from its pact,
///   and auto-fails a pending showup if the current time is past
///   `scheduledAt + duration`.
/// - [markDone] / [markFailed] update and persist the status; no-ops when
///   the showup is already resolved.
/// - [saveNote] persists a note regardless of showup status. An empty string
///   clears the note.
class ShowupDetailViewModel
    extends FamilyNotifier<ShowupDetailState, String> {
  @override
  ShowupDetailState build(String showupId) {
    return const ShowupDetailState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearLoadError: true);
    try {
      final showupRepo = ref.read(showupDetailShowupRepositoryProvider);
      final pactRepo = ref.read(showupDetailPactRepositoryProvider);

      var showup = await showupRepo.getShowupById(arg);
      if (showup == null) {
        state = state.copyWith(
          isLoading: false,
          loadError: StateError('Showup not found: $arg'),
        );
        return;
      }

      // Resolve habit name from the associated pact.
      final pact = await pactRepo.getPactById(showup.pactId);
      final habitName = pact?.habitName;

      // Auto-fail if the showup is still pending but the window has passed.
      bool wasAutoFailed = false;
      if (showup.status == ShowupStatus.pending) {
        final now = ref.read(showupDetailNowProvider);
        final endTime = showup.scheduledAt.add(showup.duration);
        if (now.isAfter(endTime)) {
          showup = showup.copyWith(status: ShowupStatus.failed);
          await showupRepo.updateShowup(showup);
          wasAutoFailed = true;
        }
      }

      state = state.copyWith(
        showup: showup,
        habitName: habitName,
        isLoading: false,
        wasAutoFailed: wasAutoFailed,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, loadError: e);
    }
  }

  /// Marks the showup as done. No-op if the showup is not [ShowupStatus.pending].
  Future<void> markDone() async {
    final showup = state.showup;
    if (showup == null || showup.status != ShowupStatus.pending) return;
    await _updateStatus(ShowupStatus.done);
  }

  /// Marks the showup as failed. No-op if the showup is not [ShowupStatus.pending].
  Future<void> markFailed() async {
    final showup = state.showup;
    if (showup == null || showup.status != ShowupStatus.pending) return;
    await _updateStatus(ShowupStatus.failed);
  }

  Future<void> _updateStatus(ShowupStatus newStatus) async {
    state = state.copyWith(isSaving: true, clearSaveError: true);
    try {
      final updatedShowup = state.showup!.copyWith(status: newStatus);
      final showupRepo = ref.read(showupDetailShowupRepositoryProvider);
      await showupRepo.updateShowup(updatedShowup);
      state = state.copyWith(showup: updatedShowup, isSaving: false);
    } catch (e) {
      state = state.copyWith(isSaving: false, saveError: e);
    }
  }

  /// Saves a note on the showup. An empty string clears the note.
  /// Always available regardless of showup status.
  Future<void> saveNote(String note) async {
    final showup = state.showup;
    if (showup == null) return;
    state = state.copyWith(isSaving: true, clearSaveError: true);
    try {
      final updatedShowup = note.isEmpty
          ? showup.copyWith(clearNote: true)
          : showup.copyWith(note: note);
      final showupRepo = ref.read(showupDetailShowupRepositoryProvider);
      await showupRepo.updateShowup(updatedShowup);
      state = state.copyWith(showup: updatedShowup, isSaving: false);
    } catch (e) {
      state = state.copyWith(isSaving: false, saveError: e);
    }
  }
}
