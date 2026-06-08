// ============================================================
//  SMARTERP · templates_repository.dart — CRUD modelli documento.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/document_template.dart';

const _select = 'id, company_id, name, doc_type, is_default, config';

class TemplatesRepository {
  TemplatesRepository(this._client);
  final SupabaseClient _client;

  Future<List<DocumentTemplate>> list(String companyId) async {
    final rows = await _client
        .from('document_templates')
        .select(_select)
        .eq('company_id', companyId)
        .order('name');
    return rows.map(DocumentTemplate.fromJson).toList();
  }

  Future<DocumentTemplate?> getById(String id) async {
    final row = await _client
        .from('document_templates')
        .select(_select)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : DocumentTemplate.fromJson(row);
  }

  Future<void> create(String companyId, DocumentTemplate t) async {
    await _client
        .from('document_templates')
        .insert({...t.toJson(), 'company_id': companyId});
  }

  Future<void> update(DocumentTemplate t) async {
    await _client.from('document_templates').update(t.toJson()).eq('id', t.id);
  }

  Future<void> delete(String id) async {
    await _client.from('document_templates').delete().eq('id', id);
  }
}

final templatesRepositoryProvider = Provider<TemplatesRepository>((ref) {
  return TemplatesRepository(ref.watch(supabaseClientProvider));
});
