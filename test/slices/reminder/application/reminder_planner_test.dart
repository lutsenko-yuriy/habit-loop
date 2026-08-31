import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/reminder/application/notification_text_builder.dart';
import 'package:habit_loop/slices/reminder/application/reminder_plan_context.dart';
import 'package:habit_loop/slices/reminder/application/reminder_planner.dart';

Pact _makePact({Duration? reminderOffset}) {
  return Pact(
    id: 'pact-1',
    habitName: 'Meditate',
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 6, 30),
    showupDuration: const Duration(minutes: 20),
    schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
    status: PactStatus.active,
    reminderOffset: reminderOffset,
    createdAt: DateTime(2026, 1, 1),
  );
}

Showup _makeShowup({
  required String id,
  required DateTime scheduledAt,
  ShowupStatus status = ShowupStatus.pending,
  Duration duration = const Duration(minutes: 20),
}) {
  return Showup(
    id: id,
    pactId: 'pact-1',
    scheduledAt: scheduledAt,
    duration: duration,
    status: status,
  );
}

// Matches the pre-refactor defaults (welcome-back on, hurry-up/deadline off)
// so most tests only need to override the one field they're exercising.
const _kDefaultContext = ReminderPlanContext(
  textVariant: 'control',
  scheduleDeadline: false,
  hurryUpEnabled: false,
  hurryUpTime: Duration(minutes: 5),
  welcomeBackEnabled: true,
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() {
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  group('plan', () {
    test('returns nothing when pact has no reminder offset', () {
      final pact = _makePact(reminderOffset: null);
      final now = DateTime(2026, 5, 1, 9, 0);
      final showups = [_makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 2, 8, 0))];

      final plan = ReminderPlanner.plan(
        pact: pact,
        showups: showups,
        now: now,
        l10n: l10n,
        breaks: const [],
        context: _kDefaultContext,
        isIOS: false,
      );

      expect(plan, isEmpty);
    });

    test('plans only future pending showups', () {
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      final showups = [
        _makeShowup(id: 'su-past', scheduledAt: DateTime(2026, 5, 6, 8, 0)),
        _makeShowup(id: 'su-future', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
        _makeShowup(id: 'su-done', scheduledAt: DateTime(2026, 5, 9, 8, 0), status: ShowupStatus.done),
        _makeShowup(id: 'su-failed', scheduledAt: DateTime(2026, 5, 10, 8, 0), status: ShowupStatus.failed),
      ];

      final plan = ReminderPlanner.plan(
        pact: pact,
        showups: showups,
        now: now,
        l10n: l10n,
        breaks: const [],
        context: _kDefaultContext,
        isIOS: false,
      );

      expect(plan, hasLength(1));
      expect(plan.first.showup.id, equals('su-future'));
    });

    test('skips a showup whose reminder fire time is already in the past', () {
      final pact = _makePact(reminderOffset: const Duration(minutes: 60));
      final now = DateTime(2026, 5, 8, 9, 0);
      final showups = [_makeShowup(id: 'su-future-but-reminder-past', scheduledAt: DateTime(2026, 5, 8, 9, 30))];

      final plan = ReminderPlanner.plan(
        pact: pact,
        showups: showups,
        now: now,
        l10n: l10n,
        breaks: const [],
        context: _kDefaultContext,
        isIOS: false,
      );

      expect(plan, isEmpty);
    });

    test('scheduleDeadline=false plans only the reminder, no deadline', () {
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final showups = [_makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0))];

      final plan = ReminderPlanner.plan(
        pact: pact,
        showups: showups,
        now: now,
        l10n: l10n,
        breaks: const [],
        context: _kDefaultContext,
        isIOS: false,
      );

      expect(plan.first.includeDeadline, isFalse);
      expect(plan.first.deadline, isNull);
    });

    test('scheduleDeadline=true plans both reminder and deadline', () {
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final showups = [_makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0))];

      final plan = ReminderPlanner.plan(
        pact: pact,
        showups: showups,
        now: now,
        l10n: l10n,
        breaks: const [],
        context: const ReminderPlanContext(
          textVariant: 'control',
          scheduleDeadline: true,
          hurryUpEnabled: false,
          hurryUpTime: Duration(minutes: 5),
          welcomeBackEnabled: true,
        ),
        isIOS: false,
      );

      final expected = NotificationTextBuilder.buildDeadlineExpiredText(l10n: l10n);
      expect(plan.first.includeDeadline, isTrue);
      expect(plan.first.deadline!.title, expected.title);
      expect(plan.first.deadline!.body, expected.body);
    });

    test('uses the given text variant for reminder text', () {
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final showups = [_makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0))];

      final plan = ReminderPlanner.plan(
        pact: pact,
        showups: showups,
        now: now,
        l10n: l10n,
        breaks: const [],
        context: const ReminderPlanContext(
          textVariant: 'deadline',
          scheduleDeadline: false,
          hurryUpEnabled: false,
          hurryUpTime: Duration(minutes: 5),
          welcomeBackEnabled: true,
        ),
        isIOS: false,
      );

      expect(plan.first.reminderTitle, contains('Meditate'));
    });

    group('on-break suppression (HAB-195 WU3)', () {
      test('does not plan a reminder for a showup inside an active break window', () {
        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final showups = [
          _makeShowup(id: 'su-onbreak', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
          _makeShowup(id: 'su-offbreak', scheduledAt: DateTime(2026, 5, 20, 8, 0)),
        ];
        final breaks = [
          PactBreak(
            id: 'brk-1',
            pactId: 'pact-1',
            startDate: DateTime(2026, 5, 5),
            plannedEndDate: DateTime(2026, 5, 10),
            rationale: 'Traveling',
          ),
        ];

        final plan = ReminderPlanner.plan(
          pact: pact,
          showups: showups,
          now: now,
          l10n: l10n,
          breaks: breaks,
          context: _kDefaultContext,
          isIOS: false,
        );

        expect(plan, hasLength(1));
        expect(plan.first.showup.id, equals('su-offbreak'));
      });
    });

    group('iOS 64-notification cap', () {
      test('caps planned showups at 32 (64 notifications / 2 per showup) when isIOS + scheduleDeadline', () {
        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final showups = List.generate(
          40,
          (i) => _makeShowup(id: 'su-$i', scheduledAt: DateTime(2026, 5, 8 + i, 8, 0)),
        );

        final plan = ReminderPlanner.plan(
          pact: pact,
          showups: showups,
          now: now,
          l10n: l10n,
          breaks: const [],
          context: const ReminderPlanContext(
            textVariant: 'control',
            scheduleDeadline: true,
            hurryUpEnabled: false,
            hurryUpTime: Duration(minutes: 5),
            welcomeBackEnabled: true,
          ),
          isIOS: true,
        );

        expect(plan, hasLength(32));
      });

      test('no cap when isIOS=false', () {
        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final showups = List.generate(
          40,
          (i) => _makeShowup(id: 'su-$i', scheduledAt: DateTime(2026, 5, 8 + i, 8, 0)),
        );

        final plan = ReminderPlanner.plan(
          pact: pact,
          showups: showups,
          now: now,
          l10n: l10n,
          breaks: const [],
          context: _kDefaultContext,
          isIOS: false,
        );

        expect(plan, hasLength(40));
      });
    });

    group('welcome-back reminder text (HAB-227)', () {
      test('the first showup after a fixed-end break gets welcome-back text', () {
        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final breaks = [
          PactBreak(
            id: 'brk-1',
            pactId: 'pact-1',
            startDate: DateTime(2026, 5, 5),
            plannedEndDate: DateTime(2026, 5, 10),
            rationale: 'Traveling',
          ),
        ];
        final target = ShowupGenerator.generateWindow(
          pact,
          from: DateTime(2026, 5, 11, 8),
          to: DateTime(2026, 5, 11, 8, 1),
        ).first;

        final plan = ReminderPlanner.plan(
          pact: pact,
          showups: [target],
          now: now,
          l10n: l10n,
          breaks: breaks,
          context: _kDefaultContext,
          isIOS: false,
        );

        final expected = NotificationTextBuilder.buildWelcomeBackText(habitName: pact.habitName, l10n: l10n);
        expect(plan.first.reminderTitle, expected.title);
        expect(plan.first.reminderBody, expected.body);
      });

      test('welcome-back text is skipped when welcomeBackEnabled=false', () {
        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final breaks = [
          PactBreak(
            id: 'brk-1',
            pactId: 'pact-1',
            startDate: DateTime(2026, 5, 5),
            plannedEndDate: DateTime(2026, 5, 10),
            rationale: 'Traveling',
          ),
        ];
        final target = ShowupGenerator.generateWindow(
          pact,
          from: DateTime(2026, 5, 11, 8),
          to: DateTime(2026, 5, 11, 8, 1),
        ).first;

        final plan = ReminderPlanner.plan(
          pact: pact,
          showups: [target],
          now: now,
          l10n: l10n,
          breaks: breaks,
          context: const ReminderPlanContext(
            textVariant: 'control',
            scheduleDeadline: false,
            hurryUpEnabled: false,
            hurryUpTime: Duration(minutes: 5),
            welcomeBackEnabled: false,
          ),
          isIOS: false,
        );

        final normal = NotificationTextBuilder.buildReminderText(
          variant: 'control',
          habitName: pact.habitName,
          scheduledAt: target.scheduledAt,
          showupDuration: target.duration,
          l10n: l10n,
        );
        expect(plan.first.reminderTitle, normal.title);
      });
    });

    group('hurry-up notification (HAB-246)', () {
      test('does not plan a hurry-up when hurryUpEnabled=false', () {
        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final showups = [
          _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0), duration: const Duration(minutes: 30)),
        ];

        final plan = ReminderPlanner.plan(
          pact: pact,
          showups: showups,
          now: now,
          l10n: l10n,
          breaks: const [],
          context: _kDefaultContext,
          isIOS: false,
        );

        expect(plan.first.includeHurryUp, isFalse);
        expect(plan.first.hurryUp, isNull);
      });

      test('plans a hurry-up when eligible (duration >= 3x hurryUpTime, still future)', () {
        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final showups = [
          _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0), duration: const Duration(minutes: 30)),
        ];

        final plan = ReminderPlanner.plan(
          pact: pact,
          showups: showups,
          now: now,
          l10n: l10n,
          breaks: const [],
          context: const ReminderPlanContext(
            textVariant: 'control',
            scheduleDeadline: false,
            hurryUpEnabled: true,
            hurryUpTime: Duration(minutes: 5),
            welcomeBackEnabled: true,
          ),
          isIOS: false,
        );

        expect(plan.first.includeHurryUp, isTrue);
        expect(plan.first.hurryUp!.offset, equals(const Duration(minutes: 5)));
        expect(plan.first.hurryUp!.title, isNotEmpty);
        expect(plan.first.hurryUp!.body, isNotEmpty);
      });

      test('does not plan a hurry-up when duration is just under 3x hurryUpTime', () {
        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final showups = [
          _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0), duration: const Duration(minutes: 14)),
        ];

        final plan = ReminderPlanner.plan(
          pact: pact,
          showups: showups,
          now: now,
          l10n: l10n,
          breaks: const [],
          context: const ReminderPlanContext(
            textVariant: 'control',
            scheduleDeadline: false,
            hurryUpEnabled: true,
            hurryUpTime: Duration(minutes: 5),
            welcomeBackEnabled: true,
          ),
          isIOS: false,
        );

        expect(plan.first.includeHurryUp, isFalse);
      });
    });

    group('iOS budget: chronological spend (HAB-246)', () {
      test('all-eligible showups plan 21 (64 / 3 per showup: reminder + deadline + hurry-up)', () {
        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final showups = List.generate(40, (i) => _makeShowup(id: 'su-$i', scheduledAt: DateTime(2026, 5, 8 + i, 8, 0)));

        final plan = ReminderPlanner.plan(
          pact: pact,
          showups: showups,
          now: now,
          l10n: l10n,
          breaks: const [],
          context: const ReminderPlanContext(
            textVariant: 'control',
            scheduleDeadline: true,
            hurryUpEnabled: true,
            hurryUpTime: Duration(minutes: 5),
            welcomeBackEnabled: true,
          ),
          isIOS: true,
        );

        expect(plan, hasLength(21));
        expect(plan.every((p) => p.includeHurryUp), isTrue);
      });
    });

    group('displayName personalization (HAB-232 WU7)', () {
      test('reminder title contains the name when the context carries one', () {
        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final showups = [_makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0))];

        final plan = ReminderPlanner.plan(
          pact: pact,
          showups: showups,
          now: now,
          l10n: l10n,
          breaks: const [],
          context: const ReminderPlanContext(
            textVariant: 'control',
            scheduleDeadline: true,
            hurryUpEnabled: true,
            hurryUpTime: Duration(minutes: 5),
            welcomeBackEnabled: true,
            displayName: 'Alex',
          ),
          isIOS: false,
        );

        expect(plan.first.reminderTitle, contains('Alex'));
        expect(plan.first.deadline!.title, contains('Alex'));
      });

      test('reminder title has no name when the context carries none', () {
        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final showups = [_makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0))];

        final plan = ReminderPlanner.plan(
          pact: pact,
          showups: showups,
          now: now,
          l10n: l10n,
          breaks: const [],
          context: _kDefaultContext,
          isIOS: false,
        );

        expect(plan.first.reminderTitle, l10n.notificationReminderTitle(pact.habitName));
      });
    });

    group('PlannedReminder equality', () {
      test('two plans over identical inputs compare equal by value', () {
        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final showups = [_makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0))];

        final planA = ReminderPlanner.plan(
          pact: pact,
          showups: showups,
          now: now,
          l10n: l10n,
          breaks: const [],
          context: _kDefaultContext,
          isIOS: false,
        );
        final planB = ReminderPlanner.plan(
          pact: pact,
          showups: showups,
          now: now,
          l10n: l10n,
          breaks: const [],
          context: _kDefaultContext,
          isIOS: false,
        );

        expect(planA.single, equals(planB.single));
        expect(planA.single.hashCode, equals(planB.single.hashCode));
      });
    });
  });
}
