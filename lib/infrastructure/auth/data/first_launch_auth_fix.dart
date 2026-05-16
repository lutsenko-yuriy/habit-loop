import 'package:habit_loop/infrastructure/auth/contracts/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key written on the first successful app launch.
///
/// Presence of this key means the app has run at least once on this install,
/// so any Firebase Auth user found in the Keychain is legitimately from the
/// current install (not a stale remnant from a previous install).
const firstLaunchHandledKey = 'habit_loop_launched';

/// Clears stale Keychain credentials on first launch after a reinstall.
///
/// On iOS, Firebase Auth stores credentials in the Keychain, which survives
/// app uninstall and reinstall. A fresh install is detected by the absence of
/// [firstLaunchHandledKey] in SharedPreferences, which is written on the very
/// first launch and persisted for all subsequent launches.
///
/// Sequence:
/// 1. If the launched key is already present → returning user, return immediately.
/// 2. Write the launched key so subsequent startups skip this block.
/// 3. If a Firebase user exists → must be a stale Keychain entry → sign out.
///    [AuthService.initialize] then creates a fresh anonymous user.
Future<void> clearStaleKeychainIfFirstLaunch({
  required AuthService authService,
  required SharedPreferences prefs,
}) async {
  if (prefs.containsKey(firstLaunchHandledKey)) return;
  // Mark as launched immediately — even if signOut() fails, subsequent startups
  // skip this block rather than repeatedly clearing a legitimate returning user.
  await prefs.setBool(firstLaunchHandledKey, true);
  if (authService.currentUserId != null) {
    await authService.signOut();
  }
}
