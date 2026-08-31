import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/profile/analytics/profile_analytics_events.dart';
import 'package:habit_loop/slices/profile/ui/generic/display_name_provider.dart';
import 'package:habit_loop/slices/profile/ui/generic/enter_name_constants.dart';
import 'package:habit_loop/slices/reminder/application/reminder_rescheduler.dart';

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
  /// cancelled/dismissed. Save is always enabled, including on an empty
  /// field — an empty result here is a deliberate clear, not a cancellation;
  /// [UserProfile]'s own normalization turns it into `displayName == null`.
  required Future<String?> Function({required BuildContext context, required String currentName}) showDialogFn,
}) async {
  final analytics = ref.read(analyticsServiceProvider);

  // Capture before any await — an async-gap read could be stale by the time
  // the dialog closes (e.g. a remote pull lands while it's open). Reads
  // personalizedNameProvider (not the raw displayNameProvider) per that
  // provider's own docstring — behaviourally identical today since this
  // dialog is only reachable while the flag is on.
  final currentName = ref.read(personalizedNameProvider) ?? '';

  unawaited(analytics.logScreenView(const ChangeNameAnalyticsScreen()));

  if (!context.mounted) return;

  final newName = await showDialogFn(context: context, currentName: currentName);

  // Re-check after the dialog's own await — the widget (and this ref) may
  // have been torn down while it was open, e.g. the user navigated away.
  if (!context.mounted) return;
  if (newName == null) return; // cancelled/dismissed

  final capped = capToMaxNameLength(newName);
  if (capped == currentName) return; // unchanged — no-op, mirrors applyLanguageSelection

  final hadPreviousName = currentName.isNotEmpty;
  try {
    await ref.read(displayNameProvider.notifier).setDisplayName(capped);
  } catch (_) {
    // Never let a transient DB failure crash a menu callback — the dialog is
    // already closed, so there is nowhere left to surface an inline error.
    // Skip the analytics event since nothing was actually persisted.
    return;
  }

  // Already-scheduled notifications keep their old (or absent) name in the
  // text baked into the OS payload — re-schedule them, same reasoning as
  // openLanguagePicker's HAB-157 fix (HAB-232 WU7 audit finding). Own
  // try/catch: a reschedule failure must not be mistaken for the name save
  // itself failing — that already succeeded above.
  try {
    await rescheduleAllPendingReminders(ref);
  } catch (_) {
    // The saved name still stands; only the reschedule pass failed.
  }

  unawaited(
    analytics.logEvent(
      DisplayNameChangedEvent(nameLength: capped.characters.length, hadPreviousName: hadPreviousName),
    ),
  );
}
