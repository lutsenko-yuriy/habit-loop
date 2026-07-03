import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_screen.dart';

/// Fired when the user successfully completes the pact creation wizard and
/// the pact is persisted.
final class PactCreatedEvent extends AnalyticsEvent {
  PactCreatedEvent({
    required this.scheduleType,
    required this.durationDays,
    required this.showupDurationMinutes,
    this.reminderOffsetMinutes,
    required this.showupsExpected,
    required this.usedSummaryJump,
    required this.commitmentVariant,
  });

  /// One of `daily`, `weekly`, or `monthly`.
  final String scheduleType;

  /// Pact length in days.
  final int durationDays;

  /// Length of a single showup in minutes.
  final int showupDurationMinutes;

  /// Minutes before the showup for the reminder; `null` if no reminder was set.
  final int? reminderOffsetMinutes;

  /// Total number of showups scheduled over the full pact.
  final int showupsExpected;

  /// `true` if the user tapped at least one Summary-screen row to jump back
  /// to a step before submitting; `false` if they swiped through linearly.
  final bool usedSummaryJump;

  /// Commitment confirmation dialog variant shown to this user: `button` |
  /// `checkbox` | `retype`. Read from Remote Config flag
  /// `exp_003_commitment_confirmation`.
  final String commitmentVariant;

  @override
  String get name => 'pact_created';

  @override
  Map<String, Object?> toParameters() {
    return {
      'schedule_type': scheduleType,
      'duration_days': durationDays,
      'showup_duration_minutes': showupDurationMinutes,
      if (reminderOffsetMinutes != null) 'reminder_offset_minutes': reminderOffsetMinutes!,
      'showups_expected': showupsExpected,
      'used_summary_jump': usedSummaryJump,
      'commitment_variant': commitmentVariant,
    };
  }
}

/// Fired when the user confirms stopping an active pact.
final class PactStoppedEvent extends AnalyticsEvent {
  PactStoppedEvent({
    required this.daysActive,
    required this.totalShowupsDone,
    required this.totalShowupsFailed,
    required this.totalShowupsRemaining,
  });

  /// Number of days from pact start to the stop date.
  final int daysActive;

  /// Showups marked done at the time of stopping.
  final int totalShowupsDone;

  /// Showups marked failed at the time of stopping.
  final int totalShowupsFailed;

  /// Showups still pending at the time of stopping.
  final int totalShowupsRemaining;

  @override
  String get name => 'pact_stopped';

  @override
  Map<String, Object?> toParameters() => {
        'days_active': daysActive,
        'total_showups_done': totalShowupsDone,
        'total_showups_failed': totalShowupsFailed,
        'total_showups_remaining': totalShowupsRemaining,
      };
}

/// Fired when the user closes the commitment confirmation dialog without
/// completing the confirmation action. Measures abandonment at the final gate.
/// (HAB-82 / EXP-003)
final class PactCommitmentDialogDismissedEvent extends AnalyticsEvent {
  PactCommitmentDialogDismissedEvent({required this.variant});

  /// Dialog variant that was shown: `button` | `checkbox` | `retype`.
  final String variant;

  @override
  String get name => 'pact_commitment_dialog_dismissed';

  @override
  Map<String, Object?> toParameters() => {'variant': variant};
}

/// Fired when the user taps a row on the Summary screen to jump directly to a
/// specific step page. (HAB-82)
final class PactWizardStepJumpedEvent extends AnalyticsEvent {
  PactWizardStepJumpedEvent({required this.stepName, required this.mode});

  /// Step jumped to: `habit_name` | `duration` | `showup_duration` |
  /// `schedule` | `reminder`.
  final String stepName;

  /// `creation` | `editing`.
  final String mode;

  @override
  String get name => 'pact_wizard_step_jumped';

  @override
  Map<String, Object?> toParameters() => {
        'step_name': stepName,
        'mode': mode,
      };
}

/// Fired when the user dismisses the wizard via back-navigation (`PopScope`)
/// without completing it. (HAB-82)
final class PactWizardAbandonedEvent extends AnalyticsEvent {
  PactWizardAbandonedEvent({required this.mode, required this.lastStep});

  /// `creation` | `editing`.
  final String mode;

  /// Page visible when the user exited: `commitment` | `habit_name` |
  /// `duration` | `showup_duration` | `schedule` | `reminder` | `summary`.
  final String lastStep;

  @override
  String get name => 'pact_wizard_abandoned';

