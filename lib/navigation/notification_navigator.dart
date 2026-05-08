import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_screen.dart';

/// App-level navigation for notification deep links.
///
/// Lives in `lib/navigation/` — outside any layer — so it may import both
/// infrastructure contracts and slice UI without violating layer rules.
///
/// Used by `main.dart` for both warm-start (app already running) and cold-start
/// (app killed and relaunched via notification tap) deep-link routing.
abstract final class NotificationNavigator {
  /// Navigates to [ShowupDetailScreen] for the given [showupId].
  ///
  /// Uses [navigatorKey] to obtain the current [NavigatorState]. No-ops when
  /// [navigatorKey] has no current context (widget tree not yet mounted).
  ///
  /// Pushes a [CupertinoPageRoute] on iOS and a [MaterialPageRoute] on Android.
  /// The route is pushed without waiting, so the caller does not need to be async.
  static void navigateToShowup({
    required GlobalKey<NavigatorState> navigatorKey,
    required String showupId,
  }) {
    final state = navigatorKey.currentState;
    if (state == null) {
      debugPrint('[NotificationNavigator] navigateToShowup: navigatorKey has no current state — skipping navigation');
      return;
    }
    debugPrint('[NotificationNavigator] pushing ShowupDetailScreen for showupId=$showupId');
    unawaited(
      state.push(
        defaultTargetPlatform == TargetPlatform.iOS
            ? CupertinoPageRoute<void>(
                builder: (_) => ShowupDetailScreen(showupId: showupId),
              )
            : MaterialPageRoute<void>(
                builder: (_) => ShowupDetailScreen(showupId: showupId),
              ),
      ),
    );
  }
}
