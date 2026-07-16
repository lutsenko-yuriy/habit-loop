import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_timeline_page_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_state.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';
import 'package:intl/intl.dart';

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

Widget _buildApp(
  PactTimelineState state, {
  void Function(PactTimelineMilestone)? onMilestoneTapped,
  String? initialHabitName,
}) {
  return MaterialApp(
    theme: HabitLoopTheme.materialTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: PactTimelinePageAndroid(
      state: state,
      onMilestoneTapped: onMilestoneTapped,
      initialHabitName: initialHabitName,
    ),
  );
}

PactTimelineState _loaded({
  List<PactTimelineMilestone> milestones = const [],
  PactTimelineMilestone? anchorEnd,
  int tailStartIndex = 0,
}) =>
    PactTimelineState(
      anchorStart: _anchorStart,
      anchorEnd: anchorEnd ?? _currentState,
      milestones: milestones,
      tailStartIndex: tailStartIndex,
      isLoading: false,
    );

void main() {
  group('PactTimelinePageAndroid — loading / error', () {
    testWidgets('shows activity indicator while loading', (tester) async {
      await tester.pumpWidget(_buildApp(const PactTimelineState(isLoading: true)));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error text when loadError is set', (tester) async {
      const state = PactTimelineState(isLoading: false, loadError: 'Something went wrong');
      await tester.pumpWidget(_buildApp(state));
      await tester.pump();
      expect(find.text('Something went wrong'), findsOneWidget);
    });
  });

  group('PactTimelinePageAndroid — anchors and milestones', () {
    testWidgets('shows app bar with pact name and timeline title', (tester) async {
      await tester.pumpWidget(_buildApp(_loaded()));
      await tester.pump();
      final l10n = AppLocalizations.of(tester.element(find.byType(PactTimelinePageAndroid)))!;
      expect(find.text('${_anchorStart.habitName} – ${l10n.pactTimelineTitle}'), findsWidgets);
    });

    testWidgets('shows pact habit name from anchor-start', (tester) async {
      await tester.pumpWidget(_buildApp(_loaded()));
      await tester.pump();
      expect(find.text('Meditate'), findsWidgets);
    });

    testWidgets('shows initialHabitName in title before anchorStart loads', (tester) async {
      await tester.pumpWidget(
        _buildApp(const PactTimelineState(isLoading: true), initialHabitName: 'Meditate'),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(tester.element(find.byType(PactTimelinePageAndroid)))!;
      expect(find.text('Meditate – ${l10n.pactTimelineTitle}'), findsOneWidget);
    });

    testWidgets('prefers anchorStart habit name over initialHabitName once loaded', (tester) async {
      await tester.pumpWidget(_buildApp(_loaded(), initialHabitName: 'Stale Name'));
      await tester.pump();
      final l10n = AppLocalizations.of(tester.element(find.byType(PactTimelinePageAndroid)))!;
      expect(find.text('${_anchorStart.habitName} – ${l10n.pactTimelineTitle}'), findsWidgets);
      expect(find.text('Stale Name – ${l10n.pactTimelineTitle}'), findsNothing);
    });

    testWidgets('shows current-state anchor label for active pact', (tester) async {
      await tester.pumpWidget(_buildApp(_loaded(anchorEnd: _currentState)));
      await tester.pump();
      final l10n = AppLocalizations.of(tester.element(find.byType(PactTimelinePageAndroid)))!;
      expect(find.text(l10n.timelineCurrentState), findsWidgets);
    });

    testWidgets('shows concluded anchor label for stopped pact', (tester) async {
      await tester.pumpWidget(_buildApp(_loaded(anchorEnd: _concluded)));
      await tester.pump();
      final l10n = AppLocalizations.of(tester.element(find.byType(PactTimelinePageAndroid)))!;
      expect(find.text(l10n.timelinePactConcludedStopped), findsWidgets);
    });

    testWidgets('shows streak milestone label', (tester) async {
      await tester.pumpWidget(_buildApp(_loaded(milestones: [_streak])));
      await tester.pump();
      final l10n = AppLocalizations.of(tester.element(find.byType(PactTimelinePageAndroid)))!;
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
      final l10n = AppLocalizations.of(tester.element(find.byType(PactTimelinePageAndroid)))!;
      expect(find.text(l10n.timelineGroup(5, 3, 2)), findsWidgets);
    });
  });

  group('PactTimelinePageAndroid — section header', () {
    testWidgets('section header appears between grouped and tail milestones', (tester) async {
      // tailStartIndex=1: _streak is non-tail, _single is the first tail item.
      await tester.pumpWidget(_buildApp(_loaded(milestones: [_streak, _single], tailStartIndex: 1)));
      await tester.pump();
      final l10n = AppLocalizations.of(tester.element(find.byType(PactTimelinePageAndroid)))!;
      expect(find.text(l10n.timelineRecentSection(7)), findsOneWidget);
    });

    testWidgets('no section header when all milestones are tail (tailStartIndex == 0)', (tester) async {
      await tester.pumpWidget(_buildApp(_loaded(milestones: [_single], tailStartIndex: 0)));
      await tester.pump();
      final l10n = AppLocalizations.of(tester.element(find.byType(PactTimelinePageAndroid)))!;
      expect(find.text(l10n.timelineRecentSection(7)), findsNothing);
    });
  });

  group('PactTimelinePageAndroid — date positioning', () {
    // In the golden-ratio spine layout the date is in the LEFT column and the
    // outcome label is in the RIGHT column.  We verify horizontal ordering for
    // both M/d/yyyy (en_US) and dd/MM/yyyy (en_GB) date formats.

    for (final locale in [const Locale('en', 'US'), const Locale('en', 'GB')]) {
      final tag = '${locale.languageCode}_${locale.countryCode}';

      testWidgets('date is left of status label for single showup milestone ($tag)', (tester) async {
        tester.binding.platformDispatcher.localeTestValue = locale;
        addTearDown(() => tester.binding.platformDispatcher.clearLocaleTestValue());
        await tester.pumpWidget(_buildApp(_loaded(milestones: [_single])));
        await tester.pump();
        final ctx = tester.element(find.byType(PactTimelinePageAndroid));
        final l10n = AppLocalizations.of(ctx)!;
        final dateStr = DateFormat.yMd(locale.toString()).format(_single.scheduledAt);
        expect(
          tester.getRect(find.text(dateStr)).center.dx,
          lessThan(tester.getRect(find.text(l10n.showupDone)).center.dx),
        );
      });

      testWidgets('date is left of status label for noted showup milestone ($tag)', (tester) async {
        tester.binding.platformDispatcher.localeTestValue = locale;
        addTearDown(() => tester.binding.platformDispatcher.clearLocaleTestValue());
        await tester.pumpWidget(_buildApp(_loaded(milestones: [_noted])));
        await tester.pump();
        final ctx = tester.element(find.byType(PactTimelinePageAndroid));
        final l10n = AppLocalizations.of(ctx)!;
        final dateStr = DateFormat.yMd(locale.toString()).format(_noted.scheduledAt);
        expect(
          tester.getRect(find.text(dateStr)).center.dx,
          lessThan(tester.getRect(find.text(l10n.showupDone)).center.dx),
        );
      });

      testWidgets('date range is left of title for streak milestone ($tag)', (tester) async {
        tester.binding.platformDispatcher.localeTestValue = locale;
        addTearDown(() => tester.binding.platformDispatcher.clearLocaleTestValue());
        await tester.pumpWidget(_buildApp(_loaded(milestones: [_streak])));
        await tester.pump();
        final l10n = AppLocalizations.of(tester.element(find.byType(PactTimelinePageAndroid)))!;
        final fmt = DateFormat.yMd(locale.toString());
        final rangeStr = '${fmt.format(_streak.firstAt)} – ${fmt.format(_streak.lastAt)}';
        final rangeRect = tester.getRect(find.text(rangeStr));
        final titleRect = tester.getRect(find.text(l10n.timelineDoneInARow(_streak.count)));
        expect(rangeRect.center.dx, lessThan(titleRect.center.dx));
      });

      testWidgets('date range is left of title for group milestone ($tag)', (tester) async {
        tester.binding.platformDispatcher.localeTestValue = locale;
        addTearDown(() => tester.binding.platformDispatcher.clearLocaleTestValue());
        await tester.pumpWidget(_buildApp(_loaded(milestones: [_group])));
        await tester.pump();
        final l10n = AppLocalizations.of(tester.element(find.byType(PactTimelinePageAndroid)))!;
        final fmt = DateFormat.yMd(locale.toString());
        final rangeStr = '${fmt.format(_group.firstAt)} – ${fmt.format(_group.lastAt)}';
        final rangeRect = tester.getRect(find.text(rangeStr));
        final titleRect =
            tester.getRect(find.text(l10n.timelineGroup(_group.total, _group.doneCount, _group.failedCount)));
        expect(rangeRect.center.dx, lessThan(titleRect.center.dx));
      });
    }
  });

  group('PactTimelinePageAndroid — tappable milestones', () {
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
