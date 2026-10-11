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
