// ============================================================
//  SMARTERP · purchases_repository.dart — CRUD documenti di acquisto
//  + conferma (numerazione progressiva per tipo+anno).
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/purchase_document.dart';

const _docSelect =
    'id, company_id, supplier_id, doc_kind, doc_number, status, issue_date, '
    'valid_until, supplier_ref, subtotal, tax_amount, total, rounding, '
    'payment_terms, notes, numbering_year, numbering_seq, '
    'suppliers ( id, company_id, name, vat_number, email, phone, address )';

class PurchasesRepository {
  PurchasesRepository(this._client);
  final SupabaseClient _client;

  Future<List<PurchaseDocument>> list(String companyId) async {
    final rows = await _client
        .from('purchase_documents')
        .select(_docSelect)
        .eq('company_id', companyId)
        .order('issue_date', ascending: false)
        .order('numbering_seq', ascending: false, nullsFirst: true);
    return rows.map(PurchaseDocument.fromJson).toList();
  }

  Future<PurchaseDocument> getById(String id) async {
    final row = await _client
        .from('purchase_documents')
        .select('$_docSelect, purchase_document_items ( id, position, product_id, '
            'description, quantity, unit_price, vat_rate, vat_nature, '
            'discount_percent, line_total )')
        .eq('id', id)
        .single();
    return PurchaseDocument.fromJson(row);
  }

  Future<String> createDraft(PurchaseDocument doc) async {
    final header = await _client
        .from('purchase_documents')
        .insert(doc.toJson())
        .select('id')
        .single();
    final id = header['id'] as String;
    await _replaceItems(id, doc.items);
    return id;
  }

  Future<void> updateDraft(PurchaseDocument doc) async {
    final id = doc.id!;
    await _client.from('purchase_documents').update(doc.toJson()).eq('id', id);
    await _replaceItems(id, doc.items);
  }

  Future<void> _replaceItems(
      String documentId, List<PurchaseItem> items) async {
    await _client
        .from('purchase_document_items')
        .delete()
        .eq('document_id', documentId);
    if (items.isEmpty) return;
    final payload = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      payload.add({
        ...items[i].toJson(),
        'position': i,
        'document_id': documentId,
      });
    }
    await _client.from('purchase_document_items').insert(payload);
  }

  Future<void> delete(String id) async {
    await _client.from('purchase_documents').delete().eq('id', id);
  }

  Future<String> confirm(PurchaseDocument doc) async {
    final n = await _client
        .rpc('assign_purchase_number', params: {'p_document_id': doc.id});
    return n as String;
  }

  Future<void> setStatus(String id, PurchaseStatus status) async {
    await _client
        .from('purchase_documents')
        .update({'status': status.db}).eq('id', id);
  }

  Future<String> duplicateFrom(PurchaseDocument source) async {
    final draft = PurchaseDocument(
      companyId: source.companyId,
      supplierId: source.supplierId,
      supplier: source.supplier,
      kind: source.kind,
      paymentTerms: source.paymentTerms,
      notes: source.notes,
      items: source.items.map((it) => it.copy()).toList(),
    );
    return createDraft(draft);
  }
}

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return PurchasesRepository(ref.watch(dataClientProvider));
});
