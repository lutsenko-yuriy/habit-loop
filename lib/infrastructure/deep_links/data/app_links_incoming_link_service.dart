import 'package:app_links/app_links.dart';
import 'package:habit_loop/infrastructure/deep_links/contracts/incoming_link_service.dart';

/// `app_links`-backed [IncomingLinkService]. Subscribes to `uriLinkStream` only —
/// since app_links 7 it also delivers the cold-start link (see docs/knowledge/notes/GH-464.md).
class AppLinksIncomingLinkService implements IncomingLinkService {
  AppLinksIncomingLinkService({Stream<Uri>? stream}) : _stream = stream;

  final Stream<Uri>? _stream;

  @override
  Stream<Uri> get links => _stream ?? AppLinks().uriLinkStream;
}
