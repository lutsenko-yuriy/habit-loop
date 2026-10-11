import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/checklister/data/noop_checklister_gateway.dart';

import 'fake_checklister_gateway.dart';

void main() {
  test('noop gateway reports not installed and cannot launch', () async {
    final g = NoopChecklisterGateway();
    expect(await g.isInstalled(), isFalse);
    expect(await g.launchSelect('cb'), isFalse);
    expect(await g.launchRun('c', 'cb'), isFalse);
  });

  test('fake gateway records launched URLs', () async {
    final g = FakeChecklisterGateway(installed: true);
    await g.launchSelect('habitloop://a');
    await g.launchRun('c1', 'habitloop://b');
    expect(g.launchedUrls.map((u) => u.host), ['select', 'run']);
    g.canLaunch = false;
    expect(await g.launchSelect('x'), isFalse);
  });
}
