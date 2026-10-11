import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_links.dart';

void main() {
  test('selectUri carries the encoded callback URL', () {
    final uri = ChecklisterLinks.selectUri('habitloop://checklist/selected?pactId=p1&x=a b');
    expect(uri.scheme, 'checklister');
    expect(uri.host, 'select');
    expect(
      uri.toString(),
      'checklister://select?callbackUrl=habitloop%3A%2F%2Fchecklist%2Fselected%3FpactId%3Dp1%26x%3Da%20b',
    );
    expect(uri.queryParameters['callbackUrl'], 'habitloop://checklist/selected?pactId=p1&x=a b');
  });

  test('runUri carries checklistId and the encoded callback URL', () {
    final uri = ChecklisterLinks.runUri('c 1', 'habitloop://checklist/run?showupId=s1');
    expect(uri.scheme, 'checklister');
    expect(uri.host, 'run');
    expect(uri.queryParameters['checklistId'], 'c 1');
    expect(uri.queryParameters['callbackUrl'], 'habitloop://checklist/run?showupId=s1');
  });

  test('probeUri uses the checklister scheme', () {
    expect(ChecklisterLinks.probeUri.scheme, 'checklister');
  });
}
