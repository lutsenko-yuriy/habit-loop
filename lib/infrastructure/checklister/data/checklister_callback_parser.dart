import 'package:habit_loop/infrastructure/checklister/contracts/checklister_callback.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_links.dart';

/// Parses Checklister's callbacks into [ChecklisterCallback]s. Pure; returns `null`
/// for anything that is not a well-formed `habitloop://checklist/...` callback.
abstract final class ChecklisterCallbackParser {
  static ChecklisterCallback? parse(Uri uri) {
    if (uri.scheme != ChecklisterLinks.callbackScheme || uri.host != ChecklisterLinks.callbackHost) return null;
    final q = uri.queryParameters;
    final pactId = _nonEmpty(q['pactId']);
    final status = _status(q['status']);
    if (pactId == null || status == null) return null;

    switch (uri.path) {
      case ChecklisterLinks.selectedPath:
        if (status == ChecklisterCallbackStatus.completed) return null;
        final checklistId = _nonEmpty(q['checklistId']);
        if (status == ChecklisterCallbackStatus.selected && checklistId == null) return null;
        return SelectionCallback(
          pactId: pactId,
          status: status,
          checklistId: checklistId,
          checklistName: _nonEmpty(q['checklistName']),
        );
      case ChecklisterLinks.runFinishedPath:
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
