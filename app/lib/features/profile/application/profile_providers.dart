// ============================================================
//  SMARTERP · profile_providers.dart
//  Profilo dell'utente loggato, ricalcolato a ogni cambio di sessione.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/impersonation.dart';
import '../../auth/application/auth_providers.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

/// Profilo REALE dello sviluppatore loggato (ignora l'impersonate).
/// Usato per decidere CHI può impersonare.
final realProfileProvider = FutureProvider<Profile?>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return null;
  return ref.watch(profileRepositoryProvider).fetchCurrentProfile();
});

/// Profilo EFFETTIVO usato in tutta l'app: quello impersonato se attivo,
/// altrimenti il reale. Pilota ruolo/permessi/licenze/branding/azienda.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final imp = ref.watch(impersonationProvider).profile;
  if (imp != null) return imp;
  final session = ref.watch(currentSessionProvider);
  if (session == null) return null;
  return ref.watch(profileRepositoryProvider).fetchCurrentProfile();
});
