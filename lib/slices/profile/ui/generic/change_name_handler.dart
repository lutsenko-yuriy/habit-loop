import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/profile/analytics/profile_analytics_events.dart';
import 'package:habit_loop/slices/profile/ui/generic/display_name_provider.dart';
import 'package:habit_loop/slices/profile/ui/generic/enter_name_constants.dart';

/// Shared between iOS and Android dashboard. Opens the "Change name" dialog
/// (⋯ menu, HAB-232), pre-filled with the current name, and persists any
/// change via [displayNameProvider]. Fires analytics before showing the
/// dialog (screen view) and after a save (change event) — mirrors
/// `openLanguagePicker`'s shape.
Future<void> openChangeNameDialog({
  required BuildContext context,
  required WidgetRef ref,

  /// Platform-specific dialog. Receives the current name (empty string if
  /// none on file) and returns the trimmed new name on Save, or `null` if
  /// cancelled/dismissed. The dialog itself is responsible for disabling
  /// Save while the field is empty — this handler never clears a name.
  required Future<String?> Function({required BuildContext context, required String currentName}) showDialog,
}) async {
  final analytics = ref.read(analyticsServiceProvider);

  // Capture before any await — an async-gap read could be stale by the time
  // the dialog closes (e.g. a remote pull lands while it's open).
  final currentName = ref.read(displayNameProvider) ?? '';

  unawaited(analytics.logScreenView(const ChangeNameAnalyticsScreen()));

  if (!context.mounted) return;

  final newName = await showDialog(context: context, currentName: currentName);
  if (newName == null) return; // cancelled/dismissed

  // Same grapheme-safe cap as EnterNameScreen — a name arriving pre-filled
  // via sync mid-edit could exceed enterNameMaxLength even though the
  // dialog's own input formatter caps typed input.
  final chars = newName.characters;
  final capped = chars.length <= enterNameMaxLength ? newName : chars.take(enterNameMaxLength).toString();

  final hadPreviousName = currentName.isNotEmpty;
  await ref.read(displayNameProvider.notifier).setDisplayName(capped);

  unawaited(
    analytics.logEvent(
      DisplayNameChangedEvent(nameLength: capped.characters.length, hadPreviousName: hadPreviousName),
    ),
  );
}
