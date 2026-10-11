/// Delivers `habitloop://` links that open or resume the app (GH #464).
///
/// A single stream covers cold-start and warm links; implementations must not
/// require a separate "initial link" call.
abstract interface class IncomingLinkService {
  Stream<Uri> get links;
}
