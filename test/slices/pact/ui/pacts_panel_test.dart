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

// ── helpers ──────────────────────────────────────────────────────────────────

final _activePact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2026, 12, 31),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
  status: PactStatus.active,
);

final _withOnePact = PactListState(entries: [PactListEntry(pact: _activePact)]);

Widget _buildApp(PactListState listState) => ProviderScope(
      overrides: [
        pactListViewModelProvider.overrideWith(() => _FakePactListViewModel(listState)),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: _PanelHost(),
      ),
    );

class _PanelHost extends StatelessWidget {
  const _PanelHost();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          children: [
            const SizedBox.expand(),
            PactsPanel(onCreatePact: () async {}),
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

// Wraps [child] and captures every DraggableScrollableNotification extent.
class _ExtentCapture extends StatelessWidget {
  final Widget child;
  final ValueChanged<double> onExtent;

  const _ExtentCapture({required this.child, required this.onExtent});

  @override
  Widget build(BuildContext context) => NotificationListener<DraggableScrollableNotification>(
        onNotification: (n) {
          onExtent(n.extent);
          return false;
        },
        child: child,
      );
}

// ── snap-logic unit tests (no Flutter runtime needed) ────────────────────────

void main() {
  group('pactsPickSnapTarget', () {
    const min = 0.12;
    const semi = 0.55;
    const max = 0.85;
    const snaps = [min, semi, max];

    test('fast upward velocity returns maxSize', () {
      expect(
        pactsPickSnapTarget(velocity: -500, currentSize: 0.3, snapSizes: snaps, maxSize: max, minSize: min),
        max,
      );
    });

    test('fast upward from semi-expanded also returns maxSize', () {
      expect(
        pactsPickSnapTarget(velocity: -400, currentSize: semi, snapSizes: snaps, maxSize: max, minSize: min),
        max,
      );
    });

    test('fast downward velocity returns minSize', () {
      expect(
        pactsPickSnapTarget(velocity: 500, currentSize: 0.7, snapSizes: snaps, maxSize: max, minSize: min),
        min,
      );
    });

    test('slow drag released below halfway between collapsed and semi-expanded snaps to collapsed', () {
      const pos = (min + semi) / 2 - 0.01;
      expect(
        pactsPickSnapTarget(velocity: 0, currentSize: pos, snapSizes: snaps, maxSize: max, minSize: min),
        min,
      );
    });

    test('slow drag released above halfway between collapsed and semi-expanded snaps to semi-expanded', () {
      const pos = (min + semi) / 2 + 0.01;
      expect(
        pactsPickSnapTarget(velocity: 0, currentSize: pos, snapSizes: snaps, maxSize: max, minSize: min),
        semi,
      );
    });

    test('slow drag released below halfway between semi-expanded and expanded snaps to semi-expanded', () {
      const pos = (semi + max) / 2 - 0.01;
      expect(
        pactsPickSnapTarget(velocity: 0, currentSize: pos, snapSizes: snaps, maxSize: max, minSize: min),
        semi,
      );
    });

    test('slow drag released above halfway between semi-expanded and expanded snaps to expanded', () {
      const pos = (semi + max) / 2 + 0.01;
      expect(
        pactsPickSnapTarget(velocity: 0, currentSize: pos, snapSizes: snaps, maxSize: max, minSize: min),
        max,
      );
    });

    test('velocity exactly at -300 threshold uses snap-to-nearest', () {
      // -300 is NOT < -300, so snap-to-nearest applies.
      // 0.3 is closer to min (delta 0.18) than to semi (delta 0.25).
      expect(
        pactsPickSnapTarget(velocity: -300, currentSize: 0.3, snapSizes: snaps, maxSize: max, minSize: min),
        min,
      );
    });

    test('velocity just past -300 threshold returns maxSize regardless of position', () {
      expect(
        pactsPickSnapTarget(velocity: -301, currentSize: 0.3, snapSizes: snaps, maxSize: max, minSize: min),
        max,
      );
    });
  });

  // ── widget tests ────────────────────────────────────────────────────────────

  group('PactsPanel', () {
    testWidgets('renders pact summary and drag handle when pacts exist', (tester) async {
      await tester.pumpWidget(_buildApp(_withOnePact));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 pact active'), findsOneWidget);
      expect(find.byKey(const Key('pacts-panel-drag-handle')), findsOneWidget);
    });

    testWidgets('hidden when no pacts exist', (tester) async {
      await tester.pumpWidget(_buildApp(const PactListState()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pacts-panel-drag-handle')), findsNothing);
    });

    testWidgets('tapping header expands to semi-expanded (0.55)', (tester) async {
      double? lastExtent;

      await tester.pumpWidget(
        _ExtentCapture(
          onExtent: (e) => lastExtent = e,
          child: _buildApp(_withOnePact),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pacts-panel-drag-handle')));
      await tester.pumpAndSettle();

      expect(lastExtent, isNotNull);
      expect(lastExtent, closeTo(0.55, 0.02));
    });

    testWidgets('fast upward fling expands past semi-expanded to fully expanded', (tester) async {
      double? lastExtent;

      await tester.pumpWidget(
        _ExtentCapture(
          onExtent: (e) => lastExtent = e,
          child: _buildApp(_withOnePact),
        ),
      );
      await tester.pumpAndSettle();

      await tester.fling(
        find.byKey(const Key('pacts-panel-drag-handle')),
        const Offset(0, -300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(lastExtent, isNotNull);
      expect(lastExtent, greaterThan(0.55));
    });
  });
}
