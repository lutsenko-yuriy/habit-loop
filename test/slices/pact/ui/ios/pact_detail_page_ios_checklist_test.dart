import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_state.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_detail_page_ios.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

final _active = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 3, 1),
  endDate: DateTime(2026, 9, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
);

final _stats = PactStats(
  showupsDone: 5,
  showupsFailed: 2,
  showupsRemaining: 10,
  totalShowups: 17,
  currentStreak: 3,
  startDate: DateTime(2026, 3, 1),
  endDate: DateTime(2026, 9, 1),
);

const _marker = Key('checklist-section-marker');

Widget _app(Pact pact, {Widget? checklistSection}) => MaterialApp(
      theme: HabitLoopTheme.materialTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: PactDetailPageIos(
        state: PactDetailState(pact: pact, stats: _stats, isLoading: false),
        onStopPact: (_) async {},
        onSaveNote: (_) async {},
        onArchivePact: (_) async {},
        checklistSection: checklistSection,
      ),
    );

Future<void> _pump(WidgetTester tester, Pact pact, {Widget? section}) async {
  await tester.pumpWidget(_app(pact, checklistSection: section));
  await tester.pumpAndSettle();
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -2000));
  await tester.pumpAndSettle();
}

void main() {
  group('PactDetailPageIos - checklist section slot', () {
    testWidgets('active pact renders the provided checklist section', (tester) async {
      await _pump(tester, _active, section: const SizedBox(key: _marker, height: 40));
      await _scrollToBottom(tester);
      expect(find.byKey(_marker), findsOneWidget);
    });

    testWidgets('active pact without a section (flag off / not installed) renders nothing extra', (tester) async {
      await _pump(tester, _active);
      await _scrollToBottom(tester);
      expect(find.byKey(_marker), findsNothing);
    });

    testWidgets('stopped pact never renders the section even if one is provided', (tester) async {
      await _pump(
        tester,
        _active.copyWith(status: PactStatus.stopped, stoppedAt: DateTime(2026, 4, 1)),
        section: const SizedBox(key: _marker, height: 40),
      );
      await _scrollToBottom(tester);
      expect(find.byKey(_marker), findsNothing);
    });

    testWidgets('stopping the pact fades the section out instead of popping it', (tester) async {
      const section = SizedBox(key: _marker, height: 40);
      await _pump(tester, _active, section: section);
      await _scrollToBottom(tester);
      expect(find.byKey(_marker), findsOneWidget);

      await tester.pumpWidget(
        _app(_active.copyWith(status: PactStatus.stopped, stoppedAt: DateTime(2026, 4, 1)), checklistSection: section),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(_marker), findsOneWidget, reason: 'still collapsing');

      await tester.pumpAndSettle();
      expect(find.byKey(_marker), findsNothing);
    });

    testWidgets('completed pact never renders the section even if one is provided', (tester) async {
      await _pump(tester, _active.copyWith(status: PactStatus.completed), section: const SizedBox(key: _marker));
      await _scrollToBottom(tester);
      expect(find.byKey(_marker), findsNothing);
    });
  });
}
