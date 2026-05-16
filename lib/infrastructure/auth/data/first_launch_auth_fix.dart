import 'package:habit_loop/infrastructure/auth/contracts/auth_service.dart';
import 'package:habit_loop/infrastructure/device/data/shared_preferences_device_id_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clears stale Keychain credentials on first launch after a reinstall.
///
/// On iOS, Firebase Auth stores credentials in the Keychain, which survives
/// app uninstall and reinstall. A fresh install (identified by the absence of
/// [SharedPreferencesDeviceIdService.prefsKey], which is only written when the
/// user creates their first pact) should start with a clean auth state.
///
/// If a Firebase user is found but no device ID exists, this indicates a
/// reinstall on iOS where the Keychain retained the previous session. Signing
/// out here lets [AuthService.initialize] create a fresh anonymous user on the
/// next call, matching what the user expects from a clean install.
Future<void> clearStaleKeychainIfFirstLaunch({
  required AuthService authService,
  required SharedPreferences prefs,
}) async {
  if (authService.currentUserId == null) return;
  if (prefs.containsKey(SharedPreferencesDeviceIdService.prefsKey)) return;
  await authService.signOut();
}
