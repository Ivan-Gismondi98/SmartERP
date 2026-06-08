// ============================================================
//  SMARTERP · settings_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/settings_repository.dart';

/// Feature toggle booleano per (scope, key) dell'azienda corrente.
final boolSettingProvider =
    FutureProvider.family<bool, ({String scope, String key})>((ref, arg) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return false;
  return ref
      .watch(settingsRepositoryProvider)
      .getBool(companyId, arg.scope, arg.key);
});

/// Scorciatoia: firma/invio SdI abilitato per le fatture.
final sdiEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.watch(
      boolSettingProvider((scope: 'invoices', key: 'sdi_enabled')).future);
});
