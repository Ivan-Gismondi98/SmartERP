// ============================================================
//  SMARTERP · company_repository.dart
//  Aggiorna i dati/branding dell'azienda (companies.theme_settings).
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';

class CompanyRepository {
  CompanyRepository(this._client);
  final SupabaseClient _client;

  /// Sovrascrive l'intero blocco theme_settings (colori, logo, font).
  Future<void> updateThemeSettings(
      String companyId, Map<String, dynamic> themeSettings) async {
    await _client
        .from('companies')
        .update({'theme_settings': themeSettings})
        .eq('id', companyId);
  }
}

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepository(ref.watch(supabaseClientProvider));
});
