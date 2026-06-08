// ============================================================
//  SMARTERP · suppliers_repository.dart — CRUD fornitori.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../domain/supplier.dart';

class SuppliersRepository {
  SuppliersRepository(this._client);
  final SupabaseClient _client;

  Future<List<Supplier>> list(String companyId) async {
    final rows = await _client
        .from('suppliers')
        .select('id, company_id, name, vat_number, email, phone, address')
        .eq('company_id', companyId)
        .order('name');
    return rows.map(Supplier.fromJson).toList();
  }

  Future<void> create(String companyId, Supplier s) async {
    await _client.from('suppliers').insert({...s.toJson(), 'company_id': companyId});
  }

  Future<void> update(Supplier s) async {
    await _client.from('suppliers').update(s.toJson()).eq('id', s.id);
  }

  Future<void> delete(String id) async {
    await _client.from('suppliers').delete().eq('id', id);
  }
}

final suppliersRepositoryProvider = Provider<SuppliersRepository>((ref) {
  return SuppliersRepository(ref.watch(supabaseClientProvider));
});

final suppliersListProvider = FutureProvider<List<Supplier>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <Supplier>[];
  return ref.watch(suppliersRepositoryProvider).list(companyId);
});
