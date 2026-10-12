import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/checklist/checklist_run.dart';

/// Set when a run-finished callback was applied for the showup (GH #464); the
/// showup detail VM consumes it (re-reads the gate, shows the failure dialog).
final checklistRunFinishedNoticeProvider = StateProvider.family<ChecklistRunOutcome?, String>((ref, showupId) => null);
