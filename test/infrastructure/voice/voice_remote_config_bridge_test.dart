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

  Future<Map<String, Object?>> syncAndCapture(Map<String, Object> overrides) async {
    final received = <String, Object?>{};
    messenger.setMockMethodCallHandler(channel, (call) async {
      received[call.method] = call.arguments;
      return null;
    });
    await VoiceRemoteConfigBridge().sync(FakeRemoteConfigService(overrides: overrides));
    return received;
  }

  test('sync writes the current voice_mark_done_enabled value to the platform channel', () async {
    final received = await syncAndCapture({'voice_mark_done_enabled': true});
    expect(received['setVoiceMarkDoneEnabled'], {'enabled': true});
  });

  test('sync writes false when the flag is off', () async {
    final received = await syncAndCapture({'voice_mark_done_enabled': false});
    expect(received['setVoiceMarkDoneEnabled'], {'enabled': false});
  });

  test('sync mirrors checklister_integration_enabled for the Siri checklist gate', () async {
    final on = await syncAndCapture({'checklister_integration_enabled': true});
    expect(on['setChecklisterIntegrationEnabled'], {'enabled': true});

    final off = await syncAndCapture({'checklister_integration_enabled': false});
    expect(off['setChecklisterIntegrationEnabled'], {'enabled': false});
  });

  test('sync swallows a platform channel failure (e.g. Android, no handler registered)', () async {
    // No mock handler registered — invokeMethod throws MissingPluginException.
    final rc = FakeRemoteConfigService(overrides: {'voice_mark_done_enabled': true});
    await expectLater(VoiceRemoteConfigBridge().sync(rc), completes);
  });
}
