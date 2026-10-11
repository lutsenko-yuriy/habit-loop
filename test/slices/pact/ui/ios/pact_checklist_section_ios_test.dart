import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_checklist_section_state.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_checklist_section_ios.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

final _link = PactChecklistLink(
  pactId: 'p1',
  checklistId: 'c1',
  checklistName: 'Morning routine',
  linkedAt: DateTime(2026, 5, 1),
);

class _Taps {
  int select = 0;
  int change = 0;
  int remove = 0;
}

Widget _app(PactChecklistSectionState state, _Taps taps, {Brightness brightness = Brightness.light}) => MaterialApp(
      theme: brightness == Brightness.dark ? HabitLoopTheme.darkMaterialTheme : HabitLoopTheme.materialTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PactChecklistSectionIos(
          state: state,
          onSelect: () => taps.select++,
          onChange: () => taps.change++,
          onRemove: () => taps.remove++,
        ),
      ),
    );

const _selectKey = Key('pact-checklist-select-button');
const _changeKey = Key('pact-checklist-change-button');
const _removeKey = Key('pact-checklist-remove-button');
const _errorKey = Key('pact-checklist-error');

void main() {
  late AppLocalizations l10n;

  Future<void> pump(WidgetTester tester, PactChecklistSectionState state, _Taps taps) async {
    await tester.pumpWidget(_app(state, taps));
    await tester.pumpAndSettle();
    l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
  }

  group('PactChecklistSectionIos', () {
    testWidgets('not loaded yet: renders nothing (no title, no buttons)', (tester) async {
      await pump(tester, const PactChecklistSectionState(), _Taps());
      expect(find.text(l10n.pactChecklistSectionTitle.toUpperCase()), findsNothing);
      expect(find.byKey(_selectKey), findsNothing);
    });

    testWidgets('no link: shows the title and only "Select checklist"', (tester) async {
      await pump(tester, const PactChecklistSectionState(isLoaded: true), _Taps());
      expect(find.text(l10n.pactChecklistSectionTitle.toUpperCase()), findsOneWidget);
      expect(find.byKey(_selectKey), findsOneWidget);
      expect(find.text(l10n.pactChecklistSelect), findsOneWidget);
      expect(find.byKey(_changeKey), findsNothing);
      expect(find.byKey(_removeKey), findsNothing);
      expect(find.byKey(_errorKey), findsNothing);
    });

    testWidgets('linked: shows the checklist name with Change and Remove, no Select', (tester) async {
      await pump(tester, PactChecklistSectionState(isLoaded: true, link: _link), _Taps());
      expect(find.text('Morning routine'), findsOneWidget);
      expect(find.byKey(_changeKey), findsOneWidget);
      expect(find.byKey(_removeKey), findsOneWidget);
      expect(find.byKey(_selectKey), findsNothing);
    });

    testWidgets('tapping Select, Change and Remove calls the matching callback exactly once', (tester) async {
      final taps = _Taps();
      await pump(tester, const PactChecklistSectionState(isLoaded: true), taps);
      await tester.tap(find.byKey(_selectKey));
      expect([taps.select, taps.change, taps.remove], [1, 0, 0]);

      await pump(tester, PactChecklistSectionState(isLoaded: true, link: _link), taps);
      await tester.tap(find.byKey(_changeKey));
      await tester.tap(find.byKey(_removeKey));
      expect([taps.select, taps.change, taps.remove], [1, 1, 1]);
    });

    testWidgets('noChecklists error: shows the "create a checklist first" message and keeps Select', (tester) async {
      await pump(
        tester,
        const PactChecklistSectionState(isLoaded: true, error: PactChecklistSectionError.noChecklists),
        _Taps(),
      );
      expect(find.byKey(_errorKey), findsOneWidget);
      expect(find.text(l10n.pactChecklistNoChecklistsError), findsOneWidget);
      expect(find.byKey(_selectKey), findsOneWidget);
    });

    testWidgets('couldNotOpen error: shows the could-not-open message', (tester) async {
      await pump(
        tester,
        const PactChecklistSectionState(isLoaded: true, error: PactChecklistSectionError.couldNotOpen),
        _Taps(),
      );
      expect(find.text(l10n.checklisterCouldNotOpenError), findsOneWidget);
    });

    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('text meets AA contrast in ${brightness.name} mode (linked, with error)', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(
          PactChecklistSectionState(isLoaded: true, link: _link, error: PactChecklistSectionError.couldNotOpen),
          _Taps(),
          brightness: brightness,
        ));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });
}
