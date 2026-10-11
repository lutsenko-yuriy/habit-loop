import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/checklist/ui/generic/checklister_install_watcher.dart';

import '../../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../../infrastructure/checklister/fake_checklister_gateway.dart';

void main() {
  late FakeChecklisterGateway gateway;
  late FakeAnalyticsService analytics;
  late ProviderContainer container;

  Future<void> pumpWatcher(WidgetTester tester, {Duration minInterval = Duration.zero}) async {
    container = ProviderContainer(overrides: [
      checklisterGatewayProvider.overrideWithValue(gateway),
      analyticsServiceProvider.overrideWithValue(analytics),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: ChecklisterInstallWatcher(minInterval: minInterval, child: const SizedBox.shrink()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> resume(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  setUp(() {
    gateway = FakeChecklisterGateway(installed: false);
    analytics = FakeAnalyticsService();
  });

  testWidgets('publishes checklister_installed once after the first frame', (tester) async {
    await pumpWatcher(tester);
    expect(analytics.setUserProperties, [(name: 'checklister_installed', value: 'false')]);
  });

  testWidgets('re-checks on resume and republishes only when the value changes', (tester) async {
    await pumpWatcher(tester);
    await resume(tester);
    expect(analytics.setUserProperties, hasLength(1));

    gateway.installed = true;
    await resume(tester);
    expect(await container.read(checklisterInstalledProvider.future), isTrue);
    expect(analytics.setUserProperties.last, (name: 'checklister_installed', value: 'true'));
  });

  testWidgets('skips a resume re-check within minInterval of the last one', (tester) async {
    await pumpWatcher(tester, minInterval: const Duration(hours: 1));
    gateway.installed = true;
    await resume(tester);
    expect(await container.read(checklisterInstalledProvider.future), isFalse);
  });

  testWidgets('a throwing install check never escapes the widget', (tester) async {
    gateway = _ThrowingGateway();
    await pumpWatcher(tester);
    expect(tester.takeException(), isNull);
    expect(analytics.setUserProperties, isEmpty);
  });

  test('user property name fits Firebase limits (<=24 chars, letter first, [A-Za-z0-9_])', () {
    expect(checklisterInstalledUserProperty.length, lessThanOrEqualTo(24));
    expect(RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(checklisterInstalledUserProperty), isTrue);
  });
}

class _ThrowingGateway extends FakeChecklisterGateway {
  @override
  Future<bool> isInstalled() async => throw StateError('probe failed');
}
