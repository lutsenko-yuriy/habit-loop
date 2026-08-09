// Integration tests for merging break runs into a single timeline milestone,
// tail zone included (HAB-216).
//
// Run on host:   flutter test integration_test/break_timeline_flow_test.dart
// Run on device: flutter test integration_test/break_timeline_flow_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Pact timeline — merged break milestones (HAB-216)', () {
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('break_inside_tailzone_renders_as_one_milestone', (tester) async {
      // TODO: 1. Set tail period to 7 days (RC override), pact_breaks_enabled: true, now = Jun 15.
      // TODO: 2. Seed the active pact and a break startDate Jun 10, plannedEndDate Jun 13
      //          (wholly inside the Jun 8 tail cutoff), rationale "Feeling sick".
      // TODO: 3. Seed 4 pending showups Jun 10-13, all covered by the break.
      // TODO: 4. Open pact detail -> open timeline.
      // TODO: 5. Verify the rationale text "Feeling sick" appears exactly once (single merged
      //          milestone, not 4).
      // TODO: 6. Verify no individual timeline-milestone-<id> key exists for any of the 4
      //          covered showups.
      // TODO: 7. Verify the milestone's y-position is below the "Showups from the last 7 days" header.
    });

    testWidgets('break_spanning_tailzone_boundary_renders_as_one_milestone_below_header', (tester) async {
      // TODO: 1. Same RC setup (tail=7, cutoff=Jun 8).
      // TODO: 2. Seed a break startDate Jun 5 (before cutoff), plannedEndDate Jun 10 (inside
      //          tail), rationale "Travel".
      // TODO: 3. Seed 6 covered showups Jun 5-10.
      // TODO: 4. Open timeline.
      // TODO: 5. Verify "Travel" appears exactly once (not split into a grouped part + individual
      //          tail entries).
      // TODO: 6. Verify no individual milestone keys exist for the 6 covered showups.
      // TODO: 7. Verify the milestone's y-position is below the header (since part of it touches
      //          the tail).
    });

    testWidgets('break_outside_tailzone_stays_above_header', (tester) async {
      // TODO: 1. Same RC setup (tail=7, cutoff=Jun 8).
      // TODO: 2. Seed a break startDate Jun 1, plannedEndDate Jun 3, rationale "Feeling sick",
      //          with 3 covered showups.
      // TODO: 3. Seed an unrelated done showup Jun 10 (inside tail) so the header actually renders.
      // TODO: 4. Open timeline.
      // TODO: 5. Verify "Feeling sick" appears exactly once.
      // TODO: 6. Verify the milestone's y-position is above the header.
    });

    testWidgets('explicit_mark_inside_break_does_not_split_break_milestone', (tester) async {
      // TODO: 1. Same RC setup. Seed a break Jun 10-13, rationale "Feeling sick".
      // TODO: 2. Seed showups Jun 10, 12, 13 pending (covered) and Jun 11 explicitly done.
      // TODO: 3. Open timeline.
      // TODO: 4. Verify "Feeling sick" appears exactly once (one milestone spanning all 4 days,
      //          not two around the done showup).
      // TODO: 5. Verify no individual timeline-milestone-<id> key exists for the Jun 11 showup.
      // TODO: 6. Navigate to pact detail; verify the "Showups done" stat (l10n.statsShowups(1))
      //          reflects the Jun 11 done mark - stats unaffected by the visual merge.
    });

    testWidgets('two_adjacent_breaks_render_as_two_milestones', (tester) async {
      // TODO: 1. Same RC setup. Seed break A: Jun 10-11, rationale "Feeling sick". Seed break B:
      //          Jun 12-13, rationale "Travel" (immediately adjacent, no gap).
      // TODO: 2. Seed covered showups Jun 10-13.
      // TODO: 3. Open timeline.
      // TODO: 4. Verify both "Feeling sick" and "Travel" each appear exactly once (two separate
      //          milestones).
    });
  });
}
