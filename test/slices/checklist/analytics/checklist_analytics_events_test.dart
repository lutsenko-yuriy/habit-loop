import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/checklist/analytics/checklist_analytics_events.dart';

void main() {
  test('PactChecklistSelectionStartedEvent', () {
    final e = PactChecklistSelectionStartedEvent(pactId: 'p1', mode: 'change');
    expect(e.name, 'pact_checklist_selection_started');
    expect(e.toParameters(), {'pact_id': 'p1', 'mode': 'change'});
  });

  test('PactChecklistLinkedEvent', () {
    final e = PactChecklistLinkedEvent(pactId: 'p1', mode: 'select');
    expect(e.name, 'pact_checklist_linked');
    expect(e.toParameters(), {'pact_id': 'p1', 'mode': 'select'});
  });

  test('PactChecklistUnlinkedEvent', () {
    final e = PactChecklistUnlinkedEvent(pactId: 'p1', daysLinked: 4);
    expect(e.name, 'pact_checklist_unlinked');
    expect(e.toParameters(), {'pact_id': 'p1', 'days_linked': 4});
  });
}
