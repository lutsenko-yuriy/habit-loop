import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kDebugMode, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_screen.dart';

// Lives in lib/navigation/ (outside any slice) so it may import both infrastructure and slice UI.
abstract final class NotificationNavigator {
  /// Pushes [ShowupDetailScreen] for [showupId] and awaits the route pop.
  /// [onReturn] is called after the user navigates back — use it to trigger
  /// a dashboard refresh so stale pending state is not shown after a status
  /// change made on the detail screen.
  static Future<void> navigateToShowup({
    required GlobalKey<NavigatorState> navigatorKey,
    required String showupId,
    VoidCallback? onReturn,
  }) async {
    final state = navigatorKey.currentState;
    if (state == null) {
      debugPrint('[NotificationNavigator] navigateToShowup: navigatorKey has no current state — skipping navigation');
      return;
    }
    if (kDebugMode) debugPrint('[NotificationNavigator] pushing ShowupDetailScreen for showupId=$showupId');
    await state.push(
      defaultTargetPlatform == TargetPlatform.iOS
          ? CupertinoPageRoute<void>(
              builder: (_) => ShowupDetailScreen(showupId: showupId),
            )
          : MaterialPageRoute<void>(
              builder: (_) => ShowupDetailScreen(showupId: showupId),
            ),
    );
    onReturn?.call();
  }
}
