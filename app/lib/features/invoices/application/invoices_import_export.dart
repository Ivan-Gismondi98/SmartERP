// ============================================================
//  SMARTERP · invoices_import_export.dart — Import/Export FATTURE a livello
//  di RIGA (una riga file = una riga fattura; righe con lo stesso "Documento"
//  formano un'unica fattura). Import con risoluzione dei collegamenti:
//   - Cliente per P.IVA o nome (creato se assente);
//   - Prodotto per SKU (riga collegata al magazzino, se trovato).
//  Le colonne di import ed export coincidono.
// ============================================================
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/reporting/report_spec.dart';
import '../../customers/data/customers_repository.dart';
import '../../customers/domain/customer.dart';
import '../../products/data/products_repository.dart';
import '../../profile/application/profile_providers.dart';
import '../data/invoices_repository.dart';
import '../domain/invoice.dart';

/// Riga "piatta" di una fattura (testata replicata + dati riga).
class InvoiceLineRow {
  InvoiceLineRow({
    required this.docRef,
    required this.customer,
    required this.customerVat,
    required this.docType,
    required this.date,
    required this.due,
    required this.sku,
    required this.description,
    required this.qty,
    required this.price,
    required this.vat,
    required this.discount,
  });

  final String docRef, customer, customerVat, docType, date, due, sku,
      description, qty, price, vat, discount;
}

final _df = DateFormat('dd/MM/yyyy');

DateTime? _parseDate(String? s) {
  final v = (s ?? '').trim();
  if (v.isEmpty) return null;
  try {
    return _df.parseStrict(v);
  } catch (_) {
    return DateTime.tryParse(v);
  }
}

String _digits(String? vat) {
  final v = (vat ?? '').trim().toUpperCase();
  final d = v.startsWith('IT') ? v.substring(2) : v;
  return d.replaceAll(RegExp(r'\s'), '');
}

