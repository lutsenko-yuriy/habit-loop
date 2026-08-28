import 'package:habit_loop/domain/user/user_profile.dart';
import 'package:habit_loop/domain/user/user_profile_sync_repository.dart';

/// No-op [UserProfileSyncRepository] used as the default provider value.
///
/// Always reports "nothing dirty" and silently ignores mark-synced/dirty
/// calls. Replaced in production by [SqliteUserProfileRepository] via
/// [AppContainer.overrides].
class NoopUserProfileSyncRepository implements UserProfileSyncRepository {
  const NoopUserProfileSyncRepository();

  @override
  Future<UserProfile?> getDirtyUserProfile() async => null;

  @override
  Future<void> markUserProfileSynced(DateTime syncedAt) async {}

  @override
  Future<DateTime?> getUserProfileSyncedAt() async => null;

  @override
  Future<void> markUserProfileDirty() async {}
}
