import 'package:flutter/foundation.dart' show AsyncCallback;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/android/language_picker_dialog_android.dart';
import 'package:habit_loop/slices/dashboard/ui/android/onboarding_carousel_android.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_actions.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_body.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_state.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/language_picker_handler.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_handler.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_view_model.dart';
import 'package:habit_loop/slices/debug/ui/android/remote_config_overrides_page_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/pacts_summary_bar.dart' show PactsPanel;
import 'package:habit_loop/slices/showup/ui/generic/showup_formatters.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';

class DashboardPageAndroid extends ConsumerWidget {
  final DashboardState state;
  final bool hasPacts;
  final bool showCarousel;
  final ValueChanged<int> onDaySelected;
  final AsyncCallback onCreatePact;
  final Future<void> Function(String) onShowupTapped;
  final AsyncCallback onAbout;

  const DashboardPageAndroid({
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
              showMaterialLanguagePicker(context, options, currentOverride, l10n),
        );

    Future<void> onSyncStatusTapped() => openSyncStatusDialog(
          context: context,
          ref: ref,
          showFn: ({required context, required title, required message, required actions}) =>
              _showMaterialSyncDialog(context, title, message, actions),
          messenger: ScaffoldMessenger.of(context),
        );

    // Show the onboarding carousel full-screen (no app bar) when requested.
    // showCarousel is true when there are no pacts + user is anonymous, OR
    // when sign-in is in progress (to avoid a flash of empty dashboard).
    if (showCarousel) {
      return OnboardingCarouselAndroid(onCreatePact: onCreatePact);
    }

    final featureFlags = ref.watch(featureFlagsProvider);

    final actions = buildDashboardActions(
      onRcOverridesPressed: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const RemoteConfigOverridesPageAndroid()))
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

    final appBarActions = actions.where((a) => a.type != DashboardActionType.createPact).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboardTitle),
        actions: appBarActions.map((a) => _buildAppBarButton(context, a, syncState)).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('create-pact-button'),
        onPressed: onCreatePact,
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : DashboardBody(
                  state: state,
                  hasPacts: hasPacts,
                  statusColors: ShowupStatusColors.material(Theme.of(context).colorScheme),
                  separator: const Divider(height: 1),
                  noPactsTextColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  onCreatePact: onCreatePact,
                  onDaySelected: onDaySelected,
                  onShowupTapped: onShowupTapped,
                  buildShowupTile: (ctx, showup, habitName, onTap) => _ShowupTile(
                    showup: showup,
                    habitName: habitName,
                    onTap: onTap,
                  ),
                  buildNoPactsCta: (ctx, createPact) => ElevatedButton(
                    key: const Key('create-first-pact-button'),
                    onPressed: createPact,
                    child: Text(l10n.createPact),
                  ),
                ),
          PactsPanel(onCreatePact: onCreatePact),
        ],
      ),
    );
  }
}

Widget _buildAppBarButton(BuildContext context, DashboardActionDescriptor action, dynamic syncState) {
  return switch (action.type) {
    DashboardActionType.rcOverrides => IconButton(
        key: action.key,
        icon: const Icon(Icons.tune),
        onPressed: action.onPressed,
      ),
    DashboardActionType.syncStatus => IconButton(
        key: action.key,
        icon: Icon(
          syncStatusIconData(syncState),
          color: syncStatusIconColor(syncState, context),
        ),
        onPressed: action.onPressed,
      ),
    DashboardActionType.languagePicker => IconButton(
        key: action.key,
        icon: const Icon(Icons.language),
        onPressed: action.onPressed,
      ),
    DashboardActionType.createPact => const SizedBox.shrink(),
    DashboardActionType.about => IconButton(
        key: action.key,
        icon: const Icon(Icons.info_outline),
        onPressed: action.onPressed,
      ),
  };
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
    final icon = switch (showup.status) {
      ShowupStatus.done => Icons.check_circle,
      ShowupStatus.failed => Icons.cancel,
      ShowupStatus.pending => Icons.radio_button_unchecked,
    };
    final colors = ShowupStatusColors.material(Theme.of(context).colorScheme);
    final statusText = showupStatusText(l10n, showup.status);

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: colors.forStatus(showup.status)),
      title: Text(habitName),
      subtitle: Text('${l10n.showupDurationMinutes(showup.duration.inMinutes)} — $statusText'),
    );
  }
}

Future<void> _showMaterialSyncDialog(
  BuildContext context,
  String title,
  String message,
  List<SyncDialogAction> actions,
) async {
  // ignore: use_build_context_synchronously — caller guards context.mounted before this call
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: actions.map((a) {
        return TextButton(
          style: a.isDestructive ? TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error) : null,
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
