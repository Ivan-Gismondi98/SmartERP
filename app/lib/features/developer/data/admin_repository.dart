// ============================================================
//  SMARTERP · admin_repository.dart — gestione utenti e organizzazioni
//  (super_admin). Le operazioni sullo schema auth passano da RPC sicure.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/app_user.dart';

class AdminRepository {
  AdminRepository(this._client);
  final SupabaseClient _client;

  // ----- Utenti -----
  Future<List<AppUser>> listUsers() async {
    final rows = await _client.rpc('admin_list_users') as List;
    return rows
        .map((e) => AppUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<String> createUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? companyId,
  }) async {
    final id = await _client.rpc('admin_create_user', params: {
      'p_email': email,
      'p_password': password,
      'p_full_name': fullName,
      'p_role': role,
      'p_company_id': companyId,
    });
    return id as String;
  }

  Future<void> updateUser(
    String id, {
    String? fullName,
    String? role,
    String? companyId,
    bool? isActive,
    bool clearCompany = false,
  }) async {
    final data = <String, dynamic>{};
    if (fullName != null) data['full_name'] = fullName;
    if (role != null) data['role'] = role;
    if (isActive != null) data['is_active'] = isActive;
    if (clearCompany) {
      data['company_id'] = null;
    } else if (companyId != null) {
      data['company_id'] = companyId;
    }
    if (data.isEmpty) return;
    await _client.from('profiles').update(data).eq('id', id);
  }

  Future<void> deleteUser(String id) async {
    await _client.rpc('admin_delete_user', params: {'p_uid': id});
  }

  /// Token JWT firmato per impersonare [targetUid] (solo super_admin).
  Future<String> impersonationToken(String targetUid) async {
    final t = await _client.rpc('dev_impersonate', params: {'p_target': targetUid});
    return t as String;
  }

  // ----- Organizzazioni -----
  Future<List<Map<String, dynamic>>> listCompanies() async {
    final rows = await _client
        .from('companies')
        .select('id, name, vat_number, email, city, province, demo_mode')
        .order('name');
    return rows.cast<Map<String, dynamic>>();
  }

  /// Attiva/disattiva i dati di prova per un'organizzazione (solo super_admin).
  /// ON: seeda i dati di prova; OFF: li cancella definitivamente (inclusi
  /// quelli aggiunti durante il test).
  Future<void> setDemoMode(String companyId, bool on) async {
    await _client
        .rpc('set_demo_mode', params: {'p_company': companyId, 'p_on': on});
  }

  Future<void> createCompany(Map<String, dynamic> data) async {
    await _client.from('companies').insert(data);
  }

  Future<void> updateCompany(String id, Map<String, dynamic> data) async {
    await _client.from('companies').update(data).eq('id', id);
  }

  Future<void> deleteCompany(String id) async {
    await _client.from('companies').delete().eq('id', id);
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(supabaseClientProvider));
});

final usersListProvider = FutureProvider<List<AppUser>>((ref) async {
  return ref.watch(adminRepositoryProvider).listUsers();
});

final companiesAdminProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminRepositoryProvider).listCompanies();
});
