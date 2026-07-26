import 'package:habit_loop/domain/pact/break_derivation.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';

// NOT a domain state — computed from time, scheduledAt, duration, status, reminderOffset, and breaks.
enum ShowupUiState {
  /// Before the reminder fires (or before start time if no reminder).
  planned,

  /// After reminder fired, before scheduled start time.
  waitingForStart,

  /// Active showup window: scheduledAt <= now < scheduledAt + duration.
  /// Also used when now is past the active window but the showup is still pending.
  ///
  /// Named [active] (not "pending") to avoid confusion with the domain
  /// [ShowupStatus.pending], which covers all unresolved showups including
  /// future ones that are still [planned].
  active,

  /// Pending showup whose scheduledAt falls inside an active pact break window
  /// (HAB-195). An explicit done/failed mark always overrides this.
  onBreak,

  /// Manually or automatically marked as done.
  done,

  /// Manually or automatically marked as failed.
  failed,
}

/// Derives the UI state for a [showup] given [now], the pact's [reminderOffset],
/// and the pact's [breaks] (HAB-195).
///
/// Rules (evaluated in order):
/// 1. If [showup.status] is done → [ShowupUiState.done]
/// 2. If [showup.status] is failed → [ShowupUiState.failed]
/// 3. If the showup falls inside any of [breaks]' windows → [ShowupUiState.onBreak]
/// 4. If now >= scheduledAt → [ShowupUiState.active] (active window or past)
/// 5. If reminderOffset is not null and > Duration.zero:
///    - reminderFiresAt = scheduledAt - reminderOffset
///    - If now >= reminderFiresAt → [ShowupUiState.waitingForStart]
/// 6. Otherwise → [ShowupUiState.planned]
ShowupUiState deriveShowupUiState({
  required Showup showup,
  required DateTime now,
  Duration? reminderOffset,
  List<PactBreak> breaks = const [],
}) {
  if (showup.status == ShowupStatus.done) return ShowupUiState.done;
  if (showup.status == ShowupStatus.failed) return ShowupUiState.failed;
  if (BreakDerivation.isShowupOnBreak(showup: showup, breaks: breaks)) return ShowupUiState.onBreak;
  if (!now.isBefore(showup.scheduledAt)) return ShowupUiState.active;
  if (reminderOffset != null && reminderOffset > Duration.zero) {
    final reminderFiresAt = showup.scheduledAt.subtract(reminderOffset);
    if (!now.isBefore(reminderFiresAt)) return ShowupUiState.waitingForStart;
  }
  return ShowupUiState.planned;
}

// TODO(HAB-54): add a periodic timer to invalidate state at reminderFiresAt / scheduledAt crossings.
List<ShowupUiState> deriveUiStates(
  List<Showup> showups,
  Map<String, Duration?> reminderOffsetByPactId, {
  Map<String, List<PactBreak>> breaksByPactId = const {},
}) {
  final now = DateTime.now();
  return [
    for (final s in showups)
      deriveShowupUiState(
        showup: s,
        now: now,
        reminderOffset: reminderOffsetByPactId[s.pactId],
        breaks: breaksByPactId[s.pactId] ?? const [],
      ),
  ];
}
