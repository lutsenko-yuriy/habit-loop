import 'package:flutter/widgets.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_checklist_section_state.dart';

/// Pact-detail "Checklist" section (GH #464). Presentational: state in, callbacks out.
class PactChecklistSectionAndroid extends StatelessWidget {
  const PactChecklistSectionAndroid({
    super.key,
    required this.state,
    required this.onSelect,
    required this.onChange,
    required this.onRemove,
  });

  final PactChecklistSectionState state;
  final VoidCallback onSelect;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
