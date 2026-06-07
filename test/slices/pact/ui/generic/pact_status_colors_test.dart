import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_status_colors.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

void main() {
  group('PactStatusColors.cupertino', () {
    test('active → HabitLoopColors.primary', () {
      expect(PactStatusColors.cupertino.forStatus(PactStatus.active), HabitLoopColors.primary);
    });

    test('stopped → CupertinoColors.destructiveRed', () {
      expect(PactStatusColors.cupertino.forStatus(PactStatus.stopped), CupertinoColors.destructiveRed);
    });

    test('completed → CupertinoColors.activeGreen', () {
      expect(PactStatusColors.cupertino.forStatus(PactStatus.completed), CupertinoColors.activeGreen);
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
