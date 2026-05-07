import 'dart:convert';

/// Parses notification payloads for deep-link routing.
///
/// Used by `main.dart` (via [NotificationNavigator]) for both warm-start
/// (app already running) and cold-start (app killed and relaunched via
/// notification tap) deep-link routing.
///
/// **Payload format** (established in WU1):
/// ```json
/// {"showupId": "abc-123", "pactId": "def-456"}
/// ```
///
/// Navigation concerns are handled by `lib/navigation/notification_navigator.dart`
/// so that this class stays inside the infrastructure layer with no UI imports.
abstract final class NotificationRouter {
  /// Parses the JSON [payload] and extracts `showupId` and `pactId`.
  ///
  /// Returns a named record `({String showupId, String pactId})` on success.
  /// Returns `null` when:
  /// - [payload] is `null` or empty
  /// - [payload] is not valid JSON
  /// - the JSON object is missing `showupId` or `pactId`
  static ({String showupId, String pactId})? parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      final showupId = decoded['showupId'];
      final pactId = decoded['pactId'];
      if (showupId is! String || pactId is! String) return null;
      return (showupId: showupId, pactId: pactId);
    } catch (_) {
      return null;
    }
  }
}
