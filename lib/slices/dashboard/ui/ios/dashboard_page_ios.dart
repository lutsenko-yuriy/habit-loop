import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show AsyncCallback;
import 'package:flutter/material.dart' show Icon, Material, MaterialType, ScaffoldMessenger, Theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/analytics/kebab_analytics_events.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_actions.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_body.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_state.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/language_picker_handler.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_handler.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/ios/language_picker_dialog_ios.dart';
import 'package:habit_loop/slices/dashboard/ui/ios/onboarding_carousel_ios.dart';
import 'package:habit_loop/slices/debug/ui/ios/remote_config_overrides_page_ios.dart';
import 'package:habit_loop/slices/pact/ui/generic/pacts_summary_bar.dart' show PactsPanel;
import 'package:habit_loop/slices/showup/ui/generic/showup_formatters.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';

class DashboardPageIos extends ConsumerWidget {
  final DashboardState state;
  final bool hasPacts;
  final bool showCarousel;
  final ValueChanged<int> onDaySelected;
  final AsyncCallback onCreatePact;
  final Future<void> Function(String) onShowupTapped;
  final AsyncCallback onAbout;

  const DashboardPageIos({
    super.key,
    required this.state,
    required this.hasPacts,
    required this.showCarousel,
    required this.onDaySelected,
    required this.onCreatePact,
    required this.onShowupTapped,
    required this.onAbout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final syncState = ref.watch(syncStatusViewModelProvider);

    Future<void> onLanguagePickerTapped() => openLanguagePicker(
          context: context,
          ref: ref,
          showPicker: ({required context, required options, required currentOverride}) =>
              showCupertinoLanguagePicker(context, options, currentOverride, l10n),
        );

    Future<void> onSyncStatusTapped() => openSyncStatusDialog(
          context: context,
          ref: ref,
          showFn: ({required context, required title, required message, required actions}) =>
              _showCupertinoSyncDialog(context, title, message, actions),
          messenger: ScaffoldMessenger.of(context),
        );

    // Show the onboarding carousel full-screen (no nav bar) when requested.
    // showCarousel is true when there are no pacts + user is anonymous, OR
    // when sign-in is in progress (to avoid a flash of empty dashboard).
    if (showCarousel) {
      return OnboardingCarouselIos(onCreatePact: onCreatePact);
    }

    final featureFlags = ref.watch(featureFlagsProvider);

    final actions = buildDashboardActions(
      onRcOverridesPressed: () => Navigator.of(context)
          .push(CupertinoPageRoute<void>(builder: (_) => const RemoteConfigOverridesPageIos()))
          // ignore: use_build_context_synchronously — onDashboardRcOverridesClosed guards context.mounted
          .then((_) => onDashboardRcOverridesClosed(context, ref)),
      onSyncStatusPressed: onSyncStatusTapped,
      onLanguagePickerPressed: onLanguagePickerTapped,
      onCreatePactPressed: onCreatePact,
      onAboutPressed: onAbout,
      languageSelectionEnabled: featureFlags.languageSelectionEnabled,
      networkSyncEnabled: featureFlags.networkSyncEnabled,
      aboutScreenEnabled: featureFlags.aboutScreenEnabled,
    );

    final kebabItems = kebabMenuItems(actions);
    final standalone = standaloneNavBarItems(actions);
    final createPactAction = standalone.last;
    final otherStandalone = standalone.sublist(0, standalone.length - 1);

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        middle: Text(l10n.dashboardTitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...otherStandalone.map((a) => _buildNavBarButton(context, a, syncState, l10n)),
            if (kebabItems.isNotEmpty) _buildKebabButton(context, ref, kebabItems, l10n),
            _buildNavBarButton(context, createPactAction, syncState, l10n),
          ],
        ),
      ),
      child: SafeArea(
        key: const Key('dashboard-ios-safe-area'),
        bottom: false,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              state.isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : DashboardBody(
                      state: state,
                      hasPacts: hasPacts,
                      statusColors: ShowupStatusColors.cupertino(context),
                      separator: Container(height: 0.5, color: CupertinoColors.separator),
                      noPactsTextColor: CupertinoColors.systemGrey.resolveFrom(context),
                      onCreatePact: onCreatePact,
                      onDaySelected: onDaySelected,
                      onShowupTapped: onShowupTapped,
                      buildShowupTile: (ctx, showup, habitName, onTap) => _ShowupTile(
                        showup: showup,
                        habitName: habitName,
                        onTap: onTap,
                      ),
                      buildNoPactsCta: (ctx, createPact) => CupertinoButton.filled(
                        key: const Key('create-first-pact-button'),
                        onPressed: createPact,
                        child: Text(l10n.createPact),
                      ),
                    ),
              PactsPanel(onCreatePact: onCreatePact),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildKebabButton(
  BuildContext context,
  WidgetRef ref,
  List<DashboardActionDescriptor> items,
  AppLocalizations l10n,
) {
  Future<void> onKebabPressed() async {
    unawaited(ref.read(analyticsServiceProvider).logEvent(const KebabMenuOpenedEvent()));
    if (!context.mounted) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: items
            .map(
              (item) => CupertinoActionSheetAction(
                key: item.key,
                onPressed: () {
                  Navigator.pop(ctx);
                  item.onPressed();
                },
                child: Text(_kebabItemLabel(item.type, l10n)),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(CupertinoLocalizations.of(ctx).cancelButtonLabel),
        ),
      ),
    );
  }

  return Semantics(
    label: l10n.dashboardMoreOptionsTooltip,
    button: true,
    onTap: () => unawaited(onKebabPressed()),
    child: ExcludeSemantics(
      child: CupertinoButton(
        key: const Key('kebab-menu-button'),
        padding: EdgeInsets.zero,
        onPressed: onKebabPressed,
        child: const Icon(CupertinoIcons.ellipsis),
      ),
    ),
  );
}

String _kebabItemLabel(DashboardActionType type, AppLocalizations l10n) => switch (type) {
      DashboardActionType.about => l10n.aboutTitle,
      DashboardActionType.languagePicker => l10n.languagePickerTitle,
      DashboardActionType.rcOverrides => l10n.dashboardDebugMenuItem,
      _ => '',
    };

Widget _buildNavBarButton(
  BuildContext context,
  DashboardActionDescriptor action,
  dynamic syncState,
  AppLocalizations l10n,
) {
  final button = switch (action.type) {
    DashboardActionType.rcOverrides => CupertinoButton(
        key: action.key,
        padding: EdgeInsets.zero,
        onPressed: action.onPressed,
        child: const Icon(CupertinoIcons.wrench),
      ),
    DashboardActionType.syncStatus => CupertinoButton(
        key: action.key,
        padding: EdgeInsets.zero,
        onPressed: action.onPressed,
        child: Icon(
          syncStatusIconDataCupertino(syncState),
          color: syncStatusIconColor(syncState, context),
        ),
      ),
    DashboardActionType.createPact => CupertinoButton(
        key: action.key,
        padding: EdgeInsets.zero,
        onPressed: action.onPressed,
        child: const Icon(CupertinoIcons.add),
      ),
    DashboardActionType.languagePicker => CupertinoButton(
        key: action.key,
        padding: EdgeInsets.zero,
        onPressed: action.onPressed,
        child: const Icon(CupertinoIcons.globe),
      ),
    DashboardActionType.about => CupertinoButton(
        key: action.key,
        padding: EdgeInsets.zero,
        onPressed: action.onPressed,
        child: const Icon(CupertinoIcons.info_circle),
      ),
  };
  return Semantics(
    label: dashboardActionLabel(action.type, l10n),
    button: true,
    onTap: action.onPressed,
    child: ExcludeSemantics(child: button),
  );
}

class _ShowupTile extends StatelessWidget {
  final Showup showup;
  final String habitName;
  final VoidCallback onTap;

  const _ShowupTile({
    required this.showup,
    required this.habitName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusText = showupStatusText(l10n, showup.status);

    return CupertinoListTile(
      backgroundColor: CupertinoColors.transparent,
      onTap: onTap,
      leading: Icon(
        switch (showup.status) {
          ShowupStatus.done => CupertinoIcons.check_mark_circled_solid,
          ShowupStatus.failed => CupertinoIcons.xmark_circle_fill,
          ShowupStatus.pending => CupertinoIcons.circle,
        },
        color: ShowupStatusColors.cupertino(context).forStatus(showup.status),
      ),
      title: Text(habitName),
      subtitle: Text('${l10n.showupDurationMinutes(showup.duration.inMinutes)} — $statusText'),
    );
  }
}

Future<void> _showCupertinoSyncDialog(
  BuildContext context,
  String title,
  String message,
  List<SyncDialogAction> actions,
) async {
  // ignore: use_build_context_synchronously — caller guards context.mounted before this call
  await showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: actions.map((a) {
        return CupertinoDialogAction(
          isDestructiveAction: a.isDestructive,
          onPressed: () {
            Navigator.pop(ctx);
            a.onPressed();
          },
          child: Text(a.label),
        );
      }).toList(),
    ),
  );
}
