import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:habit_loop/infrastructure/checklister/data/checklister_callback_parser.dart';
import 'package:habit_loop/infrastructure/deep_links/data/link_deduper.dart';

typedef SelectionCallbackHandler = Future<void> Function(SelectionCallback callback);
typedef RunCallbackHandler = Future<void> Function(RunCallback callback);

Future<void> _noopSelection(SelectionCallback _) async {}
Future<void> _noopRun(RunCallback _) async {}

/// Routes parsed Checklister callbacks to handlers. Skeleton (GH #464 WU3): the
/// handlers default to no-ops; WU4 fills in [onSelection], WU6 fills in [onRun].
class ChecklisterCallbackNavigator {
  ChecklisterCallbackNavigator({
    this.onSelection = _noopSelection,
    this.onRun = _noopRun,
    LinkDeduper? deduper,
  }) : _deduper = deduper ?? LinkDeduper();

  final SelectionCallbackHandler onSelection;
  final RunCallbackHandler onRun;
  final LinkDeduper _deduper;

  /// Dispatches [uri]. Returns `false` if it is not a valid Checklister callback.
  Future<bool> handle(Uri uri) async {
    final callback = ChecklisterCallbackParser.parse(uri);
    if (callback == null) return false;
    switch (callback) {
      case SelectionCallback():
        await onSelection(callback);
      case RunCallback():
        await onRun(callback);
    }
    return true;
  }

  /// Subscribes to [links] for the app lifetime. Repeated deliveries are dropped and
  /// a failing handler never ends the subscription. Raw URLs are never logged.
  StreamSubscription<Uri> listen(Stream<Uri> links) {
    return links.listen((uri) async {
      if (_deduper.isDuplicate(uri)) return;
      try {
        await handle(uri);
      } catch (e) {
        debugPrint('[ChecklisterCallbackNavigator] handler failed: ${e.runtimeType}');
      }
    });
  }
}
