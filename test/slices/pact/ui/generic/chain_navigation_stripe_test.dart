import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/slices/pact/ui/generic/chain_navigation_stripe.dart';
import 'package:habit_loop/theme/widgets/animated_value_transition.dart';

Pact _pact(String id, String habitName) => Pact(
      id: id,
      habitName: habitName,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 7, 1),
      showupDuration: const Duration(minutes: 10),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: PactStatus.active,
      reminderOffset: const Duration(minutes: 5),
    );

void main() {
  final predecessor = _pact('predecessor', 'Meditate (v1)');
  final successor = _pact('successor', 'Meditate (v3)');
  final farPredecessor = _pact('far-predecessor', 'Meditate (v0)');

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows only the successor slot when there is no predecessor', (tester) async {
    await tester.pumpWidget(wrap(ChainNavigationStripe(successor: successor)));

    expect(find.byKey(const Key('pact-detail-previous-pact-link')), findsNothing);
    expect(find.byKey(const Key('pact-detail-next-pact-link')), findsOneWidget);
    expect(find.textContaining('Meditate (v3)'), findsOneWidget);
  });

  testWidgets('shows only the predecessor slot when there is no successor', (tester) async {
    await tester.pumpWidget(wrap(ChainNavigationStripe(predecessor: predecessor)));

    expect(find.byKey(const Key('pact-detail-previous-pact-link')), findsOneWidget);
    expect(find.byKey(const Key('pact-detail-next-pact-link')), findsNothing);
    expect(find.textContaining('Meditate (v1)'), findsOneWidget);
  });

  testWidgets('shows both slots for a mid-chain pact', (tester) async {
    await tester.pumpWidget(wrap(ChainNavigationStripe(predecessor: predecessor, successor: successor)));

    expect(find.byKey(const Key('pact-detail-previous-pact-link')), findsOneWidget);
    expect(find.byKey(const Key('pact-detail-next-pact-link')), findsOneWidget);
    // Predecessor to the left of successor, same row.
    final previousPos = tester.getTopLeft(find.byKey(const Key('pact-detail-previous-pact-link')));
    final nextPos = tester.getTopLeft(find.byKey(const Key('pact-detail-next-pact-link')));
    expect(previousPos.dy, nextPos.dy);
    expect(previousPos.dx, lessThan(nextPos.dx));
  });

  testWidgets('tapping the predecessor slot calls onOpenPrevious', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(ChainNavigationStripe(predecessor: predecessor, onOpenPrevious: () => tapped = true)),
    );

    await tester.tap(find.byKey(const Key('pact-detail-previous-pact-link')));
    expect(tapped, isTrue);
  });

  testWidgets('tapping the successor slot calls onOpenNext', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(ChainNavigationStripe(successor: successor, onOpenNext: () => tapped = true)),
    );

    await tester.tap(find.byKey(const Key('pact-detail-next-pact-link')));
    expect(tapped, isTrue);
  });

  testWidgets('predecessor slot crossfades mid-transition, both old and new visible', (tester) async {
    await tester.pumpWidget(wrap(ChainNavigationStripe(predecessor: predecessor)));
    await tester.pumpAndSettle();

    // Simulates navigating: the predecessor slot's identity changes (e.g. the
    // new predecessor is one hop further up the chain) even though it stays
    // the same logical slot.
    await tester.pumpWidget(
      wrap(
        ChainNavigationStripe(
          predecessor: farPredecessor,
          direction: SlideDirection.backward,
          previousPredecessor: predecessor,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 125));

    expect(find.textContaining('Meditate (v1)'), findsOneWidget);
    expect(find.textContaining('Meditate (v0)'), findsOneWidget);

    await tester.pumpAndSettle();
  });
}
