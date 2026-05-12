import 'package:habit_loop/infrastructure/auth/contracts/auth_service.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_state.dart';

final class NoopAuthService implements AuthService {
  @override
  Future<void> initialize() async {}

  @override
  String? get currentUserId => null;

  @override
  bool get isAnonymous => true;

  @override
  Stream<AuthState> get authStateChanges => Stream.value(const AuthState(userId: null, isAnonymous: true));

  @override
  Future<void> linkWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}
