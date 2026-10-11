import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/navigation/checklister_callback_navigator.dart';
import 'package:habit_loop/navigation/checklister_selection_handler.dart';
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
    _subscription = ChecklisterCallbackNavigator(onSelection: _selectionHandler().call).listen(
      ref.read(incomingLinkServiceProvider).links,
    );
  }

  ChecklisterSelectionHandler _selectionHandler() => ChecklisterSelectionHandler(
        service: ref.read(checklistServiceProvider),
        onNoChecklists: (pactId) {
          if (mounted) ref.read(checklistNoChecklistsNoticeProvider(pactId).notifier).state = true;
        },
        onChanged: () {
          if (mounted) ref.read(checklistSectionRefreshSignalProvider.notifier).update((n) => n + 1);
        },
      );

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
