import 'package:habit_loop/domain/checklist/checklist_run.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_callback.dart';
import 'package:habit_loop/slices/checklist/application/checklist_service.dart';

/// Applies a Checklister run-finished callback and reports an applied outcome
/// through [onFinished]; ignored callbacks (spoofed, duplicate, or with the
/// integration switched off) report nothing.
class ChecklisterRunHandler {
  ChecklisterRunHandler({
    required ChecklistService service,
    required bool Function() isEnabled,
    required void Function(String showupId, ChecklistRunOutcome outcome) onFinished,
  })  : _service = service,
        _isEnabled = isEnabled,
        _onFinished = onFinished;

  final ChecklistService _service;
  final bool Function() _isEnabled;
  final void Function(String showupId, ChecklistRunOutcome outcome) _onFinished;

  Future<void> call(RunCallback callback) async {
    if (!_isEnabled()) return;
    final outcome = await _service.applyRunResult(callback);
    if (outcome != null) _onFinished(callback.showupId, outcome);
  }
}
