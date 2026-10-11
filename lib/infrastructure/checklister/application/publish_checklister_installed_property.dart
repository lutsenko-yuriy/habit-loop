import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_gateway.dart';

/// Sets the `has_checklister_installed` user property from the gateway's install check.
Future<void> publishChecklisterInstalledProperty(ChecklisterGateway gateway, AnalyticsService analytics) async {
  final installed = await gateway.isInstalled();
  await analytics.setUserProperty('has_checklister_installed', installed ? 'true' : 'false');
}
