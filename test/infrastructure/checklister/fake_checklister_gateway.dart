import 'package:habit_loop/infrastructure/checklister/contracts/checklister_gateway.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_links.dart';

/// Hermetic [ChecklisterGateway]: records the URLs it would have opened.
class FakeChecklisterGateway implements ChecklisterGateway {
  FakeChecklisterGateway({this.installed = true});

  bool installed;

  /// When `false`, launches report failure (as `launchUrl` returning false).
  bool canLaunch = true;

  final List<Uri> launchedUrls = [];

  /// Called with each URL just before it is (or fails to be) launched.
  void Function(Uri uri)? onLaunch;

  @override
  Future<bool> isInstalled() async => installed;

  @override
  Future<bool> launchSelect(String callbackUrl) async => _launch(ChecklisterLinks.selectUri(callbackUrl));

  @override
  Future<bool> launchRun(String checklistId, String callbackUrl) async =>
      _launch(ChecklisterLinks.runUri(checklistId, callbackUrl));

  bool _launch(Uri uri) {
    onLaunch?.call(uri);
    if (!canLaunch) return false;
    launchedUrls.add(uri);
    return true;
  }
}
