import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/material.dart' show IconData, Icons, Theme;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_link_exception.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/analytics/sync_analytics_events.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_ui_state.dart';

// ---------------------------------------------------------------------------
// Icon helpers
// ---------------------------------------------------------------------------

IconData syncStatusIconData(SyncUiState state) => switch (state) {
      SyncUiState.synced => Icons.cloud_done_outlined,
      SyncUiState.degraded => Icons.sync_problem_outlined,
      SyncUiState.suspended => Icons.sync_disabled_outlined,
      SyncUiState.noInternet => Icons.wifi_off_outlined,
      SyncUiState.connecting => Icons.cloud_outlined,
      SyncUiState.notLinked => Icons.cloud_off_outlined,
    };

Color syncStatusIconColor(SyncUiState state, BuildContext context) {
  return switch (state) {
    SyncUiState.synced => CupertinoColors.systemGreen.resolveFrom(context),
    SyncUiState.degraded => CupertinoColors.systemOrange.resolveFrom(context),
    SyncUiState.suspended => CupertinoColors.systemRed.resolveFrom(context),
    SyncUiState.noInternet || SyncUiState.notLinked => CupertinoColors.systemGrey.resolveFrom(context),
    SyncUiState.connecting => Theme.of(context).colorScheme.primary,
  };
}

// ---------------------------------------------------------------------------
// Dialog orchestration
// ---------------------------------------------------------------------------

/// Platform-specific dialog callback type.
///
/// Receives all content and action data, shows the native UI, and returns
/// when the dialog is dismissed. Return value is ignored.
typedef SyncDialogShowFn = Future<void> Function({
  required BuildContext context,
  required String title,
  required String message,
  required List<SyncDialogAction> actions,
});

/// A single action button in the sync status dialog.
class SyncDialogAction {
  const SyncDialogAction({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;
}

/// Opens the sync status dialog using the provided platform-specific [showFn].
///
/// Shared between [DashboardPageIos] and [DashboardPageAndroid]. Each platform
/// supplies a [showFn] callback that renders its native dialog (a
/// [CupertinoAlertDialog] for iOS, an [AlertDialog] for Android).
///
/// Steps:
/// 1. Fire [SyncStatusOpenedEvent] and capture state.
/// 2. Guard on [BuildContext.mounted].
/// 3. Build message and action list from state.
/// 4. Delegate to [showFn].
Future<void> openSyncStatusDialog({
  required BuildContext context,
  required WidgetRef ref,
  required SyncDialogShowFn showFn,
}) async {
  final state = ref.read(syncStatusViewModelProvider);
  final vm = ref.read(syncStatusViewModelProvider.notifier);
  final analytics = ref.read(analyticsServiceProvider);

  unawaited(analytics.logEvent(SyncStatusOpenedEvent(state: state.name)));

  if (!context.mounted) return;

  final l10n = AppLocalizations.of(context)!;

  final message = switch (state) {
    SyncUiState.synced => l10n.syncStatusSynced,
    SyncUiState.degraded => l10n.syncStatusDegraded,
    SyncUiState.suspended => l10n.syncStatusSuspended,
    SyncUiState.noInternet => l10n.syncStatusNoInternet,
    SyncUiState.connecting => l10n.syncStatusConnecting,
    SyncUiState.notLinked => l10n.syncStatusNotLinked,
  };

  final actions = _buildActions(state, vm, l10n, context, showFn);

  await showFn(
    context: context,
    title: l10n.syncStatusTitle,
    message: message,
    actions: actions,
  );
}

List<SyncDialogAction> _buildActions(
  SyncUiState state,
  SyncStatusViewModel vm,
  AppLocalizations l10n,
  BuildContext outerContext,
  SyncDialogShowFn showFn,
) {
  return switch (state) {
    SyncUiState.notLinked => [
        SyncDialogAction(
          label: l10n.signInWithGoogle,
          onPressed: () => unawaited(() async {
            try {
              await vm.linkWithGoogle();
            } on AuthLinkException {
              if (outerContext.mounted) {
                unawaited(showFn(
                  context: outerContext,
                  title: l10n.syncStatusTitle,
                  message: l10n.signInWithGoogleFailed,
                  actions: [SyncDialogAction(label: l10n.notNow, onPressed: () {})],
                ));
              }
            }
          }()),
        ),
        SyncDialogAction(label: l10n.notNow, onPressed: () {}),
      ],
    SyncUiState.suspended || SyncUiState.degraded => [
        SyncDialogAction(label: l10n.syncNow, onPressed: () => unawaited(vm.triggerManualSync())),
        SyncDialogAction(label: l10n.notNow, onPressed: () {}),
      ],
    SyncUiState.synced => [
        SyncDialogAction(label: l10n.signOut, isDestructive: true, onPressed: () => unawaited(vm.signOut())),
        SyncDialogAction(label: l10n.notNow, onPressed: () {}),
      ],
    SyncUiState.noInternet || SyncUiState.connecting => [
        SyncDialogAction(label: l10n.notNow, onPressed: () {}),
      ],
  };
}
