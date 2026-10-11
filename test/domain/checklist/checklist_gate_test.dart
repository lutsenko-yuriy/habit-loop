import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/checklist/checklist_gate.dart';
import 'package:habit_loop/domain/checklist/checklist_run.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';

void main() {
  final link = PactChecklistLink(pactId: 'p', checklistId: 'c', checklistName: 'N', linkedAt: DateTime(2026, 1, 1));
  final started = ChecklistRun(showupId: 's', pactId: 'p', checklistId: 'c', startedAt: DateTime(2026, 1, 2));
  final finished = ChecklistRun(
    showupId: 's',
    pactId: 'p',
    checklistId: 'c',
    startedAt: DateTime(2026, 1, 2),
    finishedAt: DateTime(2026, 1, 2, 0, 5),
    outcome: ChecklistRunOutcome.failure,
  );

  ChecklistGate gate({bool flag = true, bool installed = true, PactChecklistLink? l, ChecklistRun? run}) =>
      ChecklistGate.resolve(flagEnabled: flag, checklisterInstalled: installed, link: l, run: run);

  group('ChecklistGate.resolve truth table', () {
    test('flag off -> none, whatever else', () {
      expect(gate(flag: false, l: link), ChecklistGate.none);
      expect(gate(flag: false, l: link, run: finished), ChecklistGate.none);
    });
    test('not installed -> none (link kept)', () {
      expect(gate(installed: false, l: link), ChecklistGate.none);
    });
    test('no link -> none', () {
      expect(gate(), ChecklistGate.none);
      expect(gate(run: finished), ChecklistGate.none);
    });
    test('link and no run -> runRequired', () {
      expect(gate(l: link), ChecklistGate.runRequired);
    });
    test('link and started-but-unfinished run -> runRequired', () {
      expect(gate(l: link, run: started), ChecklistGate.runRequired);
    });
    test('link and finished run (any outcome) -> unlocked', () {
      expect(gate(l: link, run: finished), ChecklistGate.unlocked);
    });
  });
}