  @override
  Map<String, Object?> toParameters() => {
        'mode': mode,
        'last_step': lastStep,
      };
}

/// Fired when the user completes the edit pact wizard and the updated pact is
/// persisted successfully. (HAB-79)
final class PactEditSavedEvent extends AnalyticsEvent {
  PactEditSavedEvent({
    required this.pactId,
    required this.habitNameChanged,
    required this.reminderChanged,
    this.newReminderOffsetMinutes,
    required this.usedSummaryJump,
  });

  /// ID of the pact that was edited.
  final String pactId;

  /// `true` if the habit name was modified from its original value.
  final bool habitNameChanged;

  /// `true` if the reminder offset was modified from its original value.
  final bool reminderChanged;

  /// Resulting reminder offset in minutes; `null` if no reminder after the edit.
  final int? newReminderOffsetMinutes;

  /// `true` if the user tapped at least one Summary-screen row to jump back.
  final bool usedSummaryJump;

  @override
  String get name => 'pact_edit_saved';

  @override
  Map<String, Object?> toParameters() => {
        'pact_id': pactId,
        'habit_name_changed': habitNameChanged,
        'reminder_changed': reminderChanged,
        if (newReminderOffsetMinutes != null) 'new_reminder_offset_minutes': newReminderOffsetMinutes!,
        'used_summary_jump': usedSummaryJump,
      };
}

/// Fired when the user saves a note on an inactive pact detail screen. (HAB-115)
final class PactNoteSavedEvent extends AnalyticsEvent {
  PactNoteSavedEvent({
    required this.pactId,
    required this.pactStatus,
    required this.noteLength,
    required this.wasEdit,
  });

  final String pactId;

  /// `completed` | `stopped`
  final String pactStatus;

  /// Character count of the saved note; `0` means the note was cleared.
  final int noteLength;

  /// `true` if a non-empty note already existed before this save.
  final bool wasEdit;

  @override
  String get name => 'pact_note_saved';

  @override
  Map<String, Object?> toParameters() => {
        'pact_id': pactId,
        'pact_status': pactStatus,
        'note_length': noteLength,
        'was_edit': wasEdit,
      };
}

/// Fired when the user archives a pact. (HAB-114)
final class PactArchivedEvent extends AnalyticsEvent {
  PactArchivedEvent({required this.pactId, required this.pactStatus, required this.source});

  /// ID of the archived pact.
  final String pactId;

  /// `completed` | `stopped`
  final String pactStatus;

  /// `detail_screen` | `pact_list_swipe`
  final String source;

  @override
  String get name => 'pact_archived';

  @override
  Map<String, Object?> toParameters() => {
        'pact_id': pactId,
        'pact_status': pactStatus,
        'source': source,
      };
}

/// Fired when the user unarchives a pact. (HAB-114)
final class PactUnarchivedEvent extends AnalyticsEvent {
  PactUnarchivedEvent({required this.pactId, required this.pactStatus, required this.source});

  /// ID of the unarchived pact.
  final String pactId;

  /// `completed` | `stopped`
  final String pactStatus;

  /// `detail_screen` | `pact_list_swipe`
  final String source;

  @override
  String get name => 'pact_unarchived';

  @override
  Map<String, Object?> toParameters() => {
        'pact_id': pactId,
        'pact_status': pactStatus,
        'source': source,
      };
}

/// Screen identifier for the pact creation wizard.
class PactCreationAnalyticsScreen implements AnalyticsScreen {
  const PactCreationAnalyticsScreen();

  @override
  String get name => 'pact_creation';
}

/// Screen identifier for the pact detail screen.
class PactDetailAnalyticsScreen implements AnalyticsScreen {
  const PactDetailAnalyticsScreen();

  @override
  String get name => 'pact_detail';
}

/// Screen identifier for the edit pact wizard. (HAB-79)
class PactEditAnalyticsScreen implements AnalyticsScreen {
  const PactEditAnalyticsScreen();

  @override
  String get name => 'pact_edit';
}

/// Screen identifier for the wizard summary page.
///
/// `mode` is passed as a constructor parameter and forwarded as a screen
/// property so creation and editing funnels can be distinguished in analytics.
/// (HAB-82)
class PactWizardSummaryAnalyticsScreen implements AnalyticsScreen {
  const PactWizardSummaryAnalyticsScreen({required this.mode});

  /// `creation` | `editing`.
  final String mode;

  @override
  String get name => 'pact_wizard_summary';
}
