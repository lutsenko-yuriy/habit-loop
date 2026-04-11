import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/analytics/domain/analytics_event.dart';
import 'package:habit_loop/analytics/providers/analytics_providers.dart';
import 'package:habit_loop/features/showup/analytics/showup_analytics_events.dart';
import 'package:habit_loop/features/pact/data/pact_repository.dart';
import 'package:habit_loop/features/showup/data/showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup_detail_state.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

/// Provides the current time. Overridable in tests to make auto-fail logic
/// deterministic.
///
/// NOTE: This provider is intentionally NOT cached between navigations — it is
/// invalidated by [ShowupDetailScreen] before every [ShowupDetailViewModel.load]
/// call so that `DateTime.now()` is always sampled at the moment the screen
/// opens, not at app-start time.
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
///
/// Uses `autoDispose` so state is released when the screen is popped, avoiding
/// unbounded accumulation of one ViewModel instance per visited showup ID.
/// [ShowupDetailScreen.initState] always calls [ShowupDetailViewModel.load] on
/// entry, so re-creating the state on each visit is correct and safe.
final showupDetailViewModelProvider =
    AutoDisposeNotifierProviderFamily<ShowupDetailViewModel, ShowupDetailState,
        String>(
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
    extends AutoDisposeFamilyNotifier<ShowupDetailState, String> {
  @override
  ShowupDetailState build(String showupId) {
    return const ShowupDetailState();
  }

  Future<void> load() async {
    // Clear any stale saving state from a previous visit so buttons are never
    // permanently disabled when the screen is re-entered after an interrupted save.
    state = state.copyWith(
      isLoading: true,
      clearLoadError: true,
      isSaving: false,
      clearMarkError: true,
      clearNoteError: true,
    );
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
      // If the pact is missing (e.g. deleted while showups were not cleaned up),
      // habitName is left null so the UI layer can show a localised fallback.
      final pact = await pactRepo.getPactById(showup.pactId);
      final habitName = pact?.habitName;

      // Auto-fail if the showup is still pending but the window has passed.
      // showupDetailNowProvider is invalidated by ShowupDetailScreen before
      // load() is called, so this always reflects the real current time.
      bool wasAutoFailed = false;
      if (showup.status == ShowupStatus.pending) {
        final now = ref.read(showupDetailNowProvider);
        final endTime = showup.scheduledAt.add(showup.duration);
        if (now.isAfter(endTime)) {
          showup = showup.copyWith(status: ShowupStatus.failed);
          await showupRepo.updateShowup(showup);
          wasAutoFailed = true;

          // Fire auto-fail analytics event.
          // AnalyticsService is no-throw; no wrapping try/catch needed.
          await ref.read(analyticsServiceProvider).logEvent(
            ShowupAutoFailedEvent(pactId: showup.pactId),
          );
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
    state = state.copyWith(isSaving: true, clearMarkError: true);
    try {
      final updatedShowup = state.showup!.copyWith(status: newStatus);
      final showupRepo = ref.read(showupDetailShowupRepositoryProvider);
      await showupRepo.updateShowup(updatedShowup);
      state = state.copyWith(showup: updatedShowup, isSaving: false);

      // Determine the analytics event before entering the try block so that a
      // StateError on an unexpected pending status propagates to the outer
      // catch and is surfaced as markError rather than being swallowed.
      final AnalyticsEvent event = switch (newStatus) {
        ShowupStatus.done =>
          ShowupMarkedDoneEvent(pactId: updatedShowup.pactId),
        ShowupStatus.failed =>
          ShowupMarkedFailedEvent(pactId: updatedShowup.pactId),
        ShowupStatus.pending => throw StateError('Unexpected pending status'),
      };

      // Fire analytics for manual status changes. Swallow failures.
      await ref.read(analyticsServiceProvider).logEvent(event);
    } catch (e) {
      state = state.copyWith(isSaving: false, markError: e);
    }
  }

  /// Saves a note on the showup. An empty string clears the note.
  /// Always available regardless of showup status.
  Future<void> saveNote(String note) async {
    final showup = state.showup;
    if (showup == null) return;
    state = state.copyWith(isSaving: true, clearNoteError: true);
    try {
      final updatedShowup = note.isEmpty
          ? showup.copyWith(clearNote: true)
          : showup.copyWith(note: note);
      final showupRepo = ref.read(showupDetailShowupRepositoryProvider);
      await showupRepo.updateShowup(updatedShowup);
      state = state.copyWith(showup: updatedShowup, isSaving: false);
    } catch (e) {
      state = state.copyWith(isSaving: false, noteError: e);
    }
  }
}
