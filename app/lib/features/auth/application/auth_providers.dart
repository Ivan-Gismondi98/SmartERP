// ============================================================
//  SMARTERP · auth_providers.dart
//  Stato di autenticazione reattivo + controller per le azioni UI.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

/// Stream dello stato auth: emette a ogni login/logout/refresh.
/// Espone direttamente la Session corrente (null = non loggato).
final authStateChangesProvider = StreamProvider<Session?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.onAuthStateChange.map((event) => event.session);
});

/// Sessione corrente sincrona, derivata dallo stream (con fallback
/// alla sessione gia' presente al boot, prima del primo evento).
final currentSessionProvider = Provider<Session?>((ref) {
  final async = ref.watch(authStateChangesProvider);
  return async.valueOrNull ?? ref.watch(authRepositoryProvider).currentSession;
});

/// true se l'utente e' autenticato.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentSessionProvider) != null;
});

/// Controller delle azioni di autenticazione (login/registrazione/logout).
/// Lo stato AsyncValue<void> serve a UI per spinner/errori.
class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._repo) : super(const AsyncData(null));

  final AuthRepository _repo;

  Future<bool> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      await _repo.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String? fullName) async {
    state = const AsyncLoading();
    try {
      await _repo.signUp(
        email: email.trim(),
        password: password,
        fullName: fullName?.trim(),
      );
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await _repo.signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
