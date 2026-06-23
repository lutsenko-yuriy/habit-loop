import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_formatters.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

Future<AppLocalizations> _getL10n(WidgetTester tester) async {
  await tester.pumpWidget(_wrap(const SizedBox.shrink()));
  final ctx = tester.element(find.byType(Scaffold));
  return AppLocalizations.of(ctx)!;
}

void main() {
  group('milestoneTitle', () {
    testWidgets('PactCreatedMilestone returns pact-created label', (tester) async {
      final l10n = await _getL10n(tester);
      final m = PactCreatedMilestone(
        sortAt: DateTime(2024, 1, 1),
        habitName: 'Meditate',
        schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
        plannedEndDate: DateTime(2024, 3, 31),
      );
      expect(milestoneTitle(l10n, m), l10n.timelinePactCreated);
    });

    testWidgets('ShowupStreakMilestone done returns done-in-a-row label', (tester) async {
      final l10n = await _getL10n(tester);
      final m = ShowupStreakMilestone(
        sortAt: DateTime(2024, 1, 10),
        outcome: ShowupStatus.done,
        count: 5,
        firstAt: DateTime(2024, 1, 1),
        lastAt: DateTime(2024, 1, 10),
      );
      expect(milestoneTitle(l10n, m), l10n.timelineDoneInARow(5));
    });

    testWidgets('ShowupStreakMilestone failed returns missed-in-a-row label', (tester) async {
      final l10n = await _getL10n(tester);
      final m = ShowupStreakMilestone(
        sortAt: DateTime(2024, 1, 10),
        outcome: ShowupStatus.failed,
        count: 3,
        firstAt: DateTime(2024, 1, 1),
        lastAt: DateTime(2024, 1, 10),
      );
      expect(milestoneTitle(l10n, m), l10n.timelineMissedInARow(3));
    });

    testWidgets('SingleShowupMilestone done returns done label', (tester) async {
      final l10n = await _getL10n(tester);
      final m = SingleShowupMilestone(
        sortAt: DateTime(2024, 1, 5),
        showupId: 's1',
        outcome: ShowupStatus.done,
        scheduledAt: DateTime(2024, 1, 5, 8),
      );
      expect(milestoneTitle(l10n, m), l10n.showupDone);
    });

    testWidgets('SingleShowupMilestone failed returns failed label', (tester) async {
      final l10n = await _getL10n(tester);
      final m = SingleShowupMilestone(
        sortAt: DateTime(2024, 1, 5),
        showupId: 's1',
        outcome: ShowupStatus.failed,
        scheduledAt: DateTime(2024, 1, 5, 8),
      );
      expect(milestoneTitle(l10n, m), l10n.showupFailed);
    });

    testWidgets('ShowupGroupMilestone returns group label', (tester) async {
      final l10n = await _getL10n(tester);
      final m = ShowupGroupMilestone(
        sortAt: DateTime(2024, 1, 5),
        total: 5,
        doneCount: 3,
        failedCount: 2,
        firstAt: DateTime(2024, 1, 1),
        lastAt: DateTime(2024, 1, 5),
      );
      expect(milestoneTitle(l10n, m), l10n.timelineGroup(5, 3, 2));
    });

    testWidgets('NotedShowupMilestone done returns done label', (tester) async {
      final l10n = await _getL10n(tester);
      final m = NotedShowupMilestone(
        sortAt: DateTime(2024, 1, 5),
        showupId: 's1',
        scheduledAt: DateTime(2024, 1, 5, 8),
        outcome: ShowupStatus.done,
        note: 'Felt great',
      );
      expect(milestoneTitle(l10n, m), l10n.showupDone);
    });

    testWidgets('CurrentStateMilestone returns active label', (tester) async {
      final l10n = await _getL10n(tester);
      final m = CurrentStateMilestone(
        sortAt: DateTime(2024, 2, 15),
        showupsRemaining: 10,
        plannedEndDate: DateTime(2024, 3, 31),
      );
      expect(milestoneTitle(l10n, m), l10n.timelineCurrentState);
    });

    testWidgets('PactConcludedMilestone completed returns completed label', (tester) async {
      final l10n = await _getL10n(tester);
      final m = PactConcludedMilestone(
        sortAt: DateTime(2024, 3, 31),
        concludedAt: DateTime(2024, 3, 31),
        finalStatus: PactStatus.completed,
      );
      expect(milestoneTitle(l10n, m), l10n.timelinePactConcludedCompleted);
    });

    testWidgets('PactConcludedMilestone stopped returns stopped label', (tester) async {
      final l10n = await _getL10n(tester);
      final m = PactConcludedMilestone(
        sortAt: DateTime(2024, 2, 1),
        concludedAt: DateTime(2024, 2, 1),
        finalStatus: PactStatus.stopped,
      );
      expect(milestoneTitle(l10n, m), l10n.timelinePactConcludedStopped);
    });
  });

  group('milestoneDateRange', () {
    testWidgets('ShowupStreakMilestone single day shows one date', (tester) async {
      await _getL10n(tester);
      final ctx = tester.element(find.byType(Scaffold));
      final m = ShowupStreakMilestone(
        sortAt: DateTime(2024, 1, 5),
        outcome: ShowupStatus.done,
        count: 1,
        firstAt: DateTime(2024, 1, 5),
        lastAt: DateTime(2024, 1, 5),
      );
      final range = milestoneDateRange(ctx, m);
      expect(range, isNotEmpty);
    });
  });
}