final invoicesLinesSpec = ReportSpec<InvoiceLineRow>(
  title: 'Fatture (righe)',
  fileBase: 'fatture_righe',
  columns: [
    ReportColumn('Documento', (r) => r.docRef),
    ReportColumn('Cliente', (r) => r.customer),
    ReportColumn('P.IVA cliente', (r) => r.customerVat),
    ReportColumn('Tipo', (r) => r.docType),
    ReportColumn('Data', (r) => r.date),
    ReportColumn('Scadenza', (r) => r.due),
    ReportColumn('SKU', (r) => r.sku),
    ReportColumn('Descrizione', (r) => r.description),
    ReportColumn('Quantità', (r) => r.qty),
    ReportColumn('Prezzo', (r) => r.price),
    ReportColumn('IVA', (r) => r.vat),
    ReportColumn('Sconto %', (r) => r.discount),
  ],
  load: (ref) async {
    final profile = await ref.read(currentProfileProvider.future);
    final cid = profile?.companyId;
    if (cid == null) return <InvoiceLineRow>[];
    final invoices =
        await ref.read(invoicesRepositoryProvider).listDetailed(cid);
    final out = <InvoiceLineRow>[];
    for (final inv in invoices) {
      InvoiceLineRow line(String sku, String desc, String qty, String price,
              String vat, String disc) =>
          InvoiceLineRow(
            docRef: inv.displayNumber,
            customer: inv.customer?.name ?? '',
            customerVat: inv.customer?.vatNumber ?? '',
            docType: inv.documentType,
            date: Fmt.date(inv.issueDate),
            due: Fmt.date(inv.dueDate),
            sku: sku,
            description: desc,
            qty: qty,
            price: price,
            vat: vat,
            discount: disc,
          );
      if (inv.items.isEmpty) {
        out.add(line('', '', '', '', '', ''));
      } else {
        for (final it in inv.items) {
          out.add(line(
            '',
            it.description,
            Fmt.qty(it.quantity),
            Fmt.amount(it.unitPrice),
            it.vatRate.toStringAsFixed(0),
            it.discountPercent == 0 ? '' : Fmt.qty(it.discountPercent),
          ));
        }
      }
    }
    return out;
  },
  importRows: (ref, rows) async {
    final profile = await ref.read(currentProfileProvider.future);
    final cid = profile?.companyId;
    if (cid == null) throw 'Nessuna azienda associata';
    final invoicesRepo = ref.read(invoicesRepositoryProvider);
    final customersRepo = ref.read(customersRepositoryProvider);
    final productsRepo = ref.read(productsRepositoryProvider);

    // Lookup clienti (per P.IVA e nome) e prodotti (per SKU).
    final customers = await customersRepo.list(cid);
    final byVat = <String, String>{};
    final byName = <String, String>{};
    for (final c in customers) {
      final d = _digits(c.vatNumber);
      if (d.isNotEmpty) byVat[d] = c.id;
      byName[c.name.trim().toLowerCase()] = c.id;
    }
    final products = await productsRepo.list(cid);
    final bySku = <String, String>{
      for (final p in products)
        if ((p.sku ?? '').trim().isNotEmpty) p.sku!.trim().toLowerCase(): p.id,
    };

    // Raggruppa per "Documento" (vuoto => ogni riga è una fattura a sé).
    final groups = <String, List<Map<String, String>>>{};
    var synthetic = 0;
    for (final m in rows) {
      final key = (m['Documento'] ?? '').trim();
      final gk = key.isEmpty ? '__row${synthetic++}' : key;
      (groups[gk] ??= []).add(m);
    }

    Future<String?> resolveCustomer(Map<String, String> first) async {
      final vat = _digits(first['P.IVA cliente']);
      final name = (first['Cliente'] ?? '').trim();
      if (vat.isNotEmpty && byVat.containsKey(vat)) return byVat[vat];
      if (name.isNotEmpty && byName.containsKey(name.toLowerCase())) {
        return byName[name.toLowerCase()];
      }
      if (name.isEmpty) return null;
      // Crea il cliente mancante.
      final created = await customersRepo.create(
        cid,
        Customer(
          id: '',
          companyId: cid,
          name: name,
          vatNumber: vat.isEmpty ? null : vat,
        ),
      );
      if (vat.isNotEmpty) byVat[vat] = created.id;
      byName[name.toLowerCase()] = created.id;
      return created.id;
    }

    var count = 0;
    for (final entry in groups.entries) {
      final lines = entry.value;
      final first = lines.first;
      final customerId = await resolveCustomer(first);
      if (customerId == null) continue; // senza cliente non si crea
      final tipo = (first['Tipo'] ?? '').trim().toUpperCase();
      final docType =
          (tipo.contains('TD04') || tipo.contains('CREDITO')) ? 'TD04' : 'TD01';
      final items = <InvoiceItem>[];
      for (final m in lines) {
        final desc = (m['Descrizione'] ?? '').trim();
        if (desc.isEmpty) continue;
        final sku = (m['SKU'] ?? '').trim().toLowerCase();
        items.add(InvoiceItem(
          productId: sku.isEmpty ? null : bySku[sku],
          description: desc,
          quantity: Fmt.parseAmount(m['Quantità']) ?? 1,
          unitPrice: Fmt.parseAmount(m['Prezzo']) ?? 0,
          vatRate: Fmt.parseAmount(m['IVA']) ?? 22,
          discountPercent: Fmt.parseAmount(m['Sconto %']) ?? 0,
        ));
      }
      if (items.isEmpty) continue;
      await invoicesRepo.createDraft(Invoice(
        companyId: cid,
        customerId: customerId,
        documentType: docType,
        issueDate: _parseDate(first['Data']) ?? DateTime.now(),
        dueDate: _parseDate(first['Scadenza']),
        items: items,
      ));
      count++;
    }
    return count;
  },
);
