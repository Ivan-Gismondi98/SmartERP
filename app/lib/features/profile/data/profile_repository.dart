// ============================================================
//  SMARTERP · profile_repository.dart
//  Legge il profilo dell'utente loggato (con l'azienda associata).
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  /// Profilo dell'utente attualmente autenticato, con join sull'azienda.
  /// Ritorna null se non c'e' sessione o il profilo non esiste ancora.
  Future<Profile?> fetchCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await _client
        .from('profiles')
        .select(
            'id, company_id, full_name, role, avatar_url, phone, is_active, '
            'companies ( id, name, vat_number, tax_code, regime_fiscale, '
            'address, zip, city, province, country, transmission_format, '
            'email, theme_settings )')
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});
