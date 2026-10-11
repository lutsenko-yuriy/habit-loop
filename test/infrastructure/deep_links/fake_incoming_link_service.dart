import 'dart:async';

import 'package:habit_loop/infrastructure/deep_links/contracts/incoming_link_service.dart';

/// Hermetic [IncomingLinkService]: [initialLink] is delivered first (like a cold-start
/// link), then anything pushed through [emit]. Events emitted before a listener
/// attaches are buffered.
class FakeIncomingLinkService implements IncomingLinkService {
  FakeIncomingLinkService({Uri? initialLink}) {
    if (initialLink != null) _controller.add(initialLink);
  }

  final StreamController<Uri> _controller = StreamController<Uri>();

  @override
  Stream<Uri> get links => _controller.stream;

  void emit(Uri uri) => _controller.add(uri);

  Future<void> dispose() => _controller.close();
}
