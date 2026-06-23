import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_state.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_timeline_page_ios.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

final _anchorStart = PactCreatedMilestone(
  sortAt: DateTime(2024, 1, 1),
  habitName: 'Meditate',
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  plannedEndDate: DateTime(2024, 3, 31),
);

final _currentState = CurrentStateMilestone(
  sortAt: DateTime(2024, 2, 15),
  showupsRemaining: 5,
  plannedEndDate: DateTime(2024, 3, 31),
  nextScheduledAt: DateTime(2024, 2, 16, 8),
);

final _concluded = PactConcludedMilestone(
  sortAt: DateTime(2024, 2, 1),
  concludedAt: DateTime(2024, 2, 1),
  finalStatus: PactStatus.stopped,
);

final _streak = ShowupStreakMilestone(
  sortAt: DateTime(2024, 1, 10),
  outcome: ShowupStatus.done,
  count: 10,
  firstAt: DateTime(2024, 1, 1),
  lastAt: DateTime(2024, 1, 10),
);

final _noted = NotedShowupMilestone(
  sortAt: DateTime(2024, 1, 20),
  showupId: 'noted-1',
  scheduledAt: DateTime(2024, 1, 20, 8),
  outcome: ShowupStatus.done,
  note: 'Best session ever',
);

final _single = SingleShowupMilestone(
  sortAt: DateTime(2024, 1, 25),
  showupId: 'single-1',
  outcome: ShowupStatus.done,
  scheduledAt: DateTime(2024, 1, 25, 8),
);

final _group = ShowupGroupMilestone(
  sortAt: DateTime(2024, 1, 15),
  total: 5,
  doneCount: 3,
  failedCount: 2,
  firstAt: DateTime(2024, 1, 11),
  lastAt: DateTime(2024, 1, 15),
);

Widget _buildApp(PactTimelineState state, {void Function(PactTimelineMilestone)? onMilestoneTapped}) {
  return MaterialApp(
    theme: HabitLoopTheme.materialTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: PactTimelinePageIos(
      state: state,
      onMilestoneTapped: onMilestoneTapped,
    ),
  );
}

PactTimelineState _loaded({
  List<PactTimelineMilestone> milestones = const [],
  PactTimelineMilestone? anchorEnd,
}) =>
    PactTimelineState(
      anchorStart: _anchorStart,
      anchorEnd: anchorEnd ?? _currentState,
      milestones: milestones,
      isLoading: false,
    );

void main() {
  group('PactTimelinePageIos — loading / error', () {
    testWidgets('shows activity indicator while loading', (tester) async {
      await tester.pumpWidget(_buildApp(const PactTimelineState(isLoading: true)));
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });

    testWidgets('shows error text when loadError is set', (tester) async {
      const state = PactTimelineState(isLoading: false, loadError: 'Something went wrong');
      await tester.pumpWidget(_buildApp(state));
      await tester.pump();
      expect(find.text('Something went wrong'), findsOneWidget);
    });
  });

  group('PactTimelinePageIos — anchors and milestones', () {
    testWidgets('shows nav bar with timeline title', (tester) async {
      await tester.pumpWidget(_buildApp(_loaded()));
      await tester.pump();
      final l10n = AppLocalizations.of(tester.element(find.byType(PactTimelinePageIos)))!;
      expect(find.text(l10n.pactTimelineTitle), findsWidgets);
    });

    testWidgets('shows pact habit name from anchor-start', (tester) async {
      await tester.pumpWidget(_buildApp(_loaded()));
      await tester.pump();
      expect(find.text('Meditate'), findsWidgets);
    });

    testWidgets('shows current-state anchor label for active pact', (tester) async {
      await tester.pumpWidget(_buildApp(_loaded(anchorEnd: _currentState)));
      await tester.pump();
      final l10n = AppLocalizations.of(tester.element(find.byType(PactTimelinePageIos)))!;
      expect(find.text(l10n.timelineCurrentState), findsWidgets);
    });

    testWidgets('shows concluded anchor label for stopped pact', (tester) async {
      await tester.pumpWidget(_buildApp(_loaded(anchorEnd: _concluded)));
      await tester.pump();
      final l10n = AppLocalizations.of(tester.element(find.byType(PactTimelinePageIos)))!;
      expect(find.text(l10n.timelinePactConcludedStopped), findsWidgets);
    });

    testWidgets('shows streak milestone label', (tester) async {
      await tester.pumpWidget(_buildApp(_loaded(milestones: [_streak])));
      await tester.pump();
      final l10n = AppLocalizations.of(tester.element(find.byType(PactTimelinePageIos)))!;
      expect(find.text(l10n.timelineDoneInARow(10)), findsWidgets);
    });

    testWidgets('shows noted showup note text', (tester) async {
      await tester.pumpWidget(_buildApp(_loaded(milestones: [_noted])));
      await tester.pump();
      expect(find.text('Best session ever'), findsWidgets);
    });

    testWidgets('shows group milestone label with counts', (tester) async {
      await tester.pumpWidget(_buildApp(_loaded(milestones: [_group])));
      await tester.pump();
      final l10n = AppLocalizations.of(tester.element(find.byType(PactTimelinePageIos)))!;
      expect(find.text(l10n.timelineGroup(5, 3, 2)), findsWidgets);
    });
  });

  group('PactTimelinePageIos — tappable milestones', () {
    testWidgets('tapping noted showup calls onMilestoneTapped', (tester) async {
      PactTimelineMilestone? tapped;
      await tester.pumpWidget(_buildApp(
        _loaded(milestones: [_noted]),
        onMilestoneTapped: (m) => tapped = m,
      ));
      await tester.pump();
      await tester.tap(find.byKey(const Key('timeline-milestone-noted-1')));
      expect(tapped, isA<NotedShowupMilestone>());
    });

    testWidgets('tapping single showup calls onMilestoneTapped', (tester) async {
      PactTimelineMilestone? tapped;
      await tester.pumpWidget(_buildApp(
        _loaded(milestones: [_single]),
        onMilestoneTapped: (m) => tapped = m,
      ));
      await tester.pump();
      await tester.tap(find.byKey(const Key('timeline-milestone-single-1')));
      expect(tapped, isA<SingleShowupMilestone>());
    });
  });
}
