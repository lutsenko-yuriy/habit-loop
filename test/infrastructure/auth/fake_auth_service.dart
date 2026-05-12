import 'dart:async';

import 'package:habit_loop/infrastructure/auth/contracts/auth_service.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_state.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({String? userId, bool isAnonymous = true})
      : _userId = userId,
        _isAnonymous = isAnonymous;

  String? _userId;
  bool _isAnonymous;
  final _controller = StreamController<AuthState>.broadcast();

  @override
  Future<void> initialize() async {}

  @override
  String? get currentUserId => _userId;

  @override
  bool get isAnonymous => _isAnonymous;

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  void emitState({required String? userId, required bool isAnonymous}) {
    _userId = userId;
    _isAnonymous = isAnonymous;
    _controller.add(AuthState(userId: userId, isAnonymous: isAnonymous));
  }

  @override
  Future<void> linkWithGoogle() async {
    _isAnonymous = false;
    _controller.add(AuthState(userId: _userId, isAnonymous: false));
  }

  @override
  Future<void> signOut() async {
    _userId = null;
    _isAnonymous = true;
    _controller.add(const AuthState(userId: null, isAnonymous: true));
  }

  void dispose() => _controller.close();
}
