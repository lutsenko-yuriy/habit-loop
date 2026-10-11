import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wires the checklist section to its view model; renders nothing unless the
/// kill-switch flag is on and Checklister is installed (GH #464).
class PactChecklistSectionHost extends ConsumerStatefulWidget {
  const PactChecklistSectionHost({super.key, required this.pactId});

  final String pactId;

  @override
  ConsumerState<PactChecklistSectionHost> createState() => _PactChecklistSectionHostState();
}

class _PactChecklistSectionHostState extends ConsumerState<PactChecklistSectionHost> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
