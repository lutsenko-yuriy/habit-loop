import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS disables Flutter built-in deep linking and registers habitloop://', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(RegExp(r'<key>FlutterDeepLinkingEnabled</key>\s*<false/>').hasMatch(plist), isTrue);
    expect(plist, contains('<string>habitloop</string>'));
  });

  test('Android disables Flutter built-in deep linking and handles habitloop://checklist', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      RegExp(r'android:name="flutter_deeplinking_enabled"\s+android:value="false"').hasMatch(manifest),
      isTrue,
    );
    expect(manifest, contains('android:scheme="habitloop" android:host="checklist"'));
  });
}
