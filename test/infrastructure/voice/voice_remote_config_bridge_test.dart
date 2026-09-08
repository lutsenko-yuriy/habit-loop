import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/voice/voice_remote_config_bridge.dart';

import '../remote_config/fake_remote_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.habitloop.voice_remote_config');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('sync writes the current voice_mark_done_enabled value to the platform channel', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return null;
    });

    final rc = FakeRemoteConfigService(overrides: {'voice_mark_done_enabled': true});
    await VoiceRemoteConfigBridge().sync(rc);

    expect(received?.method, 'setVoiceMarkDoneEnabled');
    expect(received?.arguments, {'enabled': true});
  });

  test('sync writes false when the flag is off', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return null;
    });

    final rc = FakeRemoteConfigService(overrides: {'voice_mark_done_enabled': false});
    await VoiceRemoteConfigBridge().sync(rc);

    expect(received?.arguments, {'enabled': false});
  });

  test('sync swallows a platform channel failure (e.g. Android, no handler registered)', () async {
    // No mock handler registered — invokeMethod throws MissingPluginException.
    final rc = FakeRemoteConfigService(overrides: {'voice_mark_done_enabled': true});
    await expectLater(VoiceRemoteConfigBridge().sync(rc), completes);
  });
}
