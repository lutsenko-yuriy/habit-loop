import 'package:habit_loop/infrastructure/deep_links/contracts/incoming_link_service.dart';

/// Inert default: never emits.
class NoopIncomingLinkService implements IncomingLinkService {
  const NoopIncomingLinkService();

  @override
  Stream<Uri> get links => const Stream<Uri>.empty();
}
