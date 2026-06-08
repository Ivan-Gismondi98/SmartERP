// ============================================================
//  SMARTERP · invoices_repository.dart
//  CRUD fatture + emissione (numerazione progressiva via RPC).
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/invoice.dart';

const _invoiceSelect =
    'id, company_id, customer_id, invoice_number, status, document_type, '
    'issue_date, due_date, subtotal, tax_amount, total, stamp_duty, rounding, '
    'payment_method, payment_terms, payment_terms_days, '
    'interest_enabled, interest_rate, notes, numbering_year, numbering_seq, '
    'reference_invoice_id, '
    'customers ( id, company_id, name, is_company, vat_number, tax_code, '
    'address, zip, city, province, country, sdi_code, pec, email, phone )';

class InvoicesRepository {
  InvoicesRepository(this._client);
  final SupabaseClient _client;

  Future<List<Invoice>> list(String companyId) async {
    final rows = await _client
        .from('invoices')
        .select(_invoiceSelect)
        .eq('company_id', companyId)
        .order('issue_date', ascending: false)
        .order('numbering_seq', ascending: false, nullsFirst: true);
    return rows.map(Invoice.fromJson).toList();
  }

  Future<Invoice> getById(String id) async {
    final row = await _client
        .from('invoices')
        .select('$_invoiceSelect, invoice_items ( id, position, description, '
            'quantity, unit_price, vat_rate, vat_nature, discount_percent, line_total )')
        .eq('id', id)
        .single();
    return Invoice.fromJson(row);
  }

  /// Crea una nuova bozza (header + righe).
  Future<String> createDraft(Invoice inv) async {
    final header =
        await _client.from('invoices').insert(inv.toJson()).select('id').single();
    final id = header['id'] as String;
    await _replaceItems(id, inv.items);
    return id;
  }

  /// Aggiorna una bozza esistente (header + righe).
  Future<void> updateDraft(Invoice inv) async {
    final id = inv.id!;
    await _client.from('invoices').update(inv.toJson()).eq('id', id);
    await _replaceItems(id, inv.items);
  }

  Future<void> _replaceItems(String invoiceId, List<InvoiceItem> items) async {
    await _client.from('invoice_items').delete().eq('invoice_id', invoiceId);
    if (items.isEmpty) return;
    final payload = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      payload.add({
        ...items[i].toJson(),
        'position': i,
        'invoice_id': invoiceId,
      });
    }
    await _client.from('invoice_items').insert(payload);
  }

  Future<void> delete(String id) async {
    await _client.from('invoices').delete().eq('id', id);
  }

  /// Emette la fattura: salva uno snapshot dei dati cliente e assegna il
  /// numero progressivo in modo atomico (RPC lato DB).
  Future<String> issue(Invoice inv) async {
    final id = inv.id!;
    final c = inv.customer;
    await _client.from('invoices').update({
      'bill_to_name': c?.name,
      'bill_to_vat': c?.vatNumber,
      'bill_to_tax_code': c?.taxCode,
      'bill_to_address': c?.fullAddress,
      'bill_to_sdi': c?.sdiCode,
      'bill_to_pec': c?.pec,
    }).eq('id', id);

    final number = await _client
        .rpc('assign_invoice_number', params: {'p_invoice_id': id});
    return number as String;
  }

  Future<void> setStatus(String id, InvoiceStatus status) async {
    await _client.from('invoices').update({'status': status.db}).eq('id', id);
  }

  /// Crea una nuova BOZZA copiando righe e intestazione da [source].
  /// Se [asCreditNote] e' true, e' una nota di credito (TD04) collegata.
  Future<String> duplicateFrom(Invoice source,
      {required bool asCreditNote}) async {
    final draft = Invoice(
      companyId: source.companyId,
      customerId: source.customerId,
      customer: source.customer,
      documentType: asCreditNote ? 'TD04' : 'TD01',
      referenceInvoiceId: asCreditNote ? source.id : null,
      stampDuty: source.stampDuty,
      paymentMethod: source.paymentMethod,
      paymentTerms: source.paymentTerms,
      notes: asCreditNote
          ? 'Nota di credito a storno della fattura ${source.displayNumber}'
          : source.notes,
      items: source.items.map((it) => it.copy()..position = it.position).toList(),
    );
    return createDraft(draft);
  }
}

final invoicesRepositoryProvider = Provider<InvoicesRepository>((ref) {
  return InvoicesRepository(ref.watch(supabaseClientProvider));
});
