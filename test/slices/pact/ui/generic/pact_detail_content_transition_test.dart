import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_content_transition.dart';

Widget _wrap({
  required Object key,
  required Widget child,
  ChainNavigationDirection? direction,
}) {
  return MaterialApp(
    home: SizedBox(
      width: 400,
      height: 800,
      child: PactDetailContentTransition(
        transitionKey: key,
        direction: direction,
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('first build shows child immediately, unanimated', (tester) async {
    await tester.pumpWidget(_wrap(key: 'p1', child: const Text('pact one')));

    expect(find.text('pact one'), findsOneWidget);
    // No wrapping Opacity/FractionalTranslation at all when there's nothing
    // to transition from — child is returned as-is.
    expect(_transitionDescendants<Opacity>(), findsNothing);
    expect(_transitionDescendants<FractionalTranslation>(), findsNothing);
  });

  testWidgets('toSuccessor: outgoing slides left + fades out, incoming slides in from the right', (tester) async {
    await tester.pumpWidget(_wrap(key: 'p1', child: const Text('pact one')));
    await tester.pumpWidget(
      _wrap(key: 'p2', child: const Text('pact two'), direction: ChainNavigationDirection.toSuccessor),
    );

    // Mid-transition: both texts visible simultaneously.
    await tester.pump(const Duration(milliseconds: 125));
    expect(find.text('pact one'), findsOneWidget);
    expect(find.text('pact two'), findsOneWidget);

    final outgoingOpacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('pact one'), matching: find.byType(Opacity)).first,
    );
    final incomingOpacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('pact two'), matching: find.byType(Opacity)).first,
    );
    expect(outgoingOpacity.opacity, greaterThan(0));
    expect(outgoingOpacity.opacity, lessThan(1));
    expect(incomingOpacity.opacity, greaterThan(0));
    expect(incomingOpacity.opacity, lessThan(1));

    final outgoingTranslation = tester.widget<FractionalTranslation>(
      find.ancestor(of: find.text('pact one'), matching: find.byType(FractionalTranslation)).first,
    );
    final incomingTranslation = tester.widget<FractionalTranslation>(
      find.ancestor(of: find.text('pact two'), matching: find.byType(FractionalTranslation)).first,
    );
    // Successor: outgoing moves left (negative dx), incoming still catching
    // up from off-screen right (positive dx).
    expect(outgoingTranslation.translation.dx, lessThan(0));
    expect(incomingTranslation.translation.dx, greaterThan(0));

    // Settle: only the new content remains, fully opaque, untranslated.
    await tester.pumpAndSettle();
    expect(find.text('pact one'), findsNothing);
    expect(find.text('pact two'), findsOneWidget);
    expect(_transitionDescendants<Opacity>(), findsNothing);
    expect(_transitionDescendants<FractionalTranslation>(), findsNothing);
  });

  testWidgets('toPredecessor: outgoing slides right + fades out, incoming slides in from the left', (tester) async {
    await tester.pumpWidget(_wrap(key: 'p2', child: const Text('pact two')));
    await tester.pumpWidget(
      _wrap(key: 'p1', child: const Text('pact one'), direction: ChainNavigationDirection.toPredecessor),
    );

    await tester.pump(const Duration(milliseconds: 125));
    final outgoingTranslation = tester.widget<FractionalTranslation>(
      find.ancestor(of: find.text('pact two'), matching: find.byType(FractionalTranslation)).first,
    );
    final incomingTranslation = tester.widget<FractionalTranslation>(
      find.ancestor(of: find.text('pact one'), matching: find.byType(FractionalTranslation)).first,
    );
    // Predecessor: outgoing moves right (positive dx), incoming still
    // catching up from off-screen left (negative dx).
    expect(outgoingTranslation.translation.dx, greaterThan(0));
    expect(incomingTranslation.translation.dx, lessThan(0));

    await tester.pumpAndSettle();
    expect(find.text('pact one'), findsOneWidget);
    expect(find.text('pact two'), findsNothing);
  });

  testWidgets('outgoing content ignores hit testing mid-transition', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        key: 'p1',
        child: GestureDetector(onTap: () => tapped = true, child: const Text('pact one')),
      ),
    );
    await tester.pumpWidget(
      _wrap(
        key: 'p2',
        direction: ChainNavigationDirection.toSuccessor,
        child: const Text('pact two'),
      ),
    );

    await tester.pump(const Duration(milliseconds: 125));
    await tester.tap(find.text('pact one'), warnIfMissed: false);
    expect(tapped, isFalse);
  });

  testWidgets('a same-key rebuild (no transitionKey change) does not animate', (tester) async {
    await tester.pumpWidget(_wrap(key: 'p1', child: const Text('v1')));
    await tester.pumpWidget(_wrap(key: 'p1', child: const Text('v1-updated')));

    expect(find.text('v1-updated'), findsOneWidget);
    expect(find.text('v1'), findsNothing);
    expect(_transitionDescendants<Opacity>(), findsNothing);
  });
}

Finder _transitionDescendants<T extends Widget>() =>
    find.descendant(of: find.byType(PactDetailContentTransition), matching: find.byType(T));
