/// Auth service — wraps Supabase auth
/// Direct port of js/auth.js
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client;
  final _controller = StreamController<User?>.broadcast();

  User? _currentUser;
  StreamSubscription<AuthState>? _authSub;

  AuthService(this._client);

  /// Initialize auth — restore session, set up listener.
  Future<void> init() async {
    try {
      final session = _client.auth.currentSession;
      _currentUser = session?.user;
    } catch (e) {
      _currentUser = null;
    }

    _authSub = _client.auth.onAuthStateChange.listen((data) {
      _currentUser = data.session?.user;
      _controller.add(_currentUser);
    });
  }

  User? get currentUser => _currentUser;
  bool get isGuest => _currentUser == null;
  String? get userId => _currentUser?.id;

  /// Stream of auth state changes.
  Stream<User?> get onAuthChange => _controller.stream;

  Future<({User? user, String? error})> signUp(
      String email, String password) async {
    try {
      final res =
          await _client.auth.signUp(email: email, password: password);
      if (res.user != null) _currentUser = res.user;
      return (user: res.user, error: null);
    } on AuthException catch (e) {
      return (user: null, error: e.message);
    }
  }

  Future<({User? user, String? error})> signIn(
      String email, String password) async {
    try {
      final res = await _client.auth
          .signInWithPassword(email: email, password: password);
      if (res.user != null) _currentUser = res.user;
      return (user: res.user, error: null);
    } on AuthException catch (e) {
      return (user: null, error: e.message);
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.boardcast.boardcastflutter://callback',
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> signOut() async {
    try {
      await _client.auth.signOut();
      _currentUser = null;
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  void dispose() {
    _authSub?.cancel();
    _controller.close();
  }
}
