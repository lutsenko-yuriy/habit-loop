import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_screen.dart';

/// Parses notification payloads and routes to the correct screen.
///
/// Used by `main.dart` for both warm-start (app already running) and cold-start
/// (app killed and relaunched via notification tap) deep-link routing.
///
/// **Payload format** (established in WU1):
/// ```json
/// {"showupId": "abc-123", "pactId": "def-456"}
/// ```
///
/// **Navigation:** uses the supplied [GlobalKey]<[NavigatorState]> to push the
/// platform-appropriate [ShowupDetailScreen]. No-ops when the key has no current
/// context (e.g. the widget tree is not yet mounted).
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

  /// Navigates to [ShowupDetailScreen] for the given [showupId] and [pactId].
  ///
  /// Uses [navigatorKey] to obtain the current [NavigatorState]. No-ops when
  /// [navigatorKey] has no current context (widget tree not yet mounted).
  ///
  /// Pushes a [MaterialPageRoute] on Android and a [CupertinoPageRoute]-equivalent
  /// `MaterialPageRoute` on iOS — following the same pattern used on the dashboard.
  /// The route is pushed without waiting, so the caller does not need to be async.
  static void navigateToShowup({
    required GlobalKey<NavigatorState> navigatorKey,
    required String showupId,
    required String pactId,
  }) {
    final state = navigatorKey.currentState;
    if (state == null) {
      debugPrint('[NotificationRouter] navigateToShowup: navigatorKey has no current state — skipping navigation');
      return;
    }
    unawaited(
      state.push(
        MaterialPageRoute<void>(
          builder: (_) => ShowupDetailScreen(showupId: showupId),
        ),
      ),
    );
  }
}
