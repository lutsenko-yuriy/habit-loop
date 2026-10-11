import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/navigation/checklister_callback_navigator.dart';

/// Non-rendering wrapper that subscribes once to `incomingLinkServiceProvider` and
/// routes Checklister callbacks to [ChecklisterCallbackNavigator].
class ChecklisterCallbackListener extends ConsumerStatefulWidget {
  const ChecklisterCallbackListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ChecklisterCallbackListener> createState() => _ChecklisterCallbackListenerState();
}

class _ChecklisterCallbackListenerState extends ConsumerState<ChecklisterCallbackListener> {
  StreamSubscription<Uri>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ChecklisterCallbackNavigator().listen(ref.read(incomingLinkServiceProvider).links);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
