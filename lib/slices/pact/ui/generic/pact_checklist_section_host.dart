import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_checklist_section_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_checklist_section_view_model.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_checklist_section_ios.dart';

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
  void initState() {
    super.initState();
    unawaited(Future.microtask(() {
      if (mounted) unawaited(ref.read(pactChecklistSectionViewModelProvider(widget.pactId).notifier).load());
    }));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(featureFlagsProvider).checklisterIntegrationEnabled;
    final installed = ref.watch(checklisterInstalledProvider).valueOrNull ?? false;
    // Watched before the early return so the autoDispose VM stays alive for load().
    final provider = pactChecklistSectionViewModelProvider(widget.pactId);
    final state = ref.watch(provider);
    if (!enabled || !installed) return const SizedBox.shrink();

    final vm = ref.read(provider.notifier);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return PactChecklistSectionIos(
        state: state,
        onSelect: () => unawaited(vm.startSelection()),
        onChange: () => unawaited(vm.startSelection()),
        onRemove: () => unawaited(vm.remove()),
      );
    }
    return PactChecklistSectionAndroid(
      state: state,
      onSelect: () => unawaited(vm.startSelection()),
      onChange: () => unawaited(vm.startSelection()),
      onRemove: () => unawaited(vm.remove()),
    );
  }
}
