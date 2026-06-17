import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_screen.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';

void main() {
  group('PactCreatedEvent', () {
    test('has correct name', () {
      final event = PactCreatedEvent(
        scheduleType: 'daily',
        durationDays: 180,
        showupDurationMinutes: 10,
        showupsExpected: 180,
        usedSummaryJump: false,
        commitmentVariant: 'button',
      );
      expect(event.name, 'pact_created');
    });

    test('toParameters includes all non-null properties', () {
      final event = PactCreatedEvent(
        scheduleType: 'weekly',
        durationDays: 90,
        showupDurationMinutes: 30,
        reminderOffsetMinutes: 15,
        showupsExpected: 52,
        usedSummaryJump: true,
        commitmentVariant: 'checkbox',
      );
      final params = event.toParameters();
      expect(params['schedule_type'], 'weekly');
      expect(params['duration_days'], 90);
      expect(params['showup_duration_minutes'], 30);
      expect(params['reminder_offset_minutes'], 15);
      expect(params['showups_expected'], 52);
      expect(params['used_summary_jump'], true);
      expect(params['commitment_variant'], 'checkbox');
    });

    test('toParameters omits null reminder_offset_minutes', () {
      final event = PactCreatedEvent(
        scheduleType: 'monthly',
        durationDays: 180,
        showupDurationMinutes: 20,
        showupsExpected: 24,
        usedSummaryJump: false,
        commitmentVariant: 'retype',
      );
      final params = event.toParameters();
      expect(params.containsKey('reminder_offset_minutes'), isFalse);
    });

    test('toParameters includes used_summary_jump false', () {
      final event = PactCreatedEvent(
        scheduleType: 'daily',
        durationDays: 180,
        showupDurationMinutes: 10,
        showupsExpected: 180,
        usedSummaryJump: false,
        commitmentVariant: 'button',
      );
      final params = event.toParameters();
      expect(params['used_summary_jump'], false);
    });

    test('toParameters includes commitment_variant', () {
      for (final variant in ['button', 'checkbox', 'retype']) {
        final event = PactCreatedEvent(
          scheduleType: 'daily',
          durationDays: 180,
          showupDurationMinutes: 10,
          showupsExpected: 180,
          usedSummaryJump: false,
          commitmentVariant: variant,
        );
        expect(event.toParameters()['commitment_variant'], variant);
      }
    });

    test('toParameters does not contain null values', () {
      final event = PactCreatedEvent(
        scheduleType: 'daily',
        durationDays: 180,
        showupDurationMinutes: 10,
        showupsExpected: 180,
        usedSummaryJump: false,
        commitmentVariant: 'button',
      );
      final params = event.toParameters();
      expect(params.values.whereType<Null>(), isEmpty);
    });
  });

  group('PactStoppedEvent', () {
    test('has correct name', () {
      final event = PactStoppedEvent(
        daysActive: 30,
        totalShowupsDone: 25,
        totalShowupsFailed: 3,
        totalShowupsRemaining: 2,
      );
      expect(event.name, 'pact_stopped');
    });

    test('toParameters includes all properties', () {
      final event = PactStoppedEvent(
        daysActive: 30,
        totalShowupsDone: 25,
        totalShowupsFailed: 3,
        totalShowupsRemaining: 2,
      );
      final params = event.toParameters();
      expect(params['days_active'], 30);
      expect(params['total_showups_done'], 25);
      expect(params['total_showups_failed'], 3);
      expect(params['total_showups_remaining'], 2);
    });
  });

  group('PactCommitmentDialogDismissedEvent', () {
    test('has correct name', () {
      final event = PactCommitmentDialogDismissedEvent(variant: 'button');
      expect(event.name, 'pact_commitment_dialog_dismissed');
    });

    test('toParameters includes variant', () {
      for (final variant in ['button', 'checkbox', 'retype']) {
        final event = PactCommitmentDialogDismissedEvent(variant: variant);
        expect(event.toParameters()['variant'], variant);
      }
    });

    test('toParameters contains only variant key', () {
      final event = PactCommitmentDialogDismissedEvent(variant: 'checkbox');
      expect(event.toParameters().length, 1);
    });
  });

  group('PactWizardStepJumpedEvent', () {
    test('has correct name', () {
      final event = PactWizardStepJumpedEvent(stepName: 'habit_name', mode: 'creation');
      expect(event.name, 'pact_wizard_step_jumped');
    });

    test('toParameters includes step_name and mode', () {
      final event = PactWizardStepJumpedEvent(stepName: 'duration', mode: 'editing');
      final params = event.toParameters();
      expect(params['step_name'], 'duration');
      expect(params['mode'], 'editing');
    });

    test('valid step_name values', () {
      const validNames = ['habit_name', 'duration', 'showup_duration', 'schedule', 'reminder'];
      for (final name in validNames) {
        final event = PactWizardStepJumpedEvent(stepName: name, mode: 'creation');
        expect(event.toParameters()['step_name'], name);
      }
    });

    test('valid mode values', () {
      for (final mode in ['creation', 'editing']) {
        final event = PactWizardStepJumpedEvent(stepName: 'schedule', mode: mode);
        expect(event.toParameters()['mode'], mode);
      }
    });
  });

  group('PactWizardAbandonedEvent', () {
    test('has correct name', () {
      final event = PactWizardAbandonedEvent(mode: 'creation', lastStep: 'schedule');
      expect(event.name, 'pact_wizard_abandoned');
    });

    test('toParameters includes mode and last_step', () {
      final event = PactWizardAbandonedEvent(mode: 'creation', lastStep: 'summary');
      final params = event.toParameters();
      expect(params['mode'], 'creation');
      expect(params['last_step'], 'summary');
    });

    test('valid last_step values', () {
      const validSteps = [
        'commitment',
        'habit_name',
        'duration',
        'showup_duration',
        'schedule',
        'reminder',
        'summary',
      ];
      for (final step in validSteps) {
        final event = PactWizardAbandonedEvent(mode: 'creation', lastStep: step);
        expect(event.toParameters()['last_step'], step);
      }
    });
  });

  group('PactCreationAnalyticsScreen', () {
    test('implements AnalyticsScreen', () {
      expect(const PactCreationAnalyticsScreen(), isA<AnalyticsScreen>());
    });

    test('name is pact_creation', () {
      expect(const PactCreationAnalyticsScreen().name, 'pact_creation');
    });
  });

  group('PactNoteSavedEvent', () {
    test('has correct name', () {
      final event = PactNoteSavedEvent(pactId: 'p1', pactStatus: 'stopped', noteLength: 12, wasEdit: false);
      expect(event.name, 'pact_note_saved');
    });

    test('toParameters includes all fields', () {
      final event = PactNoteSavedEvent(pactId: 'p1', pactStatus: 'completed', noteLength: 42, wasEdit: true);
      final params = event.toParameters();
      expect(params['pact_id'], 'p1');
      expect(params['pact_status'], 'completed');
      expect(params['note_length'], 42);
      expect(params['was_edit'], true);
    });

    test('toParameters note_length is 0 when note was cleared', () {
      final event = PactNoteSavedEvent(pactId: 'p1', pactStatus: 'stopped', noteLength: 0, wasEdit: true);
      expect(event.toParameters()['note_length'], 0);
    });
  });

  group('PactDetailAnalyticsScreen', () {
    test('implements AnalyticsScreen', () {
      expect(const PactDetailAnalyticsScreen(), isA<AnalyticsScreen>());
    });

    test('name is pact_detail', () {
      expect(const PactDetailAnalyticsScreen().name, 'pact_detail');
    });
  });

  group('PactWizardSummaryAnalyticsScreen', () {
    test('implements AnalyticsScreen', () {
      expect(const PactWizardSummaryAnalyticsScreen(mode: 'creation'), isA<AnalyticsScreen>());
    });

    test('name is pact_wizard_summary', () {
      expect(const PactWizardSummaryAnalyticsScreen(mode: 'creation').name, 'pact_wizard_summary');
      expect(const PactWizardSummaryAnalyticsScreen(mode: 'editing').name, 'pact_wizard_summary');
    });

    test('mode is passed as screen property', () {
      const screen = PactWizardSummaryAnalyticsScreen(mode: 'editing');
      expect(screen.mode, 'editing');
    });
  });
}
