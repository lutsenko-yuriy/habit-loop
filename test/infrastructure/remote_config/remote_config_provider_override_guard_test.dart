// Guard test (HAB-260 WU3): keeps integration_test/ files from overriding
// remoteConfigServiceProvider directly. A direct override fully replaces the
// FakeRemoteConfigService instance AppHarness.create builds from
// TestRemoteConfigDefaults.all + remoteConfigOverrides, silently discarding
// that layering (the exact footgun this ticket exists to close — see
// harness.dart's `create` doc comment). Tests must use AppHarness.create's
// `remoteConfigOverrides` parameter instead.
//
// harness.dart itself is the one legitimate call site — it's what builds the
// layered FakeRemoteConfigService.withTestDefaults(...) override in the first
// place — so it is excluded from the scan.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no integration_test/ file overrides remoteConfigServiceProvider directly', () {
    final integrationTestDir = Directory('integration_test');
    expect(integrationTestDir.existsSync(), isTrue, reason: 'expected to run flutter test from the repo root');

    const forbiddenPattern = 'remoteConfigServiceProvider.overrideWithValue(';
    final violations = <String>[];

    for (final entity in integrationTestDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('${Platform.pathSeparator}harness.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains(forbiddenPattern)) {
          violations.add('${entity.path}:${i + 1}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Direct remoteConfigServiceProvider overrides bypass AppHarness.create\'s '
          'TestRemoteConfigDefaults layering (HAB-260). Use the remoteConfigOverrides '
          'parameter instead. Violations:\n${violations.join('\n')}',
    );
  });
}
