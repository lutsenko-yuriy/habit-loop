import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/theme/widgets/animated_value_transition.dart';

Widget _wrap({
  required Widget child,
  Widget? previousChild,
  SlideDirection? direction,
}) {
  return MaterialApp(
    home: Center(
      child: AnimatedValueTransition(
        previousChild: previousChild,
        direction: direction,
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('no previousChild: shows child immediately, unanimated', (tester) async {
    await tester.pumpWidget(_wrap(child: const Text('v1')));

    expect(find.text('v1'), findsOneWidget);
    expect(_transitionDescendants<Opacity>(), findsNothing);
    expect(_transitionDescendants<Transform>(), findsNothing);
  });

  testWidgets('toSuccessor: outgoing slides left + fades out, incoming slides in from the right', (tester) async {
    await tester.pumpWidget(
      _wrap(
        previousChild: const Text('5'),
        direction: SlideDirection.forward,
        child: const Text('8'),
      ),
    );

    // Mid-transition: both values visible simultaneously.
    await tester.pump(const Duration(milliseconds: 125));
    expect(find.text('5'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);

    final outgoingOpacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('5'), matching: find.byType(Opacity)).first,
    );
    final incomingOpacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('8'), matching: find.byType(Opacity)).first,
    );
    expect(outgoingOpacity.opacity, greaterThan(0));
    expect(outgoingOpacity.opacity, lessThan(1));
    expect(incomingOpacity.opacity, greaterThan(0));
    expect(incomingOpacity.opacity, lessThan(1));

    final outgoingTransform = tester.widget<Transform>(
      find.ancestor(of: find.text('5'), matching: find.byType(Transform)).first,
    );
    final incomingTransform = tester.widget<Transform>(
      find.ancestor(of: find.text('8'), matching: find.byType(Transform)).first,
    );
    // Successor: outgoing moves left (negative dx), incoming still catching
    // up from off to the right (positive dx).
    expect(outgoingTransform.transform.getTranslation().x, lessThan(0));
    expect(incomingTransform.transform.getTranslation().x, greaterThan(0));

    // Settle: only the new value remains, fully opaque, untranslated.
    await tester.pumpAndSettle();
    expect(find.text('5'), findsNothing);
    expect(find.text('8'), findsOneWidget);
    expect(_transitionDescendants<Opacity>(), findsNothing);
    expect(_transitionDescendants<Transform>(), findsNothing);
  });

  testWidgets('toPredecessor: outgoing slides right + fades out, incoming slides in from the left', (tester) async {
    await tester.pumpWidget(
      _wrap(
        previousChild: const Text('8'),
        direction: SlideDirection.backward,
        child: const Text('5'),
      ),
    );

    await tester.pump(const Duration(milliseconds: 125));
    final outgoingTransform = tester.widget<Transform>(
      find.ancestor(of: find.text('8'), matching: find.byType(Transform)).first,
    );
    final incomingTransform = tester.widget<Transform>(
      find.ancestor(of: find.text('5'), matching: find.byType(Transform)).first,
    );
    // Predecessor: outgoing moves right (positive dx), incoming still
    // catching up from off to the left (negative dx).
    expect(outgoingTransform.transform.getTranslation().x, greaterThan(0));
    expect(incomingTransform.transform.getTranslation().x, lessThan(0));

    await tester.pumpAndSettle();
    expect(find.text('5'), findsOneWidget);
    expect(find.text('8'), findsNothing);
  });

  testWidgets('a null previousChild (unchanged value) never animates, even with a direction set', (tester) async {
    // Caller convention: when the outgoing and incoming pact happen to show
    // the same value, previousChild is omitted entirely — nothing to
    // visibly swap, so this must render as a plain, unanimated child.
    await tester.pumpWidget(
      _wrap(direction: SlideDirection.forward, child: const Text('0')),
    );

    expect(find.text('0'), findsOneWidget);
    expect(_transitionDescendants<Opacity>(), findsNothing);
    expect(_transitionDescendants<Transform>(), findsNothing);
  });

  testWidgets('outgoing content ignores hit testing mid-transition', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        previousChild: GestureDetector(onTap: () => tapped = true, child: const Text('a')),
        direction: SlideDirection.forward,
        child: const Text('b'),
      ),
    );

    await tester.pump(const Duration(milliseconds: 125));
    await tester.tap(find.text('a'), warnIfMissed: false);
    expect(tapped, isFalse);
  });
}

Finder _transitionDescendants<T extends Widget>() =>
    find.descendant(of: find.byType(AnimatedValueTransition), matching: find.byType(T));
