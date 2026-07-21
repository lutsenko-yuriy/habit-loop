import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';
import 'package:habit_loop/theme/typography.dart';

void main() {
  testWidgets('HabitLoopTheme.cupertinoTheme resolves AppTypography.cupertinoTextTheme', (tester) async {
    late TextStyle resolvedTabLabelStyle;

    await tester.pumpWidget(
      CupertinoTheme(
        data: HabitLoopTheme.cupertinoTheme,
        child: Builder(
          builder: (context) {
            resolvedTabLabelStyle = CupertinoTheme.of(context).textTheme.tabLabelTextStyle;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // tabLabelTextStyle has no CupertinoTabBar consumer anywhere in the app
    // (yet), so AppTypography gives it a real, distinct value purely to make
    // this assertion meaningful: if `textTheme:` is ever dropped from
    // `HabitLoopTheme.cupertinoTheme`, this style falls back to Flutter's
    // own gray default and the test fails — proving the wiring is live, not
    // just defined and unused.
    expect(resolvedTabLabelStyle.fontSize, AppTypography.cupertinoTextTheme.tabLabelTextStyle.fontSize);
    expect(resolvedTabLabelStyle.color, AppTypography.cupertinoTextTheme.tabLabelTextStyle.color);
  });
}
