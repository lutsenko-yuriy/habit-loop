import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/main.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_screen.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/theme/colors.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

// WCAG AA requires >= 4.5:1 for normal-sized text.
double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  testWidgets('HabitLoopApp applies the shared Habit Loop brand color', (tester) async {
    final pactRepo = InMemoryPactRepository();
    final showupRepo = InMemoryShowupRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactTransactionServiceProvider.overrideWithValue(
            InMemoryPactTransactionService(pactRepo, showupRepo),
          ),
        ],
        child: HabitLoopApp(navigatorKey: GlobalKey<NavigatorState>()),
      ),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      materialApp.theme?.colorScheme.primary,
      HabitLoopColors.primary,
    );

    final dashboardContext = tester.element(find.byType(DashboardScreen));
    expect(
      CupertinoTheme.of(dashboardContext).primaryColor,
      HabitLoopColors.primary,
    );
  });

  group('HabitLoopTheme — on-color contrast against overridden brand colors', () {
    // ColorScheme.fromSeed(...).copyWith(primary: HabitLoopColors.primary, ...) pins each
    // brand role to a fixed brand color, but the seed algorithm's auto-derived "on*" colors
    // stay paired to its own (different) auto-generated tone — not the literal brand override.
    // In dark mode this silently drops FilledButton/CupertinoButton.filled text (which uses
    // colorScheme.onPrimary) below the 4.5:1 AA minimum against the always-teal primary.
    for (final theme in [HabitLoopTheme.materialTheme, HabitLoopTheme.darkMaterialTheme]) {
      final mode = theme.brightness.name;
      final cs = theme.colorScheme;

      testWidgets('onPrimary meets AA contrast against primary ($mode)', (tester) async {
        expect(_contrastRatio(cs.onPrimary, cs.primary), greaterThanOrEqualTo(4.5));
      });

      testWidgets('onSecondary meets AA contrast against secondary ($mode)', (tester) async {
        expect(_contrastRatio(cs.onSecondary, cs.secondary), greaterThanOrEqualTo(4.5));
      });

      testWidgets('onTertiary meets AA contrast against tertiary ($mode)', (tester) async {
        expect(_contrastRatio(cs.onTertiary, cs.tertiary), greaterThanOrEqualTo(4.5));
      });

      testWidgets('onError meets AA contrast against error ($mode)', (tester) async {
        expect(_contrastRatio(cs.onError, cs.error), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('HabitLoopColors.secondaryText — AA contrast against systemBackground', () {
    // Verified directly against the token rather than via a whole-screen sweep:
    // whole-page meetsGuideline(textContrastGuideline) checks are fragile against
    // unrelated, pre-existing contrast issues elsewhere on the same screen
    // (e.g. systemGreen/systemRed outcome text, or primary-as-text-on-dark-surface
    // — both out of scope for this WU, see HAB-187 debrief notes).
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('meets 4.5:1 in ${brightness.name} mode', (tester) async {
        late BuildContext capturedCtx;
        await tester.pumpWidget(CupertinoApp(
          theme: CupertinoThemeData(brightness: brightness),
          home: Builder(builder: (ctx) {
            capturedCtx = ctx;
            return const SizedBox.shrink();
          }),
        ));

        final textColor = HabitLoopColors.secondaryText(capturedCtx);
        final background = CupertinoColors.systemBackground.resolveFrom(capturedCtx);
        expect(_contrastRatio(textColor, background), greaterThanOrEqualTo(4.5));
      });
    }
  });
}
