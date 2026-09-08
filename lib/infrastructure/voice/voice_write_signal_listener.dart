import 'dart:async';

import 'package:flutter/services.dart';

/// HAB-269 WU2 — thin wrapper around an `EventChannel` that fires [listen]'s
/// callback whenever the native side (a Siri mark-done write, forwarded by
/// `AppDelegate.swift` after `MarkShowupDoneIntent.perform()` posts a Darwin
/// notification) signals a write. `main.dart` constructs one instance and
/// passes a callback that invalidates `dashboardRefreshSignalProvider` —
/// otherwise a live-in-background Flutter engine's caches would go stale
/// after a Siri-triggered mark-done.
///
/// No-throw contract, matching the rest of `lib/infrastructure/`: a stream
/// error from the platform side never propagates, it's just dropped.
class VoiceWriteSignalListener {
  VoiceWriteSignalListener({EventChannel? channel}) : _channel = channel ?? const EventChannel(_channelName);

  static const _channelName = 'com.habitloop.voice_write_signal';

  final EventChannel _channel;
  StreamSubscription<dynamic>? _subscription;

  /// Starts listening; [onSignal] is invoked once per event delivered on the
  /// channel (the event payload itself carries no information — the mere
  /// arrival of an event is the signal).
  void listen(void Function() onSignal) {
    _subscription = _channel.receiveBroadcastStream().listen(
          (_) => onSignal(),
          onError: (_) {},
        );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
