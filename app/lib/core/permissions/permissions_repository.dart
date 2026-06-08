// ============================================================
//  SMARTERP · permissions_repository.dart
//  Legge/scrive i permessi per ruolo (tabelle permissions /
//  role_permissions). Risolve i default globali con override azienda.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/profile/domain/profile.dart';
import '../supabase_providers.dart';

/// Singola voce del catalogo permessi.
class PermissionDef {
  const PermissionDef(
      {required this.code,
      required this.module,
      required this.description,
      this.kind = 'generic',
      this.adminManageable = false});
  final String code;
  final String module;
  final String description;
  final String kind; // 'generic' | 'feature'
  final bool adminManageable; // delegabile/gestibile dall'admin

  bool get isFeature => kind == 'feature';

  factory PermissionDef.fromJson(Map<String, dynamic> j) => PermissionDef(
        code: j['code'] as String,
        module: j['module'] as String,
        description: j['description'] as String,
        kind: (j['kind'] as String?) ?? 'generic',
        adminManageable: (j['admin_manageable'] as bool?) ?? false,
      );
}

class PermissionsRepository {
  PermissionsRepository(this._client);
  final SupabaseClient _client;

  String _roleDb(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.admin:
        return 'admin';
      case UserRole.employee:
        return 'employee';
      case UserRole.customer:
        return 'customer';
    }
  }

  /// Codici permesso effettivi per (ruolo, azienda).
  /// super_admin ha tutto. Per gli altri: default globale (company_id null)
  /// con eventuale override per azienda (precede il default).
  Future<Set<String>> fetchAllowedCodes(UserRole role, String? companyId) async {
    if (role == UserRole.superAdmin) {
      final cat = await _client.from('permissions').select('code');
      return cat.map((e) => e['code'] as String).toSet();
    }

    final rows = await _client
        .from('role_permissions')
        .select('permission_code, allowed, company_id')
        .eq('role', _roleDb(role));

    // company override > default globale
    final effective = <String, bool>{};
    // prima i default globali
    for (final r in rows.where((r) => r['company_id'] == null)) {
      effective[r['permission_code'] as String] = r['allowed'] as bool;
    }
    // poi gli override dell'azienda corrente
    if (companyId != null) {
      for (final r in rows.where((r) => r['company_id'] == companyId)) {
        effective[r['permission_code'] as String] = r['allowed'] as bool;
      }
    }
    return effective.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toSet();
  }

  Future<List<PermissionDef>> fetchCatalog() async {
    final rows = await _client
        .from('permissions')
        .select('code, module, description, kind, admin_manageable')
        .order('module');
    return rows.map(PermissionDef.fromJson).toList();
  }

  /// Solo super_admin: marca un permesso come delegabile all'admin.
  Future<void> setAdminManageable(String code, bool value) async {
    await _client
        .from('permissions')
        .update({'admin_manageable': value}).eq('code', code);
  }

  /// Matrice effettiva (ruolo -> codice -> allowed) per la schermata
  /// Impostazioni, risolvendo i default con gli override dell'azienda.
  Future<Map<String, Map<String, bool>>> fetchRoleMatrix(String? companyId) async {
    final rows = await _client
        .from('role_permissions')
        .select('role, permission_code, allowed, company_id');

    final defaults = <String, Map<String, bool>>{};
    final overrides = <String, Map<String, bool>>{};
    for (final r in rows) {
      final role = r['role'] as String;
      final code = r['permission_code'] as String;
      final allowed = r['allowed'] as bool;
      if (r['company_id'] == null) {
        (defaults[role] ??= {})[code] = allowed;
      } else if (r['company_id'] == companyId) {
        (overrides[role] ??= {})[code] = allowed;
      }
    }
    final result = <String, Map<String, bool>>{};
    for (final role in {...defaults.keys, ...overrides.keys}) {
      result[role] = {...?defaults[role], ...?overrides[role]};
    }
    return result;
  }

  /// Imposta (override) un permesso per un ruolo nella propria azienda.
  /// Gli override hanno sempre company_id valorizzato (l'azienda corrente):
  /// facciamo update-or-insert manuale per non dipendere dall'inferenza
  /// ON CONFLICT sugli indici univoci parziali.
  Future<void> setRolePermission({
    required String companyId,
    required String role,
    required String code,
    required bool allowed,
  }) async {
    final updated = await _client
        .from('role_permissions')
        .update({'allowed': allowed})
        .eq('company_id', companyId)
        .eq('role', role)
        .eq('permission_code', code)
        .select('id');

    if (updated.isEmpty) {
      await _client.from('role_permissions').insert({
        'company_id': companyId,
        'role': role,
        'permission_code': code,
        'allowed': allowed,
      });
    }
  }
}

final permissionsRepositoryProvider = Provider<PermissionsRepository>((ref) {
  return PermissionsRepository(ref.watch(supabaseClientProvider));
});
