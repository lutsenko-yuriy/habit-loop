import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/deep_links/data/app_links_incoming_link_service.dart';

void main() {
  test('forwards the underlying uri stream', () async {
    final source = StreamController<Uri>();
    final service = AppLinksIncomingLinkService(stream: source.stream);
    final received = <Uri>[];
    final sub = service.links.listen(received.add);

    source.add(Uri.parse('habitloop://checklist/selected?pactId=p1'));
    await Future<void>.delayed(Duration.zero);

    expect(received, [Uri.parse('habitloop://checklist/selected?pactId=p1')]);
    await sub.cancel();
    await source.close();
  });
}
