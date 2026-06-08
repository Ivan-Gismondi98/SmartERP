// ============================================================
//  SMARTERP · settings_repository.dart
//  Impostazioni chiave/valore per azienda (tabella app_settings),
//  con scope 'general' o per-applicativo ('invoices', 'products', ...).
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';

class SettingsRepository {
  SettingsRepository(this._client);
  final SupabaseClient _client;

  /// Tutte le impostazioni di uno scope come mappa key->value.
  Future<Map<String, dynamic>> getScope(String companyId, String scope) async {
    final rows = await _client
        .from('app_settings')
        .select('key, value')
        .eq('company_id', companyId)
        .eq('scope', scope);
    return {for (final r in rows) r['key'] as String: r['value']};
  }

  Future<bool> getBool(String companyId, String scope, String key,
      {bool fallback = false}) async {
    final rows = await _client
        .from('app_settings')
        .select('value')
        .eq('company_id', companyId)
        .eq('scope', scope)
        .eq('key', key)
        .maybeSingle();
    final v = rows?['value'];
    return v is bool ? v : fallback;
  }

  Future<void> setValue(
      String companyId, String scope, String key, Object? value) async {
    await _client.from('app_settings').upsert(
      {
        'company_id': companyId,
        'scope': scope,
        'key': key,
        'value': value,
      },
      onConflict: 'company_id,scope,key',
    );
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(supabaseClientProvider));
});
