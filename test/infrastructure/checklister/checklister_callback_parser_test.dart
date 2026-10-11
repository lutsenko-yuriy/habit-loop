import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/checklister/data/checklister_callback_parser.dart';

ChecklisterCallback? parse(String url) => ChecklisterCallbackParser.parse(Uri.parse(url));

void main() {
  group('selection callbacks', () {
    test('selected carries checklist id and name', () {
      final cb = parse(
        'habitloop://checklist/selected?pactId=p1&status=selected&checklistId=c1&checklistName=Morning%20routine',
      );
      expect(cb, isA<SelectionCallback>());
      final s = cb! as SelectionCallback;
      expect(s.pactId, 'p1');
      expect(s.status, ChecklisterCallbackStatus.selected);
      expect(s.checklistId, 'c1');
      expect(s.checklistName, 'Morning routine');
    });

    test('selected without a name still parses', () {
      final s = parse('habitloop://checklist/selected?pactId=p1&status=selected&checklistId=c1')! as SelectionCallback;
      expect(s.checklistName, isNull);
    });

    test('selected without checklistId is rejected', () {
      expect(parse('habitloop://checklist/selected?pactId=p1&status=selected'), isNull);
      expect(parse('habitloop://checklist/selected?pactId=p1&status=selected&checklistId='), isNull);
    });

    test('cancelled and error parse without a checklist', () {
      for (final st in ['cancelled', 'error']) {
        final s = parse('habitloop://checklist/selected?pactId=p1&status=$st')! as SelectionCallback;
        expect(s.status.name, st);
        expect(s.checklistId, isNull);
      }
    });

    test('status completed is not valid for selection', () {
      expect(parse('habitloop://checklist/selected?pactId=p1&status=completed&checklistId=c1'), isNull);
    });

    test('missing or empty pactId is rejected', () {
      expect(parse('habitloop://checklist/selected?status=cancelled'), isNull);
      expect(parse('habitloop://checklist/selected?pactId=&status=cancelled'), isNull);
    });

    test('ids with encoded special characters round-trip', () {
      final s = parse(
        'habitloop://checklist/selected?pactId=p%261%3D&status=selected&checklistId=%D0%B0%26b',
      )! as SelectionCallback;
      expect(s.pactId, 'p&1=');
      expect(s.checklistId, 'а&b');
    });
  });

  group('run-finished callbacks', () {
    test('completed carries ids and run id', () {
      final r = parse(
        'habitloop://checklist/run-finished?pactId=p1&showupId=s1&status=completed&checklistId=c1&runId=r1',
      )! as RunCallback;
      expect(r.pactId, 'p1');
      expect(r.showupId, 's1');
      expect(r.status, ChecklisterCallbackStatus.completed);
      expect(r.checklistId, 'c1');
      expect(r.runId, 'r1');
    });

    test('cancelled and error parse', () {
      for (final st in ['cancelled', 'error']) {
        final r =
            parse('habitloop://checklist/run-finished?pactId=p1&showupId=s1&status=$st&checklistId=c1')! as RunCallback;
        expect(r.status.name, st);
        expect(r.runId, isNull);
      }
    });

    test('status selected is not valid for a run', () {
      expect(parse('habitloop://checklist/run-finished?pactId=p1&showupId=s1&status=selected&checklistId=c1'), isNull);
    });

    test('missing showupId, pactId or checklistId is rejected', () {
      expect(parse('habitloop://checklist/run-finished?pactId=p1&status=cancelled&checklistId=c1'), isNull);
      expect(parse('habitloop://checklist/run-finished?showupId=s1&status=cancelled&checklistId=c1'), isNull);
      expect(parse('habitloop://checklist/run-finished?pactId=p1&showupId=s1&status=cancelled'), isNull);
    });

    test('completed without runId is rejected', () {
      expect(parse('habitloop://checklist/run-finished?pactId=p1&showupId=s1&status=completed&checklistId=c1'), isNull);
    });
  });

  group('rejections', () {
    test('foreign scheme', () {
      expect(parse('https://checklist/selected?pactId=p1&status=cancelled'), isNull);
      expect(parse('checklister://checklist/selected?pactId=p1&status=cancelled'), isNull);
    });

    test('unknown host', () {
      expect(parse('habitloop://evil/selected?pactId=p1&status=cancelled'), isNull);
    });

    test('unknown or extra path', () {
      expect(parse('habitloop://checklist/other?pactId=p1&status=cancelled'), isNull);
      expect(parse('habitloop://checklist/selected/extra?pactId=p1&status=cancelled'), isNull);
      expect(parse('habitloop://checklist?pactId=p1&status=cancelled'), isNull);
    });

    test('unknown or missing status', () {
      expect(parse('habitloop://checklist/selected?pactId=p1&status=weird'), isNull);
      expect(parse('habitloop://checklist/selected?pactId=p1'), isNull);
    });

    test('extra params are ignored', () {
      expect(parse('habitloop://checklist/selected?pactId=p1&status=cancelled&foo=bar'), isA<SelectionCallback>());
    });
  });
}
