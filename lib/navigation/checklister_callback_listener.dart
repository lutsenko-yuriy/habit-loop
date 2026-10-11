import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_callback.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/navigation/checklister_callback_navigator.dart';
import 'package:habit_loop/slices/checklist/application/checklist_service.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_checklist_section_signals.dart';

/// Non-rendering wrapper that subscribes once to `incomingLinkServiceProvider` and
/// routes Checklister callbacks to [ChecklisterCallbackNavigator].
class ChecklisterCallbackListener extends ConsumerStatefulWidget {
  const ChecklisterCallbackListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ChecklisterCallbackListener> createState() => _ChecklisterCallbackListenerState();
}

class _ChecklisterCallbackListenerState extends ConsumerState<ChecklisterCallbackListener> {
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ChecklisterCallbackNavigator(onSelection: _onSelection).listen(
      ref.read(incomingLinkServiceProvider).links,
    );
  }

  Future<void> _onSelection(SelectionCallback callback) async {
    final outcome = await ref.read(checklistServiceProvider).applySelection(callback);
    if (!mounted) return;
    if (outcome == SelectionOutcome.noChecklists) {
      ref.read(checklistNoChecklistsNoticeProvider(callback.pactId).notifier).state = true;
    }
    if (outcome != SelectionOutcome.ignored) {
      ref.read(checklistSectionRefreshSignalProvider.notifier).update((n) => n + 1);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
