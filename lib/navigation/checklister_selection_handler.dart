import 'dart:ui' show VoidCallback;

import 'package:habit_loop/infrastructure/checklister/contracts/checklister_callback.dart';
import 'package:habit_loop/slices/checklist/application/checklist_service.dart';

/// Applies a Checklister selection callback and reports what the UI should react to.
class ChecklisterSelectionHandler {
  ChecklisterSelectionHandler({
    required ChecklistService service,
    required void Function(String pactId) onNoChecklists,
    required VoidCallback onChanged,
  });

  Future<void> call(SelectionCallback callback) async => throw UnimplementedError();
}
