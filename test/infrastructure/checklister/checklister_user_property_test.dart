import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/checklister/application/publish_checklister_installed_property.dart';

import '../analytics/fake_analytics_service.dart';
import 'fake_checklister_gateway.dart';

void main() {
  test('publishes has_checklister_installed=true when installed', () async {
    final analytics = FakeAnalyticsService();
    await publishChecklisterInstalledProperty(FakeChecklisterGateway(installed: true), analytics);
    expect(analytics.setUserProperties, [(name: 'has_checklister_installed', value: 'true')]);
  });

  test('publishes false when not installed', () async {
    final analytics = FakeAnalyticsService();
    await publishChecklisterInstalledProperty(FakeChecklisterGateway(installed: false), analytics);
    expect(analytics.setUserProperties, [(name: 'has_checklister_installed', value: 'false')]);
  });
}
