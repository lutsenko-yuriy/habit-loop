import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/auth/data/first_launch_auth_fix.dart';
import 'package:habit_loop/infrastructure/device/data/shared_preferences_device_id_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_auth_service.dart';

void main() {
  group('clearStaleKeychainIfFirstLaunch', () {
    tearDown(() => SharedPreferences.resetStatic());

    test('does nothing when no Firebase user is cached (already signed out)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = FakeAuthService(userId: null, isAnonymous: true);

      await clearStaleKeychainIfFirstLaunch(authService: auth, prefs: prefs);

      expect(auth.currentUserId, isNull);
    });

    test('does nothing when device ID key exists (returning user on same install)', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesDeviceIdService.prefsKey: 'some-device-id',
      });
      final prefs = await SharedPreferences.getInstance();
      final auth = FakeAuthService(userId: 'google-uid', isAnonymous: false);

      await clearStaleKeychainIfFirstLaunch(authService: auth, prefs: prefs);

      expect(auth.currentUserId, equals('google-uid'));
    });

    test('calls signOut when Firebase user exists but no device ID key (fresh install after reinstall)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = FakeAuthService(userId: 'stale-google-uid', isAnonymous: false);

      await clearStaleKeychainIfFirstLaunch(authService: auth, prefs: prefs);

      expect(auth.currentUserId, isNull);
      expect(auth.isAnonymous, isTrue);
    });

    test('also clears anonymous Keychain user on fresh install', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // Can happen if the anonymous sign-in was cached in Keychain from prior install
      final auth = FakeAuthService(userId: 'anon-uid', isAnonymous: true);

      await clearStaleKeychainIfFirstLaunch(authService: auth, prefs: prefs);

      expect(auth.currentUserId, isNull);
    });
  });
}
