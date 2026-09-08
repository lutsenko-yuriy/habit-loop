import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/voice/voice_write_signal_listener.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = EventChannel('com.habitloop.voice_write_signal');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockStreamHandler(channel, null);
  });

  test('listen invokes the callback for every event delivered on the channel', () async {
    late MockStreamHandlerEventSink sink;
    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (args, events) => sink = events,
      ),
    );

    var callCount = 0;
    final listener = VoiceWriteSignalListener();
    listener.listen(() => callCount++);
    // Let the subscription's listen() call reach the platform channel.
    await Future<void>.delayed(Duration.zero);

    sink.success(true);
    await Future<void>.delayed(Duration.zero);
    sink.success(true);
    await Future<void>.delayed(Duration.zero);

    expect(callCount, 2);
    await listener.dispose();
  });

  test('a stream error does not crash and does not invoke the callback', () async {
    late MockStreamHandlerEventSink sink;
    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(onListen: (args, events) => sink = events),
    );

    var callCount = 0;
    final listener = VoiceWriteSignalListener();
    listener.listen(() => callCount++);
    await Future<void>.delayed(Duration.zero);

    sink.error(code: 'boom');
    await Future<void>.delayed(Duration.zero);

    expect(callCount, 0);
    await listener.dispose();
  });

  test('dispose cancels the subscription', () async {
    var onCancelCalled = false;
    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (args, events) {},
        onCancel: (args) => onCancelCalled = true,
      ),
    );

    final listener = VoiceWriteSignalListener();
    listener.listen(() {});
    await Future<void>.delayed(Duration.zero);
    await listener.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(onCancelCalled, isTrue);
  });
}
