// ============================================================
//  SMARTERP · sales_repository.dart
//  CRUD documenti di vendita (preventivi/ordini) + conferma (numerazione
//  progressiva via RPC) + conversione in fattura.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/sales_document.dart';

const _docSelect =
    'id, company_id, customer_id, doc_kind, doc_number, status, issue_date, '
    'valid_until, subtotal, tax_amount, total, stamp_duty, rounding, '
    'payment_method, payment_terms, payment_terms_days, notes, '
    'numbering_year, numbering_seq, converted_invoice_id, template_id, '
    'customers ( id, company_id, name, is_company, vat_number, tax_code, '
    'address, zip, city, province, country, sdi_code, pec, email, phone )';

class SalesRepository {
  SalesRepository(this._client);
  final SupabaseClient _client;

  Future<List<SalesDocument>> list(String companyId) async {
    final rows = await _client
        .from('sales_documents')
        .select(_docSelect)
        .eq('company_id', companyId)
        .order('issue_date', ascending: false)
        .order('numbering_seq', ascending: false, nullsFirst: true);
    return rows.map(SalesDocument.fromJson).toList();
  }

  /// Elenco documenti CON righe (per export/import riga-livello).
  Future<List<SalesDocument>> listDetailed(String companyId) async {
    final rows = await _client
        .from('sales_documents')
        .select('$_docSelect, sales_document_items ( id, position, product_id, '
            'description, quantity, unit_price, vat_rate, vat_nature, '
            'discount_percent, line_total )')
        .eq('company_id', companyId)
        .order('issue_date', ascending: false)
        .order('numbering_seq', ascending: false, nullsFirst: true);
    return rows.map(SalesDocument.fromJson).toList();
  }

  Future<SalesDocument> getById(String id) async {
    final row = await _client
        .from('sales_documents')
        .select('$_docSelect, sales_document_items ( id, position, product_id, '
            'description, quantity, unit_price, vat_rate, vat_nature, '
            'discount_percent, line_total )')
        .eq('id', id)
        .single();
    return SalesDocument.fromJson(row);
  }

  Future<String> createDraft(SalesDocument doc) async {
    final header = await _client
        .from('sales_documents')
        .insert(doc.toJson())
        .select('id')
        .single();
    final id = header['id'] as String;
    await _replaceItems(id, doc.items);
    return id;
  }

  Future<void> updateDraft(SalesDocument doc) async {
    final id = doc.id!;
    await _client.from('sales_documents').update(doc.toJson()).eq('id', id);
    await _replaceItems(id, doc.items);
  }

  Future<void> _replaceItems(String documentId, List<SalesItem> items) async {
    await _client
        .from('sales_document_items')
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
    await _client.from('sales_document_items').insert(payload);
  }

  Future<void> delete(String id) async {
    await _client.from('sales_documents').delete().eq('id', id);
  }

  /// Conferma il documento: assegna il numero progressivo (per tipo+anno) e
  /// porta lo stato a "inviato".
  Future<String> confirm(SalesDocument doc) async {
    final number = await _client
        .rpc('assign_sales_number', params: {'p_document_id': doc.id});
    return number as String;
  }

  Future<void> setStatus(String id, SalesStatus status) async {
    await _client
        .from('sales_documents')
        .update({'status': status.db}).eq('id', id);
  }

  /// Registra l'avvenuta conversione in fattura: collega l'id fattura e
  /// segna il documento come "convertito".
  Future<void> markConverted(String id, String invoiceId) async {
    await _client.from('sales_documents').update({
      'converted_invoice_id': invoiceId,
      'status': SalesStatus.converted.db,
    }).eq('id', id);
  }

  /// Duplica un documento come nuova BOZZA (stesso tipo, righe copiate).
  Future<String> duplicateFrom(SalesDocument source) async {
    final draft = SalesDocument(
      companyId: source.companyId,
      customerId: source.customerId,
      customer: source.customer,
      kind: source.kind,
      stampDuty: source.stampDuty,
      paymentMethod: source.paymentMethod,
      paymentTerms: source.paymentTerms,
      paymentTermsDays: source.paymentTermsDays,
      notes: source.notes,
      items: source.items.map((it) => it.copy()).toList(),
    );
    return createDraft(draft);
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.watch(dataClientProvider));
});
