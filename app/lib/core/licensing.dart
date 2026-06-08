// ============================================================
//  SMARTERP · licensing.dart
//  Un'app è disponibile a un'organizzazione solo se ha una licenza
//  ATTIVA per quell'app (impostata dal super_admin). 'suite' = tutte.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/profile/application/profile_providers.dart';
import '../features/profile/domain/profile.dart';
import 'supabase_providers.dart';

/// App soggette a licenza (codici = nomi modulo).
const kAppModules = <String>{'invoices', 'customers', 'products', 'chat', 'studio'};

/// Insieme dei codici app abilitati per l'organizzazione corrente.
/// super_admin: tutte. Altri: dalle licenze attive (suite => tutte).
final licensedAppsProvider = FutureProvider<Set<String>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return <String>{};
  if (profile.role == UserRole.superAdmin) return {...kAppModules};
  final companyId = profile.companyId;
  if (companyId == null) return <String>{};

  final rows = await ref
      .watch(supabaseClientProvider)
      .from('licenses')
      .select('app_code')
      .eq('company_id', companyId)
      .eq('status', 'active');

  final codes = <String>{};
  for (final r in rows) {
    final c = r['app_code'] as String?;
    if (c == 'suite') return {...kAppModules};
    if (c != null) codes.add(c);
  }
  return codes;
});
