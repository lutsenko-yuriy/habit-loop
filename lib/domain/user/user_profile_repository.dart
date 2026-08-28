import 'package:habit_loop/domain/user/user_profile.dart';

abstract class UserProfileRepository {
  /// Returns the single locally-stored profile, or `null` if none has been saved yet.
  Future<UserProfile?> getProfile();

  /// Upserts the single profile row. The single-row invariant (fixed id,
  /// `ConflictAlgorithm.replace`) is enforced by the implementation, not by
  /// convention.
  Future<void> saveProfile(UserProfile profile);
}
