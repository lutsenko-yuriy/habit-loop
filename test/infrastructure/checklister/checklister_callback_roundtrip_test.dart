import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_callback.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_links.dart';
import 'package:habit_loop/infrastructure/checklister/data/checklister_callback_parser.dart';

/// Simulates Checklister appending its params to our callback URL.
Uri appendParams(Uri base, Map<String, String> extra) =>
    base.replace(queryParameters: {...base.queryParameters, ...extra});

void main() {
  test('builders produce the documented URLs', () {
    expect(ChecklisterLinks.selectedCallback('p1').toString(), 'habitloop://checklist/selected?pactId=p1');
    expect(
      ChecklisterLinks.runFinishedCallback('p1', 's1').toString(),
      'habitloop://checklist/run-finished?pactId=p1&showupId=s1',
    );
  });

  test('builders percent-encode ids', () {
    final uri = ChecklisterLinks.runFinishedCallback('p&1', 's 1=');
    expect(uri.queryParameters, {'pactId': 'p&1', 'showupId': 's 1='});
  });

  group('selection round trip', () {
    final base = ChecklisterLinks.selectedCallback('p&1');

    test('selected', () {
      final cb = ChecklisterCallbackParser.parse(
        appendParams(base, {'status': 'selected', 'checklistId': 'c1', 'checklistName': 'Morning routine'}),
      )! as SelectionCallback;
      expect(cb.pactId, 'p&1');
      expect(cb.status, ChecklisterCallbackStatus.selected);
      expect(cb.checklistId, 'c1');
      expect(cb.checklistName, 'Morning routine');
    });

    for (final st in ['cancelled', 'error']) {
      test(st, () {
        final cb = ChecklisterCallbackParser.parse(appendParams(base, {'status': st}))! as SelectionCallback;
        expect(cb.pactId, 'p&1');
        expect(cb.status.name, st);
      });
    }
  });

  group('run round trip', () {
    final base = ChecklisterLinks.runFinishedCallback('p1', 's 1');

    test('completed', () {
      final cb = ChecklisterCallbackParser.parse(
        appendParams(base, {'status': 'completed', 'checklistId': 'c1', 'runId': 'r1'}),
      )! as RunCallback;
      expect((cb.pactId, cb.showupId, cb.checklistId, cb.runId), ('p1', 's 1', 'c1', 'r1'));
      expect(cb.status, ChecklisterCallbackStatus.completed);
    });

    for (final st in ['cancelled', 'error']) {
      test(st, () {
        final cb =
            ChecklisterCallbackParser.parse(appendParams(base, {'status': st, 'checklistId': 'c1'}))! as RunCallback;
        expect((cb.pactId, cb.showupId, cb.checklistId), ('p1', 's 1', 'c1'));
        expect(cb.status.name, st);
      });
    }
  });
}
