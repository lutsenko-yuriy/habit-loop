/// Drops a link identical to the previous one delivered within [window] (some
/// platforms deliver the same incoming link twice).
class LinkDeduper {
  LinkDeduper({this.window = const Duration(seconds: 2), DateTime Function()? now}) : _now = now ?? DateTime.now;

  final Duration window;
  final DateTime Function() _now;

  String? _lastLink;
  DateTime? _lastAt;

  bool isDuplicate(Uri uri) {
    final link = uri.toString();
    final now = _now();
    final duplicate = link == _lastLink && _lastAt != null && now.difference(_lastAt!) < window;
    _lastLink = link;
    _lastAt = now;
    return duplicate;
  }
}
