// Regression net for HAB-187 WU1 — written against the pre-split
// `_PactsPanelState.build` to prove the God-widget split (into
// `_PactsPanelHeader`, `_PactFilterChipsRow`, `_PactListBody`,
// `_ArchivedPactsSection`) preserves behaviour. Drag-snap math
// (`pactsPickSnapTarget`) and basic header/hidden-state coverage already
// live in `pacts_panel_test.dart` and are intentionally not duplicated here.
import 'package:flutter/foundation.dart' show AsyncCallback;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pacts_summary_bar.dart';

// ── fixtures ─────────────────────────────────────────────────────────────────

Pact _pact({
  required String id,
  required String habitName,
  required PactStatus status,
  bool archived = false,
}) =>
    Pact(
      id: id,
      habitName: habitName,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      showupDuration: const Duration(minutes: 10),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
      status: status,
      stoppedAt: status == PactStatus.stopped ? DateTime(2026, 6, 1) : null,
      archived: archived,
    );

final _activePact = _pact(id: 'p-active', habitName: 'Meditate', status: PactStatus.active);
final _donePact = _pact(id: 'p-done', habitName: 'Journal', status: PactStatus.completed);
final _archivedDonePact = _pact(
  id: 'p-archived',
  habitName: 'Stretch',
  status: PactStatus.completed,
  archived: true,
);

final _mixedState = PactListState(
  entries: [
    PactListEntry(pact: _activePact),
    PactListEntry(pact: _donePact),
    PactListEntry(pact: _archivedDonePact),
  ],
);

// ── harness ──────────────────────────────────────────────────────────────────

Widget _buildApp(PactListState listState, {AsyncCallback? onCreatePact}) => ProviderScope(
      overrides: [
        pactListViewModelProvider.overrideWith(() => _FakePactListViewModel(listState)),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: _PanelHost(onCreatePact: onCreatePact ?? (() async {})),
      ),
    );

class _PanelHost extends StatelessWidget {
  final AsyncCallback onCreatePact;

  const _PanelHost({required this.onCreatePact});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          children: [
            const SizedBox.expand(),
            PactsPanel(onCreatePact: onCreatePact),
          ],
        ),
      );
}

class _FakePactListViewModel extends PactListViewModel {
  final PactListState _initial;
  _FakePactListViewModel(this._initial);

  @override
  PactListState build() => _initial;
}

// Panel starts collapsed to header-height only — the sliver body (filter
// chips, list, archived section) needs the panel fully expanded before its
// content is laid out and discoverable by finders. A fast upward fling snaps
// straight to the max extent (see the equivalent fling in pacts_panel_test.dart).
Future<void> _expandPanel(WidgetTester tester) async {
  await tester.fling(find.byKey(const Key('pacts-panel-drag-handle')), const Offset(0, -300), 1000);
  await tester.pumpAndSettle();
}

// ── tests ────────────────────────────────────────────────────────────────────

void main() {
  group('PactsPanel header', () {
    testWidgets('renders drag handle and pact counts', (tester) async {
      await tester.pumpWidget(_buildApp(_mixedState));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pacts-panel-drag-handle')), findsOneWidget);
      expect(find.textContaining('1 pact active'), findsOneWidget);
    });
  });

  group('PactsPanel filter row', () {
    testWidgets('renders active/done/cancelled chips, and archived chip once an archived pact exists', (tester) async {
      await tester.pumpWidget(_buildApp(_mixedState));
      await tester.pumpAndSettle();
      await _expandPanel(tester);

      expect(find.widgetWithText(FilterChip, 'Active'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Done'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Stopped'), findsOneWidget);
      expect(find.byKey(const Key('archive-filter-chip')), findsOneWidget);
    });

    testWidgets('no archived chip when there are no archived pacts', (tester) async {
      await tester.pumpWidget(_buildApp(PactListState(entries: [PactListEntry(pact: _activePact)])));
      await tester.pumpAndSettle();
      await _expandPanel(tester);

      expect(find.byKey(const Key('archive-filter-chip')), findsNothing);
    });

    testWidgets('toggling the Active filter hides active pacts from the list', (tester) async {
      await tester.pumpWidget(_buildApp(_mixedState));
      await tester.pumpAndSettle();
      await _expandPanel(tester);

      expect(find.text('Meditate'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Active'));
      await tester.pumpAndSettle();

      expect(find.text('Meditate'), findsNothing);
      // Unaffected filters keep their entries visible.
      expect(find.text('Journal'), findsOneWidget);
    });
  });

  group('PactsPanel list body', () {
    testWidgets('renders a tile per unarchived, filter-visible entry', (tester) async {
      await tester.pumpWidget(_buildApp(_mixedState));
      await tester.pumpAndSettle();
      await _expandPanel(tester);

      expect(find.text('Meditate'), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget);
      // Archived entry is not shown until "show archived" is toggled on.
      expect(find.text('Stretch'), findsNothing);
    });

    testWidgets('shows the empty state when there are no visible entries', (tester) async {
      // All filters toggled off: raw counts keep the panel visible, but
      // filteredEntries/archivedEntries are both empty, so allEmpty is true.
      final allFiltersOff = PactListState(
        entries: [PactListEntry(pact: _activePact)],
        activeFilters: const {},
      );
      await tester.pumpWidget(_buildApp(allFiltersOff));
      await tester.pumpAndSettle();
      await _expandPanel(tester);

      expect(find.text('No pacts yet'), findsOneWidget);
    });

    testWidgets('tapping "Add a pact" invokes onCreatePact', (tester) async {
      var created = false;
      await tester.pumpWidget(_buildApp(
        PactListState(entries: [PactListEntry(pact: _activePact)]),
        onCreatePact: () async {
          created = true;
        },
      ));
      await tester.pumpAndSettle();
      await _expandPanel(tester);

      await tester.tap(find.text('Add a pact'));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(created, isTrue);
    });
  });

  group('PactsPanel archived section', () {
    testWidgets('reveals archived entries when the archived-pacts row is tapped', (tester) async {
      await tester.pumpWidget(_buildApp(_mixedState));
      await tester.pumpAndSettle();
      await _expandPanel(tester);

      expect(find.text('Stretch'), findsNothing);

      await tester.tap(find.byKey(const Key('show-archived-pacts-row')));
      await tester.pumpAndSettle();

      expect(find.text('Stretch'), findsOneWidget);
    });
  });
}
