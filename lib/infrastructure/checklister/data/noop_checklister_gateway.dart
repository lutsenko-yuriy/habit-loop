import 'package:habit_loop/infrastructure/checklister/contracts/checklister_gateway.dart';

/// Default gateway: Checklister is never installed and nothing launches.
class NoopChecklisterGateway implements ChecklisterGateway {
  @override
  Future<bool> isInstalled() async => false;

  @override
  Future<bool> launchSelect(String callbackUrl) async => false;

  @override
  Future<bool> launchRun(String checklistId, String callbackUrl) async => false;
}
