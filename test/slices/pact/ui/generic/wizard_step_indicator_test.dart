import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/wizard_step_indicator.dart';
import 'package:habit_loop/slices/pact/ui/generic/wizard_style.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

const _keyPrefix = 'test-step-indicator';
const _stepCount = 4;

Widget _wrap({
  required int currentIndex,
  ValueChanged<int>? onStepTapped,
  ValueChanged<WizardStyle>? onStyleResolved,
}) {
  return MaterialApp(
    theme: HabitLoopTheme.materialTheme,
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(builder: (context) {
        final style = WizardStyle.material(context);
        onStyleResolved?.call(style);
        return WizardStepIndicator(
          style: style,
          currentIndex: currentIndex,
          stepCount: _stepCount,
          onStepTapped: onStepTapped ?? (_) {},
          keyPrefix: _keyPrefix,
        );
      }),
    ),
  );
}

void main() {
  testWidgets('renders stepCount segments', (tester) async {
    await tester.pumpWidget(_wrap(currentIndex: 0));
    for (var i = 0; i < _stepCount; i++) {
      expect(find.byKey(Key('$_keyPrefix-segment-$i')), findsOneWidget);
    }
  });

  testWidgets('outer Padding has the keyPrefix key', (tester) async {
    await tester.pumpWidget(_wrap(currentIndex: 0));
    expect(find.byKey(const Key(_keyPrefix)), findsOneWidget);
  });

  testWidgets('tapping segment calls onStepTapped with correct index', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(_wrap(currentIndex: 0, onStepTapped: tapped.add));
    await tester.tap(find.byKey(const Key('$_keyPrefix-segment-2')));
    await tester.pump();
    expect(tapped, [2]);
  });

  testWidgets('current segment uses activeStepColor', (tester) async {
    late WizardStyle style;
    await tester.pumpWidget(_wrap(currentIndex: 2, onStyleResolved: (s) => style = s));
    final container = tester.widget<Container>(find.byKey(const Key('$_keyPrefix-segment-2')));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, style.activeStepColor);
  });

  testWidgets('past segment uses pastStepColor', (tester) async {
    late WizardStyle style;
    await tester.pumpWidget(_wrap(currentIndex: 2, onStyleResolved: (s) => style = s));
    final container = tester.widget<Container>(find.byKey(const Key('$_keyPrefix-segment-1')));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, style.pastStepColor);
  });

  testWidgets('future segment uses inactiveStepColor', (tester) async {
    late WizardStyle style;
    await tester.pumpWidget(_wrap(currentIndex: 1, onStyleResolved: (s) => style = s));
    final container = tester.widget<Container>(find.byKey(const Key('$_keyPrefix-segment-3')));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, style.inactiveStepColor);
  });

  group('accessibility', () {
    testWidgets('each segment exposes a Semantics label with its position and selected state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(currentIndex: 1));

      expect(
        tester.getSemantics(find.byKey(const Key('$_keyPrefix-segment-0'))),
        matchesSemantics(
          label: 'Step 1 of $_stepCount',
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('$_keyPrefix-segment-1'))),
        matchesSemantics(
          label: 'Step 2 of $_stepCount',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('segments meet the Android and iOS tap-target guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(currentIndex: 0));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });
  });
}
