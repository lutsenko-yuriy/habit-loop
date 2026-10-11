/// Builds the `checklister://` deep links defined by Checklister's external
/// contract (GH #464). Pure — no I/O.
abstract final class ChecklisterLinks {
  static const scheme = 'checklister';

  /// Our own callback scheme/host/paths, which Checklister opens after select/run.
  static const callbackScheme = 'habitloop';
  static const callbackHost = 'checklist';
  static const selectedPath = '/selected';
  static const runFinishedPath = '/run-finished';

  /// Bare link used only to ask the OS whether Checklister can handle its scheme.
  static final Uri probeUri = Uri(scheme: scheme, host: 'select');

  static Uri selectUri(String callbackUrl) => _build('select', {'callbackUrl': callbackUrl});

  static Uri runUri(String checklistId, String callbackUrl) =>
      _build('run', {'checklistId': checklistId, 'callbackUrl': callbackUrl});

  static Uri selectedCallback(String pactId) => _callback(selectedPath, {'pactId': pactId});

  static Uri runFinishedCallback(String pactId, String showupId) =>
      _callback(runFinishedPath, {'pactId': pactId, 'showupId': showupId});

  static Uri _callback(String path, Map<String, String> params) {
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return Uri.parse('$callbackScheme://$callbackHost$path?$query');
  }

  // Uri.queryParameters encodes spaces as '+'; build the query by hand with
  // percent-encoding so the receiver decodes every value unambiguously.
  static Uri _build(String host, Map<String, String> params) {
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return Uri.parse('$scheme://$host?$query');
  }
}
