import 'package:habit_loop/domain/user/user_profile.dart';

/// Sync-layer persistence for the single [UserProfile] record.
/// Only the sync service calls these — view models and application services use [UserProfileRepository].
abstract class UserProfileSyncRepository {
  /// Returns the profile if it has unsynced local changes, or `null` if
  /// already synced or never saved.
  Future<UserProfile?> getDirtyUserProfile();

  /// Marks the profile as successfully synced: sets `dirty=0` and
  /// `synced_at` to [syncedAt] in the local database.
  Future<void> markUserProfileSynced(DateTime syncedAt);

  /// Returns the `synced_at` timestamp for the profile, or `null` if dirty,
  /// never synced, or never saved.
  Future<DateTime?> getUserProfileSyncedAt();

  /// Marks the profile dirty (`dirty=1, synced_at=NULL`).
  /// Called after a Firebase UID change so it is re-uploaded under the new UID.
  Future<void> markUserProfileDirty();
}
