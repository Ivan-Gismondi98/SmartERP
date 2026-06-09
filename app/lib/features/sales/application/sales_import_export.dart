// ============================================================
//  SMARTERP · sales_import_export.dart — Import/Export VENDITE (preventivi/
//  ordini) a livello di RIGA. Righe con lo stesso "Documento" = un unico
//  documento. Import con risoluzione cliente (P.IVA/nome, creato se assente)
//  e prodotto (per SKU). Colonne import/export coincidenti.
// ============================================================
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/reporting/report_spec.dart';
import '../../customers/data/customers_repository.dart';
import '../../customers/domain/customer.dart';
import '../../products/data/products_repository.dart';
import '../../profile/application/profile_providers.dart';
import '../data/sales_repository.dart';
import '../domain/sales_document.dart';

class SalesLineRow {
  SalesLineRow({
    required this.docRef,
    required this.customer,
    required this.customerVat,
    required this.kind,
    required this.date,
    required this.valid,
    required this.sku,
    required this.description,
    required this.qty,
    required this.price,
    required this.vat,
    required this.discount,
  });

  final String docRef, customer, customerVat, kind, date, valid, sku,
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

final salesLinesSpec = ReportSpec<SalesLineRow>(
  title: 'Vendite (righe)',
  fileBase: 'vendite_righe',
  columns: [
    ReportColumn('Documento', (r) => r.docRef),
    ReportColumn('Cliente', (r) => r.customer),
    ReportColumn('P.IVA cliente', (r) => r.customerVat),
    ReportColumn('Tipo', (r) => r.kind),
    ReportColumn('Data', (r) => r.date),
    ReportColumn('Validità', (r) => r.valid),
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
    if (cid == null) return <SalesLineRow>[];
    final docs = await ref.read(salesRepositoryProvider).listDetailed(cid);
    final out = <SalesLineRow>[];
    for (final d in docs) {
      SalesLineRow line(String desc, String qty, String price, String vat,
              String disc) =>
          SalesLineRow(
            docRef: d.displayNumber,
            customer: d.customer?.name ?? '',
            customerVat: d.customer?.vatNumber ?? '',
            kind: d.kind.label,
            date: Fmt.date(d.issueDate),
            valid: Fmt.date(d.validUntil),
            sku: '',
            description: desc,
            qty: qty,
            price: price,
            vat: vat,
            discount: disc,
          );
      if (d.items.isEmpty) {
        out.add(line('', '', '', '', ''));
      } else {
        for (final it in d.items) {
          out.add(line(
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
    final salesRepo = ref.read(salesRepositoryProvider);
    final customersRepo = ref.read(customersRepositoryProvider);

    final customers = await customersRepo.list(cid);
    final byVat = <String, String>{};
    final byName = <String, String>{};
    for (final c in customers) {
      final d = _digits(c.vatNumber);
      if (d.isNotEmpty) byVat[d] = c.id;
      byName[c.name.trim().toLowerCase()] = c.id;
    }
    final products = await ref.read(productsRepositoryProvider).list(cid);
    final bySku = <String, String>{
      for (final p in products)
        if ((p.sku ?? '').trim().isNotEmpty) p.sku!.trim().toLowerCase(): p.id,
    };

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
      if (customerId == null) continue;
      final tipo = (first['Tipo'] ?? '').trim().toLowerCase();
      final kind = (tipo.contains('ordine') || tipo.contains('order'))
          ? SalesKind.order
          : SalesKind.quote;
      final items = <SalesItem>[];
      for (final m in lines) {
        final desc = (m['Descrizione'] ?? '').trim();
        if (desc.isEmpty) continue;
        final sku = (m['SKU'] ?? '').trim().toLowerCase();
        items.add(SalesItem(
          productId: sku.isEmpty ? null : bySku[sku],
          description: desc,
          quantity: Fmt.parseAmount(m['Quantità']) ?? 1,
          unitPrice: Fmt.parseAmount(m['Prezzo']) ?? 0,
          vatRate: Fmt.parseAmount(m['IVA']) ?? 22,
          discountPercent: Fmt.parseAmount(m['Sconto %']) ?? 0,
        ));
      }
      if (items.isEmpty) continue;
      await salesRepo.createDraft(SalesDocument(
        companyId: cid,
        customerId: customerId,
        kind: kind,
        issueDate: _parseDate(first['Data']) ?? DateTime.now(),
        validUntil: _parseDate(first['Validità']),
        items: items,
      ));
      count++;
    }
    return count;
  },
);
