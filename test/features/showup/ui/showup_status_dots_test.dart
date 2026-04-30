import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/features/showup/ui/generic/showup_status_colors.dart';
import 'package:habit_loop/features/showup/ui/generic/showup_status_dots.dart';

Showup _s(String id, ShowupStatus status) => Showup(
      id: id,
      pactId: 'p',
      scheduledAt: DateTime(2026, 3, 30),
      duration: const Duration(minutes: 10),
      status: status,
    );

// Pumps ShowupStatusDots inside a CupertinoApp so that
// ShowupStatusColors.cupertino(context) can resolve against a real brightness.
Future<void> _pump(WidgetTester tester, List<Showup> showups, DateTime date) {
  return tester.pumpWidget(
    CupertinoApp(
      home: Builder(
        builder: (context) => ShowupStatusDots(
          showups: showups,
          date: date,
          colors: ShowupStatusColors.cupertino(context),
        ),
      ),
    ),
  );
}

void main() {
  final date = DateTime(2026, 3, 30);

  testWidgets('renders nothing when there are no showups', (tester) async {
    await _pump(tester, const [], date);
    expect(find.byType(SizedBox), findsOneWidget);
    // No dot keys should be present.
    expect(find.byKey(const Key('status-dot-overflow-2026-03-30')), findsNothing);
  });

  testWidgets('renders 1..3 individual dots with per-showup keys', (tester) async {
    final showups = [
      _s('a', ShowupStatus.done),
      _s('b', ShowupStatus.failed),
      _s('c', ShowupStatus.pending),
    ];
    await _pump(tester, showups, date);
    expect(find.byKey(const Key('status-dot-a')), findsOneWidget);
    expect(find.byKey(const Key('status-dot-b')), findsOneWidget);
    expect(find.byKey(const Key('status-dot-c')), findsOneWidget);
    // No overflow dot.
    expect(find.byKey(const Key('status-dot-overflow-2026-03-30')), findsNothing);
  });

  testWidgets('renders the overflow dot when there are 4 or more showups', (tester) async {
    final showups = [
      _s('a', ShowupStatus.done),
      _s('b', ShowupStatus.done),
      _s('c', ShowupStatus.failed),
      _s('d', ShowupStatus.pending),
    ];
    await _pump(tester, showups, date);
    expect(find.byKey(const Key('status-dot-overflow-2026-03-30')), findsOneWidget);
    // Individual dots are not rendered in overflow mode.
    expect(find.byKey(const Key('status-dot-a')), findsNothing);
  });

  testWidgets('overflow dot uses the pending color while any showup is pending', (tester) async {
    final showups = [
      _s('a', ShowupStatus.pending),
      _s('b', ShowupStatus.done),
      _s('c', ShowupStatus.done),
      _s('d', ShowupStatus.done),
    ];
    await _pump(tester, showups, date);
    final container = tester.widget<Container>(find.byKey(const Key('status-dot-overflow-2026-03-30')));
    final decoration = container.decoration as BoxDecoration;
    // The overflow dot should use the resolved systemGrey colour.
    final BuildContext ctx = tester.element(find.byKey(const Key('status-dot-overflow-2026-03-30')));
    expect(decoration.color, CupertinoColors.systemGrey.resolveFrom(ctx));
  });

  testWidgets('pads the overflow key with zeros (single-digit month/day)', (tester) async {
    // Date with single-digit month and day: 2026-01-05 → "2026-01-05".
    final early = DateTime(2026, 1, 5);
    final showups = List.generate(4, (i) => _s('s$i', ShowupStatus.done));
    await _pump(tester, showups, early);
    expect(find.byKey(const Key('status-dot-overflow-2026-01-05')), findsOneWidget);
  });
}
