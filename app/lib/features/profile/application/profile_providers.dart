// ============================================================
//  SMARTERP · profile_providers.dart
//  Profilo dell'utente loggato, ricalcolato a ogni cambio di sessione.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

/// Profilo corrente (con azienda). Dipende dalla sessione: al logout
/// torna null, al login viene rifatta la fetch.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return null;
  return ref.watch(profileRepositoryProvider).fetchCurrentProfile();
});
