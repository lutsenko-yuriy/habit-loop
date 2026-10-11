import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/checklist/checklist_run.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';
import 'package:habit_loop/infrastructure/persistence/checklist_run_mapper.dart';
import 'package:habit_loop/infrastructure/persistence/pact_checklist_link_mapper.dart';

void main() {
  test('PactChecklistLinkMapper round-trips and has no sync columns', () {
    final link =
        PactChecklistLink(pactId: 'p', checklistId: 'c', checklistName: 'Morning', linkedAt: DateTime(2026, 5, 1, 7));
    final row = PactChecklistLinkMapper.toRow(link);
    expect(row.keys, unorderedEquals(['pact_id', 'checklist_id', 'checklist_name', 'linked_at']));
    expect(PactChecklistLinkMapper.fromRow(row), link);
  });

  test('ChecklistRunMapper round-trips an unfinished run', () {
    final run = ChecklistRun(showupId: 's', pactId: 'p', checklistId: 'c', startedAt: DateTime(2026, 5, 1, 7));
    final row = ChecklistRunMapper.toRow(run);
    expect(row['finished_at'], isNull);
    expect(row['outcome'], isNull);
    expect(ChecklistRunMapper.fromRow(row), run);
  });

  for (final outcome in ChecklistRunOutcome.values) {
    test('ChecklistRunMapper round-trips a finished run ($outcome)', () {
      final run = ChecklistRun(
        showupId: 's',
        pactId: 'p',
        checklistId: 'c',
        startedAt: DateTime(2026, 5, 1, 7),
        finishedAt: DateTime(2026, 5, 1, 7, 10),
        outcome: outcome,
      );
      expect(ChecklistRunMapper.fromRow(ChecklistRunMapper.toRow(run)), run);
    });
  }
}
