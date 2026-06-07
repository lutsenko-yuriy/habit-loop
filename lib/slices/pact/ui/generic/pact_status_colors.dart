import 'package:flutter/cupertino.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

// Status-color palette for pact badges and detail screens.
// Two constant instances: cupertino (Cupertino primitives) and material (HabitLoopColors constants).
class PactStatusColors {
  final Color active;
  final Color stopped;
  final Color completed;

  const PactStatusColors({
    required this.active,
    required this.stopped,
    required this.completed,
  });

  static PactStatusColors cupertino(BuildContext context) => PactStatusColors(
        active: HabitLoopColors.primary,
        stopped: CupertinoColors.destructiveRed.resolveFrom(context),
        completed: CupertinoColors.activeGreen.resolveFrom(context),
      );

  static const PactStatusColors material = PactStatusColors(
    active: HabitLoopColors.primary,
    stopped: HabitLoopColors.danger,
    completed: HabitLoopColors.success,
  );

  Color forStatus(PactStatus status) => switch (status) {
        PactStatus.active => active,
        PactStatus.stopped => stopped,
        PactStatus.completed => completed,
      };
}
