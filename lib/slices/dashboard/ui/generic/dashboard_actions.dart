import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';

enum DashboardActionType { rcOverrides, syncStatus, languagePicker, createPact }

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
  required bool languageSelectionEnabled,
}) =>
    [
      if (kDebugMode || kProfileMode)
        DashboardActionDescriptor(
          type: DashboardActionType.rcOverrides,
          key: const Key('remote-config-debug-button'),
          onPressed: onRcOverridesPressed,
        ),
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
      DashboardActionDescriptor(
        type: DashboardActionType.createPact,
        key: const Key('create-pact-button'),
        onPressed: onCreatePactPressed,
      ),
    ];

void onDashboardRcOverridesClosed(BuildContext context, WidgetRef ref) {
  if (!context.mounted) return;
  ref.invalidate(hasActivePactsProvider);
  ref.invalidate(featureFlagsProvider);
  unawaited(ref.read(dashboardViewModelProvider.notifier).load());
  unawaited(ref.read(pactListViewModelProvider.notifier).load());
}
