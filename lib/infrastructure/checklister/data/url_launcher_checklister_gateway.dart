import 'package:habit_loop/infrastructure/checklister/contracts/checklister_gateway.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_links.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

/// [ChecklisterGateway] backed by `url_launcher`. The probe/launch functions
/// are injectable so URL handling is unit-testable without a platform channel.
class UrlLauncherChecklisterGateway implements ChecklisterGateway {
  UrlLauncherChecklisterGateway({
    Future<bool> Function(Uri)? canLaunch,
    Future<bool> Function(Uri)? launch,
  })  : _canLaunch = canLaunch ?? ul.canLaunchUrl,
        _launch = launch ?? ((uri) => ul.launchUrl(uri, mode: ul.LaunchMode.externalApplication));

  final Future<bool> Function(Uri) _canLaunch;
  final Future<bool> Function(Uri) _launch;

  @override
  Future<bool> isInstalled() async {
    try {
      return await _canLaunch(ChecklisterLinks.probeUri);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> launchSelect(String callbackUrl) => _safeLaunch(ChecklisterLinks.selectUri(callbackUrl));

  @override
  Future<bool> launchRun(String checklistId, String callbackUrl) =>
      _safeLaunch(ChecklisterLinks.runUri(checklistId, callbackUrl));

  Future<bool> _safeLaunch(Uri uri) async {
    try {
      return await _launch(uri);
    } catch (_) {
      return false;
    }
  }
}
