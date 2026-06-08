// ============================================================
//  SMARTERP · permissions_providers.dart
//  Espone i permessi effettivi dell'utente loggato e l'helper can().
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/application/profile_providers.dart';
import 'permissions_repository.dart';

/// Insieme dei codici permesso concessi all'utente corrente.
/// Si ricalcola quando cambia il profilo (login/logout/cambio ruolo).
final allowedPermissionsProvider = FutureProvider<Set<String>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return <String>{};
  return ref
      .watch(permissionsRepositoryProvider)
      .fetchAllowedCodes(profile.role, profile.companyId);
});

/// Verifica sincrona di un permesso (false finche' non sono caricati).
final canProvider = Provider.family<bool, String>((ref, code) {
  final perms = ref.watch(allowedPermissionsProvider).valueOrNull;
  return perms?.contains(code) ?? false;
});
