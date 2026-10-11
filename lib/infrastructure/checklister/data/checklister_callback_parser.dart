enum ChecklisterCallbackStatus { selected, completed, cancelled, error }

sealed class ChecklisterCallback {
  const ChecklisterCallback({required this.pactId, required this.status});

  final String pactId;
  final ChecklisterCallbackStatus status;
}

/// `habitloop://checklist/selected` — result of Checklister's checklist picker.
class SelectionCallback extends ChecklisterCallback {
  const SelectionCallback({required super.pactId, required super.status, this.checklistId, this.checklistName});

  final String? checklistId;
  final String? checklistName;
}

/// `habitloop://checklist/run-finished` — result of running a checklist for a showup.
class RunCallback extends ChecklisterCallback {
  const RunCallback({
    required super.pactId,
    required this.showupId,
    required super.status,
    required this.checklistId,
    this.runId,
  });

  final String showupId;
  final String checklistId;
  final String? runId;
}

/// Parses Checklister's callbacks into [ChecklisterCallback]s. Pure; returns `null`
/// for anything that is not a well-formed `habitloop://checklist/...` callback.
abstract final class ChecklisterCallbackParser {
  static const scheme = 'habitloop';
  static const host = 'checklist';
  static const selectedPath = '/selected';
  static const runFinishedPath = '/run-finished';

  static ChecklisterCallback? parse(Uri uri) {
    if (uri.scheme != scheme || uri.host != host) return null;
    final q = uri.queryParameters;
    final pactId = _nonEmpty(q['pactId']);
    final status = _status(q['status']);
    if (pactId == null || status == null) return null;

    switch (uri.path) {
      case selectedPath:
        if (status == ChecklisterCallbackStatus.completed) return null;
        final checklistId = _nonEmpty(q['checklistId']);
        if (status == ChecklisterCallbackStatus.selected && checklistId == null) return null;
        return SelectionCallback(
          pactId: pactId,
          status: status,
          checklistId: checklistId,
          checklistName: _nonEmpty(q['checklistName']),
        );
      case runFinishedPath:
        if (status == ChecklisterCallbackStatus.selected) return null;
        final showupId = _nonEmpty(q['showupId']);
        final checklistId = _nonEmpty(q['checklistId']);
        final runId = _nonEmpty(q['runId']);
        if (showupId == null || checklistId == null) return null;
        if (status == ChecklisterCallbackStatus.completed && runId == null) return null;
        return RunCallback(pactId: pactId, showupId: showupId, status: status, checklistId: checklistId, runId: runId);
      default:
        return null;
    }
  }

  static String? _nonEmpty(String? v) => (v == null || v.isEmpty) ? null : v;

  static ChecklisterCallbackStatus? _status(String? raw) {
    for (final s in ChecklisterCallbackStatus.values) {
      if (s.name == raw) return s;
    }
    return null;
  }
}
