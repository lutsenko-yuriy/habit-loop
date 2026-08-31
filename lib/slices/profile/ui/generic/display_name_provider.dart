import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/user/user_profile.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/profile/ui/generic/enter_name_constants.dart';

/// The user's raw resolved display name (HAB-232), `null` when none is on
/// file. Seeded synchronously before `runApp` via [DisplayNameNotifier]'s
/// constructor (see `AppContainer.overrides`, same pattern as
/// `localeOverrideProvider`) so the first frame is already correct, then kept
/// in sync with local writes ([DisplayNameNotifier.setDisplayName]) and with
/// [SyncService.pullCompleted] (a remote pull may merge in a newer name from
/// another device).
///
/// Prefer [personalizedNameProvider] at every UI/notification call site —
/// this provider ignores the feature-toggle and always exposes the raw value.
final displayNameProvider = NotifierProvider<DisplayNameNotifier, String?>(DisplayNameNotifier.new);

/// Derived from [displayNameProvider], gated by
/// `FeatureFlags.displayNamePersonalizationEnabled`. Returns `null` — never
/// an empty string — whenever the flag is off, so every consumer (onboarding,
/// dashboard greeting, notification copy, the change-name dialog) has
/// exactly one "no name" representation to check.
///
/// Also re-applies [capToMaxNameLength] here (HAB-232 WU6 audit finding) —
/// the UI entry points (`EnterNameScreen`, `openChangeNameDialog`) cap on
/// save, but a name arriving via [SyncService.pullCompleted] is written to
/// the repository (and this provider) uncapped, and this is the single
/// choke point every render call site already goes through.
final personalizedNameProvider = Provider<String?>((ref) {
  final enabled = ref.watch(featureFlagsProvider).displayNamePersonalizationEnabled;
  if (!enabled) return null;
  final name = ref.watch(displayNameProvider);
  return name == null ? null : capToMaxNameLength(name);
});

class DisplayNameNotifier extends Notifier<String?> {
  DisplayNameNotifier({String? seedDisplayName}) : _seed = seedDisplayName;

  final String? _seed;
  StreamSubscription<void>? _pullCompletedSubscription;

  // riverpod 2.6.1's NotifierProviderRef has no `mounted` getter (added in a
  // later major) — track disposal ourselves so a state write that lands
  // after an await can't touch a torn-down notifier.
  bool _disposed = false;

  @override
  String? build() {
    // Riverpod preserves this Notifier instance across a build() re-run
    // (ref.invalidate/refresh, hot reload) — the prior build's onDispose
    // fires first, so _disposed must be reset here or it latches true
    // forever and every future write silently stops reaching `state`.
    _disposed = false;
    try {
      // syncServiceProvider transitively requires the full repository graph
      // (pactRepositoryProvider et al.) to be wired — guarded the same way
      // the pre-runApp seed read is (see AppContainer.overrides) so a
      // caller that only cares about the raw/personalized name (e.g.
      // ReminderSchedulingService, now a personalizedNameProvider consumer
      // as of WU7) never needs the sync stack overridden just to construct
      // this notifier (HAB-232 WU7 fix — this cascaded through dozens of
      // pre-existing tests when the feature flag's default flipped to `true`).
      _pullCompletedSubscription = ref.read(syncServiceProvider).pullCompleted.listen((_) {
        unawaited(_refreshFromRepository());
      });
    } catch (e, s) {
      // No cross-device pull-refresh available — the locally seeded/written
      // name still works fine. Recorded non-fatal (not just swallowed) so a
      // genuine production failure of the sync stack is distinguishable from
      // a test that didn't override the repository graph (HAB-232 WU7 audit
      // finding) — CrashlyticsService has a no-throw contract, safe to call
      // unconditionally.
      unawaited(ref.read(crashlyticsServiceProvider).recordError(e, s, fatal: false));
    }
    ref.onDispose(() {
      _disposed = true;
      unawaited(_pullCompletedSubscription?.cancel());
    });
    unawaited(_publishUserProperty(_seed));
    return _seed;
  }

  /// Persists [name] via [UserProfileRepository] (which marks the row dirty
  /// for the next sync flush) and updates state immediately — `null`/empty
  /// clears the name, matching [UserProfile]'s own normalization.
  Future<void> setDisplayName(String? name) async {
    final profile = UserProfile(displayName: name, updatedAt: DateTime.now());
    await ref.read(userProfileRepositoryProvider).saveProfile(profile);
    unawaited(ref.read(syncServiceProvider).uploadUserProfile(profile));
    if (_disposed) return;
    state = profile.displayName;
    unawaited(_publishUserProperty(state));
  }

  // Triggered by SyncService.pullCompleted — re-reads the local repository
  // (already updated by the sync pull) rather than the Firestore document
  // directly, so this stays agnostic of the sync layer's merge rules.
  Future<void> _refreshFromRepository() async {
    final UserProfile? profile;
    try {
      profile = await ref.read(userProfileRepositoryProvider).getProfile();
    } catch (_) {
      // A refresh failure leaves the previously known name in place.
      return;
    }
    // The notifier (and its provider scope) may have been disposed while the
    // read above was in flight — never write state past that point.
    if (_disposed) return;
    state = profile?.displayName;
    unawaited(_publishUserProperty(state));
  }

  Future<void> _publishUserProperty(String? name) {
    return ref.read(analyticsServiceProvider).setUserProperty('has_display_name', name == null ? 'false' : 'true');
  }
}
