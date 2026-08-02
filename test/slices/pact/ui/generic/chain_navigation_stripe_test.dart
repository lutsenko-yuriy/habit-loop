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
  final current = _pact('current', 'Meditate (v2)');
  final predecessor = _pact('predecessor', 'Meditate (v1)');
  final successor = _pact('successor', 'Meditate (v3)');

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows only the successor slot when there is no predecessor', (tester) async {
    await tester.pumpWidget(wrap(ChainNavigationStripe(current: current, successor: successor)));

    expect(find.byKey(const Key('pact-detail-previous-pact-link')), findsNothing);
    expect(find.byKey(const Key('pact-detail-next-pact-link')), findsOneWidget);
    expect(find.byKey(const Key('pact-detail-current-pact-chip')), findsOneWidget);
    expect(find.textContaining('Meditate (v3)'), findsOneWidget);
    expect(find.textContaining('Meditate (v2)'), findsOneWidget);
  });

  testWidgets('shows only the predecessor slot when there is no successor', (tester) async {
    await tester.pumpWidget(wrap(ChainNavigationStripe(current: current, predecessor: predecessor)));

    expect(find.byKey(const Key('pact-detail-previous-pact-link')), findsOneWidget);
    expect(find.byKey(const Key('pact-detail-next-pact-link')), findsNothing);
    expect(find.byKey(const Key('pact-detail-current-pact-chip')), findsOneWidget);
    expect(find.textContaining('Meditate (v1)'), findsOneWidget);
    expect(find.textContaining('Meditate (v2)'), findsOneWidget);
  });

  testWidgets('shows all three slots for a mid-chain pact', (tester) async {
    await tester.pumpWidget(
      wrap(ChainNavigationStripe(current: current, predecessor: predecessor, successor: successor)),
    );

    expect(find.byKey(const Key('pact-detail-previous-pact-link')), findsOneWidget);
    expect(find.byKey(const Key('pact-detail-next-pact-link')), findsOneWidget);
    expect(find.byKey(const Key('pact-detail-current-pact-chip')), findsOneWidget);
    expect(find.textContaining('Meditate (v2)'), findsOneWidget);
  });

  testWidgets('tapping the predecessor slot calls onOpenPrevious', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(ChainNavigationStripe(current: current, predecessor: predecessor, onOpenPrevious: () => tapped = true)),
    );

    await tester.tap(find.byKey(const Key('pact-detail-previous-pact-link')));
    expect(tapped, isTrue);
  });

  testWidgets('tapping the successor slot calls onOpenNext', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(ChainNavigationStripe(current: current, successor: successor, onOpenNext: () => tapped = true)),
    );

    await tester.tap(find.byKey(const Key('pact-detail-next-pact-link')));
    expect(tapped, isTrue);
  });

  testWidgets('current slot is not tappable', (tester) async {
    await tester.pumpWidget(wrap(ChainNavigationStripe(current: current)));

    expect(find.byKey(const Key('pact-detail-current-pact-chip')), findsOneWidget);
    expect(
      find.ancestor(of: find.byKey(const Key('pact-detail-current-pact-chip')), matching: find.byType(TextButton)),
      findsNothing,
    );
  });

  testWidgets('predecessor and current slots crossfade mid-transition, both old and new visible', (tester) async {
    await tester.pumpWidget(
      wrap(ChainNavigationStripe(current: predecessor, successor: current)),
    );
    await tester.pumpAndSettle();

    // Simulates navigating forward: old current (predecessor arg here) becomes
    // the new predecessor slot; old successor (current arg here) becomes the
    // new current slot — mirrors PactDetailScreen's own re-mapping on a "next" tap.
    await tester.pumpWidget(
      wrap(
        ChainNavigationStripe(
          current: current,
          predecessor: predecessor,
          direction: SlideDirection.forward,
          previousCurrent: predecessor,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 125));

    expect(find.textContaining('Meditate (v1)'), findsWidgets);
    expect(find.textContaining('Meditate (v2)'), findsOneWidget);

    await tester.pumpAndSettle();
  });
}
