import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_status_colors.dart';
import 'package:habit_loop/theme/colors.dart';

void main() {
  group('PactStatusColors.cupertino', () {
    testWidgets('active → HabitLoopColors.primary', (tester) async {
      late PactStatusColors colors;
      await tester.pumpWidget(CupertinoApp(
        home: Builder(builder: (ctx) {
          colors = PactStatusColors.cupertino(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(colors.forStatus(PactStatus.active), HabitLoopColors.primary);
    });

    testWidgets('stopped → HabitLoopColors.danger', (tester) async {
      late PactStatusColors colors;
      await tester.pumpWidget(CupertinoApp(
        home: Builder(builder: (ctx) {
          colors = PactStatusColors.cupertino(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(colors.forStatus(PactStatus.stopped), HabitLoopColors.danger);
    });

    testWidgets('completed → HabitLoopColors.success', (tester) async {
      late PactStatusColors colors;
      await tester.pumpWidget(CupertinoApp(
        home: Builder(builder: (ctx) {
          colors = PactStatusColors.cupertino(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(colors.forStatus(PactStatus.completed), HabitLoopColors.success);
    });
  });

  group('PactStatusColors.material', () {
    test('active → HabitLoopColors.primary', () {
      expect(PactStatusColors.material.forStatus(PactStatus.active), HabitLoopColors.primary);
    });

    test('stopped → HabitLoopColors.danger', () {
      expect(PactStatusColors.material.forStatus(PactStatus.stopped), HabitLoopColors.danger);
    });

    test('completed → HabitLoopColors.success', () {
      expect(PactStatusColors.material.forStatus(PactStatus.completed), HabitLoopColors.success);
    });
  });
}
