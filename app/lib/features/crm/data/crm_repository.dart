// ============================================================
//  SMARTERP · crm_repository.dart — CRUD opportunità CRM.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/opportunity.dart';

const _select =
    'id, company_id, title, customer_id, contact_name, contact_email, '
    'contact_phone, contact_company, stage, expected_value, probability, '
    'expected_close, source, owner_id, notes, '
    'customers ( id, company_id, name, is_company, vat_number, tax_code, '
    'address, zip, city, province, country, sdi_code, pec, email, phone )';

class CrmRepository {
  CrmRepository(this._client);
  final SupabaseClient _client;

  Future<List<Opportunity>> list(String companyId) async {
    final rows = await _client
        .from('crm_opportunities')
        .select(_select)
        .eq('company_id', companyId)
        .order('expected_close', ascending: true, nullsFirst: false)
        .order('created_at', ascending: false);
    return rows.map(Opportunity.fromJson).toList();
  }

  Future<Opportunity> getById(String id) async {
    final row =
        await _client.from('crm_opportunities').select(_select).eq('id', id).single();
    return Opportunity.fromJson(row);
  }

  Future<String> create(Opportunity o) async {
    final row = await _client
        .from('crm_opportunities')
        .insert(o.toJson())
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> update(Opportunity o) async {
    await _client.from('crm_opportunities').update(o.toJson()).eq('id', o.id!);
  }

  Future<void> setStage(String id, CrmStage stage) async {
    await _client
        .from('crm_opportunities')
        .update({'stage': stage.db}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('crm_opportunities').delete().eq('id', id);
  }
}

final crmRepositoryProvider = Provider<CrmRepository>((ref) {
  return CrmRepository(ref.watch(dataClientProvider));
});
