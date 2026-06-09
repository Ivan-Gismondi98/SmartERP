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
const kAppModules = <String>{
  'invoices', 'customers', 'products', 'chat', 'studio', 'assistant', 'crm',
  'accounting', 'documents', 'production', 'purchases', 'maintenance',
  'projects'
};

/// Etichette leggibili delle app (per i selettori/pacchetti).
const kAppLabels = <String, String>{
  'invoices': 'Fatture',
  'customers': 'Clienti',
  'products': 'Magazzino / Prodotti',
  'chat': 'Chat',
  'studio': 'Studio',
  'assistant': 'Assistente IA',
  'crm': 'CRM',
  'accounting': 'Contabilità',
  'documents': 'Documenti',
  'production': 'Produzione',
  'purchases': 'Acquisti',
  'maintenance': 'Manutenzione',
  'projects': 'Progetti',
  'suite': 'Suite completa',
};

String appLabel(String code) => kAppLabels[code] ?? code;

/// Stato di una licenza per un'app dell'organizzazione.
enum AppLicenseState {
  /// Licenza presente e in corso di validità.
  active,

  /// Licenza presente ma scaduta (status non attivo o rinnovo passato).
  expired,
}

/// Stato di licenza per ciascun codice app dell'organizzazione corrente.
/// super_admin: tutte attive. Una licenza valida prevale sulla scaduta per
/// la stessa app. Le app senza alcuna licenza non compaiono nella mappa.
final appLicenseStatesProvider =
    FutureProvider<Map<String, AppLicenseState>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return const {};
  if (profile.role == UserRole.superAdmin) {
    return {for (final a in kAppModules) a: AppLicenseState.active};
  }
  final companyId = profile.companyId;
  if (companyId == null) return const {};

  final rows = await ref
      .watch(supabaseClientProvider)
      .from('licenses')
      .select('app_code, app_codes, status, renewal_date')
      .eq('company_id', companyId);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final states = <String, AppLicenseState>{};

  void apply(String code, AppLicenseState st) {
    // 'active' prevale sempre su 'expired'.
    if (states[code] == AppLicenseState.active) return;
    states[code] = st;
  }

  for (final r in rows) {
    final status = (r['status'] as String?) ?? 'active';
    final renewalRaw = r['renewal_date'] as String?;
    final renewal = renewalRaw == null ? null : DateTime.tryParse(renewalRaw);
    final valid = status == 'active' &&
        (renewal == null || !renewal.isBefore(today));
    final st = valid ? AppLicenseState.active : AppLicenseState.expired;

    final list = (r['app_codes'] as List?)?.map((e) => e as String).toList() ??
        [if (r['app_code'] != null) r['app_code'] as String];
    final codes = <String>{};
    for (final c in list) {
      if (c == 'suite') {
        codes.addAll(kAppModules);
      } else {
        codes.add(c);
      }
    }
    for (final c in codes) {
      apply(c, st);
    }
  }
  return states;
});

/// Insieme dei codici app ATTIVI (licenza valida) per l'organizzazione.
/// super_admin: tutte. (Una licenza scaduta NON abilita l'app.)
final licensedAppsProvider = FutureProvider<Set<String>>((ref) async {
  final states = await ref.watch(appLicenseStatesProvider.future);
  return {
    for (final e in states.entries)
      if (e.value == AppLicenseState.active) e.key
  };
});
