// Integration tests for showup on-break polish (HAB-213): calendar strip
// overflow-dot color when only some of a day's showups are on break.
//
// Run on host:   flutter test integration_test/showup_on_break_flow_test.dart
// Run on device: flutter test integration_test/showup_on_break_flow_test.dart -d <device>
import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart' show Key, Theme;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';
import 'package:habit_loop/theme/colors.dart';
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

// pact_breaks_enabled now defaults to true (HAB-195 WU6) — this override is
// kept for explicitness/determinism, independent of the production default.
final _breaksEnabled = remoteConfigServiceProvider.overrideWithValue(
  FakeRemoteConfigService(overrides: {'pact_breaks_enabled': true}),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Calendar strip overflow dot', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('overflow_dot_not_blue_when_only_some_showups_on_break', (tester) async {
      final testNow = DateTime(2099, 6, 15, 7, 0);
      final pacts = [
        buildPact(id: 'test-pact-overflow-meditate', habitName: 'Meditate', startDate: DateTime(2099, 6, 15)),
        buildPact(id: 'test-pact-overflow-jog', habitName: 'Jog', startDate: DateTime(2099, 6, 15)),
        buildPact(id: 'test-pact-overflow-read', habitName: 'Read', startDate: DateTime(2099, 6, 15)),
        buildPact(id: 'test-pact-overflow-swim', habitName: 'Swim', startDate: DateTime(2099, 6, 15)),
      ];
      final onBreak = buildBreak(
        id: 'brk-overflow-1',
        pactId: 'test-pact-overflow-meditate',
        startDate: DateTime(2099, 6, 15),
        plannedEndDate: DateTime(2099, 6, 22),
        rationale: 'Feeling sick',
      );

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(testNow),
          pactListNowProvider.overrideWithValue(testNow),
          _breaksEnabled,
        ],
        beforePump: (h) async {
          for (final pact in pacts) {
            await h.pactRepo.savePact(pact);
          }
          await h.pactBreakRepo.saveBreak(onBreak);
        },
      );

      // ── 1. Dashboard load generates each pact's showup for today and
      //         resolves Meditate's alone to onBreak, the other three stay
      //         planned — wait for the overflow dot to appear. ─────────────
      const overflowKey = Key('status-dot-overflow-2099-06-15');
      await waitFor(tester, find.byKey(overflowKey));

      // ── 2. Only one of the four showups is on break — the overflow dot
      //         must fall back to the pending/grey priority color, not blue.
      //         Each platform page supplies its own statusColors instance
      //         (cupertino() on iOS, material() on Android — see
      //         dashboard_page_ios.dart / dashboard_page_android.dart), so
      //         the expected pending color must match the running platform. ─
      final container = tester.widget<Container>(find.byKey(overflowKey));
      final decoration = container.decoration as BoxDecoration;
      final ctx = tester.element(find.byKey(overflowKey));
      final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
      final expectedPending =
          isIOS ? CupertinoColors.systemGrey.resolveFrom(ctx) : Theme.of(ctx).colorScheme.onSurfaceVariant;
      final expectedOnBreak = isIOS ? CupertinoColors.systemBlue.resolveFrom(ctx) : HabitLoopColors.onBreak;
      expect(decoration.color, expectedPending);
      expect(decoration.color, isNot(equals(expectedOnBreak)));
    });
  });
}
