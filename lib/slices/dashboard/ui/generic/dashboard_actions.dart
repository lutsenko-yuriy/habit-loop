import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';

enum DashboardActionType { rcOverrides, syncStatus, languagePicker, createPact, about }

class DashboardActionDescriptor {
  final DashboardActionType type;
  final Key? key;
  final VoidCallback onPressed;

  const DashboardActionDescriptor({required this.type, this.key, required this.onPressed});
}

List<DashboardActionDescriptor> buildDashboardActions({
  required VoidCallback onRcOverridesPressed,
  required VoidCallback onSyncStatusPressed,
  required VoidCallback onLanguagePickerPressed,
  required VoidCallback onCreatePactPressed,
  required VoidCallback onAboutPressed,
  required bool languageSelectionEnabled,
  required bool networkSyncEnabled,
  required bool aboutScreenEnabled,
}) =>
    [
      if (kDebugMode || kProfileMode)
        DashboardActionDescriptor(
          type: DashboardActionType.rcOverrides,
          key: const Key('remote-config-debug-button'),
          onPressed: onRcOverridesPressed,
        ),
      if (networkSyncEnabled)
        DashboardActionDescriptor(
          type: DashboardActionType.syncStatus,
          key: const Key('sync-status-button'),
          onPressed: onSyncStatusPressed,
        ),
      if (languageSelectionEnabled)
        DashboardActionDescriptor(
          type: DashboardActionType.languagePicker,
          key: const Key('language-picker-button'),
          onPressed: onLanguagePickerPressed,
        ),
      if (aboutScreenEnabled)
        DashboardActionDescriptor(
          type: DashboardActionType.about,
          key: const Key('about-button'),
          onPressed: onAboutPressed,
        ),
      DashboardActionDescriptor(
        type: DashboardActionType.createPact,
        key: const Key('create-pact-button'),
        onPressed: onCreatePactPressed,
      ),
    ];

const _kebabCandidateTypes = {
  DashboardActionType.rcOverrides,
  DashboardActionType.languagePicker,
  DashboardActionType.about,
};

/// Items that belong inside the kebab menu (⋯).
///
/// Returns an empty list when the single-item shortcut applies (≤1 candidate),
/// meaning the lone item renders as a standalone nav-bar button instead.
List<DashboardActionDescriptor> kebabMenuItems(List<DashboardActionDescriptor> actions) {
  final candidates = actions.where((a) => _kebabCandidateTypes.contains(a.type)).toList();
  return candidates.length > 1 ? candidates : const [];
}

/// Items that render as standalone nav-bar buttons.
///
/// Always includes [DashboardActionType.syncStatus] and
/// [DashboardActionType.createPact]. When the single-item shortcut applies
/// (≤1 kebab candidate), the lone candidate is also promoted to standalone.
///
/// **Note:** [DashboardActionType.createPact] is always last in the returned
/// list. UI callers must NOT use list position to decide rendering order for
/// the create-pact button — it must always be rendered as the rightmost item
/// regardless of its index here.
List<DashboardActionDescriptor> standaloneNavBarItems(List<DashboardActionDescriptor> actions) {
  final candidates = actions.where((a) => _kebabCandidateTypes.contains(a.type)).toList();
  final createPact = actions.where((a) => a.type == DashboardActionType.createPact).toList();
  final others =
      actions.where((a) => !_kebabCandidateTypes.contains(a.type) && a.type != DashboardActionType.createPact).toList();
  final promoted = candidates.length <= 1 ? candidates : const <DashboardActionDescriptor>[];
  return [...others, ...promoted, ...createPact];
}

void onDashboardRcOverridesClosed(BuildContext context, WidgetRef ref) {
  if (!context.mounted) return;
  ref.invalidate(hasActivePactsProvider);
  ref.invalidate(featureFlagsProvider);
  unawaited(ref.read(dashboardViewModelProvider.notifier).load());
  unawaited(ref.read(pactListViewModelProvider.notifier).load());
}
