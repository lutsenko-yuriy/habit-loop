import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/checklister/data/url_launcher_checklister_gateway.dart';

void main() {
  final launched = <Uri>[];
  var canLaunchResult = true;
  var launchResult = true;
  var throwOnCan = false;
  var throwOnLaunch = false;

  late UrlLauncherChecklisterGateway gateway;

  setUp(() {
    launched.clear();
    canLaunchResult = true;
    launchResult = true;
    throwOnCan = false;
    throwOnLaunch = false;
    gateway = UrlLauncherChecklisterGateway(
      canLaunch: (uri) async {
        if (throwOnCan) throw Exception('boom');
        return canLaunchResult;
      },
      launch: (uri) async {
        if (throwOnLaunch) throw Exception('boom');
        launched.add(uri);
        return launchResult;
      },
    );
  });

  test('isInstalled reflects canLaunch', () async {
    expect(await gateway.isInstalled(), isTrue);
    canLaunchResult = false;
    expect(await gateway.isInstalled(), isFalse);
  });

  test('isInstalled is false when canLaunch throws', () async {
    throwOnCan = true;
    expect(await gateway.isInstalled(), isFalse);
  });

  test('launchSelect opens the select link', () async {
    expect(await gateway.launchSelect('habitloop://cb'), isTrue);
    expect(launched.single.toString(), 'checklister://select?callbackUrl=habitloop%3A%2F%2Fcb');
  });

  test('launchRun opens the run link', () async {
    expect(await gateway.launchRun('c1', 'habitloop://cb'), isTrue);
    expect(launched.single.host, 'run');
    expect(launched.single.queryParameters, {'checklistId': 'c1', 'callbackUrl': 'habitloop://cb'});
  });

  test('launch returns false when the OS cannot open the link or throws', () async {
    launchResult = false;
    expect(await gateway.launchSelect('x'), isFalse);
    launchResult = true;
    throwOnLaunch = true;
    expect(await gateway.launchRun('c', 'x'), isFalse);
  });
}
