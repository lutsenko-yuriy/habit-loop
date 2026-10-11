import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/checklister/data/checklister_callback_parser.dart';
import 'package:habit_loop/infrastructure/deep_links/data/link_deduper.dart';
import 'package:habit_loop/navigation/checklister_callback_navigator.dart';

import '../infrastructure/deep_links/fake_incoming_link_service.dart';

final _sel = Uri.parse('habitloop://checklist/selected?pactId=p1&status=selected&checklistId=c1&checklistName=M');
final _run = Uri.parse('habitloop://checklist/run-finished?pactId=p1&showupId=s1&status=completed&checklistId=c1&runId=r1');

void main() {
  late List<SelectionCallback> selections;
  late List<RunCallback> runs;
  late ChecklisterCallbackNavigator navigator;

  setUp(() {
    selections = [];
    runs = [];
    navigator = ChecklisterCallbackNavigator(
      onSelection: (c) async => selections.add(c),
      onRun: (c) async => runs.add(c),
    );
  });

  test('routes a selection callback to the selection handler', () async {
    expect(await navigator.handle(_sel), isTrue);
    expect(selections.single.checklistId, 'c1');
    expect(runs, isEmpty);
  });

  test('routes a run callback to the run handler', () async {
    expect(await navigator.handle(_run), isTrue);
    expect(runs.single.runId, 'r1');
    expect(selections, isEmpty);
  });

  test('ignores malformed or foreign links', () async {
    expect(await navigator.handle(Uri.parse('habitloop://evil/selected?pactId=p1&status=cancelled')), isFalse);
    expect(await navigator.handle(Uri.parse('https://example.com')), isFalse);
    expect(selections, isEmpty);
    expect(runs, isEmpty);
  });

  test('default handlers are no-ops', () async {
    expect(await ChecklisterCallbackNavigator().handle(_sel), isTrue);
    expect(await ChecklisterCallbackNavigator().handle(_run), isTrue);
  });

  test('listen dispatches stream links, dropping repeated deliveries', () async {
    final service = FakeIncomingLinkService(initialLink: _sel);
    final sub = navigator.listen(service.links);
    service.emit(_sel); // duplicate delivery of the cold-start link
    service.emit(_run);
    await Future<void>.delayed(Duration.zero);

    expect(selections, hasLength(1));
    expect(runs, hasLength(1));
    await sub.cancel();
    await service.dispose();
  });

  test('a throwing handler does not kill the subscription', () async {
    var calls = 0;
    final nav = ChecklisterCallbackNavigator(
      onSelection: (c) async {
        calls++;
        throw StateError('boom');
      },
      deduper: LinkDeduper(window: Duration.zero),
    );
    final service = FakeIncomingLinkService();
    final sub = nav.listen(service.links);
    service.emit(_sel);
    await Future<void>.delayed(Duration.zero);
    service.emit(Uri.parse('habitloop://checklist/selected?pactId=p2&status=cancelled'));
    await Future<void>.delayed(Duration.zero);

    expect(calls, 2);
    await sub.cancel();
    await service.dispose();
  });
}
