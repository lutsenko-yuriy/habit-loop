/// One resolved row for the debug pending-notifications viewer (HAB-228).
///
/// [fireAt] is `null` when it couldn't be recomputed — e.g. the notification's
/// payload is missing/malformed, or its showup or pact no longer exists.
class PendingNotificationRow {
  const PendingNotificationRow({
    required this.id,
    required this.title,
    required this.body,
    required this.fireAt,
  });

  final int id;
  final String? title;
  final String? body;
  final DateTime? fireAt;
}
