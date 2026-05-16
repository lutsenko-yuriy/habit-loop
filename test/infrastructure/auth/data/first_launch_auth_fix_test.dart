import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/auth/data/first_launch_auth_fix.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_auth_service.dart';

void main() {
  group('clearStaleKeychainIfFirstLaunch', () {
    tearDown(() => SharedPreferences.resetStatic());

    test('does nothing when launched key is already present (returning user)', () async {
      SharedPreferences.setMockInitialValues({firstLaunchHandledKey: true});
      final prefs = await SharedPreferences.getInstance();
      final auth = FakeAuthService(userId: 'google-uid', isAnonymous: false);

      await clearStaleKeychainIfFirstLaunch(authService: auth, prefs: prefs);

      expect(auth.currentUserId, equals('google-uid')); // Unchanged
    });

    test('writes launched key on first launch', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = FakeAuthService(userId: null, isAnonymous: true);

      await clearStaleKeychainIfFirstLaunch(authService: auth, prefs: prefs);

      expect(prefs.containsKey(firstLaunchHandledKey), isTrue);
    });

    test('signs out stale Keychain user on first launch (Google-linked)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = FakeAuthService(userId: 'stale-google-uid', isAnonymous: false);

      await clearStaleKeychainIfFirstLaunch(authService: auth, prefs: prefs);

      expect(auth.currentUserId, isNull);
      expect(auth.isAnonymous, isTrue);
      expect(prefs.containsKey(firstLaunchHandledKey), isTrue);
    });

    test('signs out stale Keychain anonymous user on first launch', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = FakeAuthService(userId: 'anon-uid', isAnonymous: true);

      await clearStaleKeychainIfFirstLaunch(authService: auth, prefs: prefs);

      expect(auth.currentUserId, isNull);
      expect(prefs.containsKey(firstLaunchHandledKey), isTrue);
    });

    test('does nothing when no Firebase user on first launch (normal fresh install)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = FakeAuthService(userId: null, isAnonymous: true);

      await clearStaleKeychainIfFirstLaunch(authService: auth, prefs: prefs);

      expect(auth.currentUserId, isNull); // Was already null
      expect(prefs.containsKey(firstLaunchHandledKey), isTrue);
    });

    test('subsequent launch after stale-auth clear: returning user is not signed out', () async {
      // Simulate: first launch already ran and wrote the key.
      SharedPreferences.setMockInitialValues({firstLaunchHandledKey: true});
      final prefs = await SharedPreferences.getInstance();
      // Now the user has a legitimate Google account from the current install.
      final auth = FakeAuthService(userId: 'real-google-uid', isAnonymous: false);

      await clearStaleKeychainIfFirstLaunch(authService: auth, prefs: prefs);

      expect(auth.currentUserId, equals('real-google-uid')); // Not signed out
    });
  });
}
