import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/theme/widgets/animated_reveal.dart';

void main() {
  Widget wrap({required bool visible}) => MaterialApp(
        home: Scaffold(
          body: AnimatedReveal(
            visible: visible,
            child: const Text('reveal-me', key: Key('revealed-content')),
          ),
        ),
      );

  testWidgets('shows child immediately when visible starts true', (tester) async {
    await tester.pumpWidget(wrap(visible: true));

    expect(find.byKey(const Key('revealed-content')), findsOneWidget);
    final align = tester.widget<Align>(find.byType(Align));
    expect(align.heightFactor, 1.0);
  });

  testWidgets('child is absent from the tree when visible starts false', (tester) async {
    await tester.pumpWidget(wrap(visible: false));

    expect(find.byKey(const Key('revealed-content')), findsNothing);
    expect(find.byType(Align), findsNothing);
  });

  testWidgets('height factor and opacity stay in lock-step mid-animation when revealing', (tester) async {
    await tester.pumpWidget(wrap(visible: false));
    await tester.pumpWidget(wrap(visible: true));

    // Halfway through the 250ms animation.
    await tester.pump(const Duration(milliseconds: 125));

    final align = tester.widget<Align>(find.byType(Align));
    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(align.heightFactor, greaterThan(0.0));
    expect(align.heightFactor, lessThan(1.0));
    expect(opacity.opacity, align.heightFactor);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('revealed-content')), findsOneWidget);
    expect(tester.widget<Align>(find.byType(Align)).heightFactor, 1.0);
  });

  testWidgets('height factor and opacity stay in lock-step mid-animation when hiding', (tester) async {
    await tester.pumpWidget(wrap(visible: true));
    await tester.pumpWidget(wrap(visible: false));

    await tester.pump(const Duration(milliseconds: 125));

    final align = tester.widget<Align>(find.byType(Align));
    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(align.heightFactor, greaterThan(0.0));
    expect(align.heightFactor, lessThan(1.0));
    expect(opacity.opacity, align.heightFactor);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('revealed-content')), findsNothing);
  });

  testWidgets('child ignores taps while collapsing', (tester) async {
    var tapped = false;
    Widget wrapTappable({required bool visible}) => MaterialApp(
          home: Scaffold(
            body: AnimatedReveal(
              visible: visible,
              child: GestureDetector(onTap: () => tapped = true, child: const Text('tap-me')),
            ),
          ),
        );

    await tester.pumpWidget(wrapTappable(visible: true));
    await tester.pumpWidget(wrapTappable(visible: false));
    await tester.pump(const Duration(milliseconds: 125));
    await tester.tap(find.text('tap-me'), warnIfMissed: false);
    expect(tapped, isFalse, reason: 'collapsing content refers to already-stale state and must not react to taps');
  });
}
