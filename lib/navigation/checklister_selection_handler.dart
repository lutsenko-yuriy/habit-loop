import 'dart:ui' show VoidCallback;

import 'package:habit_loop/infrastructure/checklister/contracts/checklister_callback.dart';
import 'package:habit_loop/slices/checklist/application/checklist_service.dart';

/// Applies a Checklister selection callback and reports what the UI should react to:
/// [onNoChecklists] when the picker had nothing to pick, [onChanged] for any applied
/// (non-ignored) outcome so open screens re-read.
class ChecklisterSelectionHandler {
  ChecklisterSelectionHandler({
    required ChecklistService service,
    required void Function(String pactId) onNoChecklists,
    required VoidCallback onChanged,
  })  : _service = service,
        _onNoChecklists = onNoChecklists,
        _onChanged = onChanged;

  final ChecklistService _service;
  final void Function(String pactId) _onNoChecklists;
  final VoidCallback _onChanged;

  Future<void> call(SelectionCallback callback) async {
    final outcome = await _service.applySelection(callback);
    if (outcome == SelectionOutcome.ignored) return;
    if (outcome == SelectionOutcome.noChecklists) _onNoChecklists(callback.pactId);
    _onChanged();
  }
}
