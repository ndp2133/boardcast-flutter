/// Auth state provider
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

/// The auth service singleton.
final authServiceProvider = Provider<AuthService>((ref) {
  final service = AuthService(supabase);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream of the current user (null = guest).
final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(authServiceProvider);
  // Emit current state immediately, then stream changes
  return Stream.value(auth.currentUser).asyncExpand(
    (_) => auth.onAuthChange,
  );
});

/// Convenience: is the user a guest?
final isGuestProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull == null;
});
