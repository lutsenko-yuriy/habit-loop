import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';

/// Firebase user property name (max 24 chars).
const checklisterInstalledUserProperty = 'checklister_installed';

/// Non-rendering wrapper that re-checks whether Checklister is installed after
/// the first frame and on app resume (throttled by [minInterval]), refreshing
/// `checklisterInstalledProvider` and the `checklister_installed` user property.
class ChecklisterInstallWatcher extends ConsumerStatefulWidget {
  const ChecklisterInstallWatcher({super.key, required this.child, this.minInterval = const Duration(seconds: 5)});

  final Widget child;
  final Duration minInterval;

  @override
  ConsumerState<ChecklisterInstallWatcher> createState() => _ChecklisterInstallWatcherState();
}

class _ChecklisterInstallWatcherState extends ConsumerState<ChecklisterInstallWatcher> with WidgetsBindingObserver {
  DateTime? _lastCheck;
  bool? _published;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check(initial: true)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check({bool initial = false}) async {
    final now = DateTime.now();
    final last = _lastCheck;
    if (last != null && now.difference(last) < widget.minInterval) return;
    _lastCheck = now;
    try {
      // The first read already resolves fresh; later checks must drop the cached value.
      if (!initial) ref.invalidate(checklisterInstalledProvider);
      final installed = await ref.read(checklisterInstalledProvider.future);
      if (!mounted || installed == _published) return;
      _published = installed;
      await ref.read(analyticsServiceProvider).setUserProperty(checklisterInstalledUserProperty, '$installed');
    } catch (_) {
      // Best-effort: a failed probe or analytics call must never surface.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
