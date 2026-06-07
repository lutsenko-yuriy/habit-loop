import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kDebugMode, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_screen.dart';

// Lives in lib/navigation/ (outside any slice) so it may import both infrastructure and slice UI.
abstract final class NotificationNavigator {
  static void navigateToShowup({
    required GlobalKey<NavigatorState> navigatorKey,
    required String showupId,
  }) {
    final state = navigatorKey.currentState;
    if (state == null) {
      debugPrint('[NotificationNavigator] navigateToShowup: navigatorKey has no current state — skipping navigation');
      return;
    }
    if (kDebugMode) debugPrint('[NotificationNavigator] pushing ShowupDetailScreen for showupId=$showupId');
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
