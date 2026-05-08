import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';

/// Time-derived UI state for a showup.
///
/// This is NOT a domain state — it is computed from the current time,
/// [Showup.scheduledAt], [Showup.duration], [Showup.status], and
/// the pact's [reminderOffset].
enum ShowupUiState {
  /// Before the reminder fires (or before start time if no reminder).
  planned,

  /// After reminder fired, before scheduled start time.
  waitingForStart,

  /// Active showup window: scheduledAt <= now < scheduledAt + duration.
  /// Also used when now is past the active window but the showup is still pending.
  pending,

  /// Manually or automatically marked as done.
  done,

  /// Manually or automatically marked as failed.
  failed,
}

/// Derives the UI state for a [showup] given [now] and the pact's [reminderOffset].
///
/// Rules (evaluated in order):
/// 1. If [showup.status] is done → [ShowupUiState.done]
/// 2. If [showup.status] is failed → [ShowupUiState.failed]
/// 3. If now >= scheduledAt → [ShowupUiState.pending] (active window or past)
/// 4. If reminderOffset is not null and > Duration.zero:
///    - reminderFiresAt = scheduledAt - reminderOffset
///    - If now >= reminderFiresAt → [ShowupUiState.waitingForStart]
/// 5. Otherwise → [ShowupUiState.planned]
ShowupUiState deriveShowupUiState({
  required Showup showup,
  required DateTime now,
  Duration? reminderOffset,
}) {
  // Rule 1 & 2: domain status overrides everything.
  if (showup.status == ShowupStatus.done) return ShowupUiState.done;
  if (showup.status == ShowupStatus.failed) return ShowupUiState.failed;

  // Rule 3: now is at or past the scheduled start.
  if (!now.isBefore(showup.scheduledAt)) return ShowupUiState.pending;

  // Rule 4: reminder has fired but showup hasn't started.
  if (reminderOffset != null && reminderOffset > Duration.zero) {
    final reminderFiresAt = showup.scheduledAt.subtract(reminderOffset);
    if (!now.isBefore(reminderFiresAt)) return ShowupUiState.waitingForStart;
  }

  // Rule 5: nothing has happened yet.
  return ShowupUiState.planned;
}
