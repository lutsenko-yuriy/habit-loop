import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_body.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';

Showup _showup(String id) => Showup(
      id: id,
      pactId: 'p-1',
      scheduledAt: DateTime(2026, 6, 8, 9, 0),
      duration: const Duration(minutes: 30),
      status: ShowupStatus.pending,
      note: null,
    );

DashboardState _state(List<Showup> showups) {
  final days = List.generate(
      7,
      (i) => CalendarDayEntry(
            date: DateTime(2026, 6, i + 2),
            showups: i == 3 ? showups : [],
          ));
  return DashboardState(
    calendarDays: days,
    selectedDayIndex: 3,
    isLoading: false,
    pactNames: {'p-1': 'Meditate'},
    todayIndex: 3,
  );
}

Widget _wrap(
  DashboardState state, {
  bool hasPacts = true,
  ValueChanged<int>? onDaySelected,
  Future<void> Function(String)? onShowupTapped,
  TextScaler? textScaler,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: textScaler == null
        ? null
        : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
    home: Scaffold(
      body: DashboardBody(
        state: state,
        hasPacts: hasPacts,
        statusColors: ShowupStatusColors.material(ThemeData().colorScheme),
        separator: const Divider(key: Key('test-separator')),
        noPactsTextColor: Colors.grey,
        onCreatePact: () async {},
        onDaySelected: onDaySelected ?? (_) {},
        onShowupTapped: onShowupTapped ?? (_) async {},
        buildShowupTile: (ctx, showup, habitName, onTap) => GestureDetector(
          key: Key('tile-${showup.id}'),
          onTap: onTap,
          child: Text(habitName),
        ),
        buildNoPactsCta: (ctx, createPact) => ElevatedButton(
          key: const Key('no-pacts-cta-button'),
          onPressed: createPact,
          child: const Text('Create'),
        ),
      ),
    ),
  );
}

void main() {
  group('DashboardBody — calendar strip', () {
    testWidgets('renders a day number for each calendar entry', (tester) async {
      await tester.pumpWidget(_wrap(_state([])));
      await tester.pump();
      for (int i = 2; i <= 8; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
    });

    testWidgets('calls onDaySelected with the tapped index', (tester) async {
      int? selected;
      await tester.pumpWidget(_wrap(_state([]), onDaySelected: (i) => selected = i));
      await tester.pump();
      await tester.tap(find.text('2'));
      expect(selected, 0);
    });
  });

  group('DashboardBody — calendar strip accessibility', () {
    testWidgets('day buttons meet the Android and iOS tap-target guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(_state([])));
      await tester.pump();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('selected day exposes a selected semantics flag', (tester) async {
      final handle = tester.ensureSemantics();
      final days = List.generate(
          7,
          (i) => CalendarDayEntry(
                date: DateTime(2026, 6, i + 2),
                showups: const [],
              ));
      final state = DashboardState(
        calendarDays: days,
        selectedDayIndex: 3,
        isLoading: false,
        pactNames: const {},
        todayIndex: 6, // deliberately distinct from selectedDayIndex/index 0 so "today" wording doesn't leak in
      );
      await tester.pumpWidget(_wrap(state));
      await tester.pump();

      expect(
        tester.getSemantics(find.text('5')), // selectedDayIndex is 3 → date 2026-06-05
        matchesSemantics(
          label: 'Friday, June 5, 2026',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('2')),
        matchesSemantics(
          label: 'Tuesday, June 2, 2026',
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('today carries a distinct semantic label from other days', (tester) async {
      final handle = tester.ensureSemantics();
      final days = List.generate(
          7,
          (i) => CalendarDayEntry(
                date: DateTime(2026, 6, i + 2),
                showups: const [],
              ));
      final state = DashboardState(
        calendarDays: days,
        selectedDayIndex: 3,
        isLoading: false,
        pactNames: const {},
        todayIndex: 5,
      );
      await tester.pumpWidget(_wrap(state));
      await tester.pump();

      expect(
        tester.getSemantics(find.text('7')), // todayIndex 5 → date 2026-06-07
        matchesSemantics(
          label: 'Sunday, June 7, 2026, today',
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('day digit does not overflow at a large system text-scale factor', (tester) async {
      await tester.pumpWidget(_wrap(_state([]), textScaler: const TextScaler.linear(3.0)));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('DashboardBody — separator', () {
    testWidgets('renders the separator widget', (tester) async {
      await tester.pumpWidget(_wrap(_state([])));
      await tester.pump();
      expect(find.byKey(const Key('test-separator')), findsOneWidget);
    });
  });

  group('DashboardBody — empty state', () {
    testWidgets('does not show buildNoPactsCta when hasPacts and no showups', (tester) async {
      await tester.pumpWidget(_wrap(_state([]), hasPacts: true));
      await tester.pump();
      expect(find.byKey(const Key('no-pacts-cta-button')), findsNothing);
    });

    testWidgets('shows buildNoPactsCta when not hasPacts and no showups', (tester) async {
      await tester.pumpWidget(_wrap(_state([]), hasPacts: false));
      await tester.pump();
      expect(find.byKey(const Key('no-pacts-cta-button')), findsOneWidget);
    });
  });

  group('DashboardBody — showup list', () {
    testWidgets('renders one tile per showup via buildShowupTile', (tester) async {
      await tester.pumpWidget(_wrap(_state([_showup('s1'), _showup('s2')])));
      await tester.pump();
      expect(find.byKey(const Key('tile-s1')), findsOneWidget);
      expect(find.byKey(const Key('tile-s2')), findsOneWidget);
    });

    testWidgets('calls onShowupTapped with showup id on tile tap', (tester) async {
      String? tapped;
      await tester.pumpWidget(_wrap(
        _state([_showup('s1')]),
        onShowupTapped: (id) async => tapped = id,
      ));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tile-s1')));
      expect(tapped, 's1');
    });

    testWidgets('passes habitName derived from pactNames to buildShowupTile', (tester) async {
      await tester.pumpWidget(_wrap(_state([_showup('s1')])));
      await tester.pump();
      expect(find.text('Meditate'), findsOneWidget);
    });
  });
}
