/// Why [PendingNotificationRow.fireAt] couldn't be resolved. `none` means it
/// resolved successfully (or resolution wasn't attempted because [fireAt] is
/// non-null).
enum UnresolvedFireTimeReason {
  none,
  missingPayload,
  malformedPayload,
  showupNotFound,
  pactNotFound,
  noReminderOffset,
}

/// One resolved row for the debug pending-notifications viewer (HAB-228).
///
/// [fireAt] is `null` when it couldn't be recomputed — [unresolvedReason]
/// distinguishes why (missing showup/pact vs. cleared reminderOffset vs. a
/// malformed payload) so a developer investigating a suspected missing
/// reminder isn't left guessing.
class PendingNotificationRow {
  const PendingNotificationRow({
    required this.id,
    required this.title,
    required this.body,
    required this.fireAt,
    this.unresolvedReason = UnresolvedFireTimeReason.none,
  });

  final int id;
  final String? title;
  final String? body;
  final DateTime? fireAt;
  final UnresolvedFireTimeReason unresolvedReason;
}

/// Short, developer-facing label for [UnresolvedFireTimeReason] — shown next
/// to the notification's raw id when [PendingNotificationRow.fireAt] is null,
/// so an unresolvable row can be correlated back to DB state instead of just
/// reading "no scheduled time" with nothing to investigate further.
String unresolvedFireTimeReasonLabel(UnresolvedFireTimeReason reason) => switch (reason) {
      UnresolvedFireTimeReason.none => '',
      UnresolvedFireTimeReason.missingPayload => 'no payload',
      UnresolvedFireTimeReason.malformedPayload => 'malformed payload',
      UnresolvedFireTimeReason.showupNotFound => 'showup not found',
      UnresolvedFireTimeReason.pactNotFound => 'pact not found',
      UnresolvedFireTimeReason.noReminderOffset => 'pact has no reminderOffset',
    };
