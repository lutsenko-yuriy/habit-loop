import 'package:habit_loop/domain/user/user_profile.dart';
import 'package:habit_loop/domain/user/user_profile_repository.dart';

/// Fast in-memory fake used by unit tests and as the inert default provider
/// value that doesn't need SQLite fidelity.
class InMemoryUserProfileRepository implements UserProfileRepository {
  UserProfile? _profile;

  @override
  Future<UserProfile?> getProfile() async => _profile;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
  }
}
