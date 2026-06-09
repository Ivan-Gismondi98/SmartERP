// ============================================================
//  SMARTERP · purchases_import_export.dart — Import/Export ACQUISTI
//  (offerte/ordini/contratti) a livello di RIGA. Righe con lo stesso
//  "Documento" = un unico documento. Import con risoluzione fornitore
//  (P.IVA/nome, creato se assente) e prodotto (per SKU).
// ============================================================
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/reporting/report_spec.dart';
import '../../products/data/products_repository.dart';
import '../../profile/application/profile_providers.dart';
import '../../suppliers/data/suppliers_repository.dart';
import '../../suppliers/domain/supplier.dart';
import '../data/purchases_repository.dart';
import '../domain/purchase_document.dart';

class PurchaseLineRow {
  PurchaseLineRow({
    required this.docRef,
    required this.supplier,
    required this.supplierVat,
    required this.kind,
    required this.date,
    required this.valid,
    required this.supplierRef,
    required this.sku,
    required this.description,
    required this.qty,
    required this.price,
    required this.vat,
    required this.discount,
  });

  final String docRef, supplier, supplierVat, kind, date, valid, supplierRef,
      sku, description, qty, price, vat, discount;
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

final purchasesLinesSpec = ReportSpec<PurchaseLineRow>(
  title: 'Acquisti (righe)',
  fileBase: 'acquisti_righe',
  columns: [
    ReportColumn('Documento', (r) => r.docRef),
    ReportColumn('Fornitore', (r) => r.supplier),
    ReportColumn('P.IVA fornitore', (r) => r.supplierVat),
    ReportColumn('Tipo', (r) => r.kind),
    ReportColumn('Data', (r) => r.date),
    ReportColumn('Validità', (r) => r.valid),
    ReportColumn('Rif. fornitore', (r) => r.supplierRef),
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
    if (cid == null) return <PurchaseLineRow>[];
    final docs = await ref.read(purchasesRepositoryProvider).listDetailed(cid);
    final out = <PurchaseLineRow>[];
    for (final d in docs) {
      PurchaseLineRow line(String desc, String qty, String price, String vat,
              String disc) =>
          PurchaseLineRow(
            docRef: d.displayNumber,
            supplier: d.supplier?.name ?? '',
            supplierVat: d.supplier?.vatNumber ?? '',
            kind: d.kind.label,
            date: Fmt.date(d.issueDate),
            valid: Fmt.date(d.validUntil),
            supplierRef: d.supplierRef ?? '',
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
    final purchasesRepo = ref.read(purchasesRepositoryProvider);
    final suppliersRepo = ref.read(suppliersRepositoryProvider);

    final suppliers = await suppliersRepo.list(cid);
    final byVat = <String, String>{};
    final byName = <String, String>{};
    for (final s in suppliers) {
      final d = _digits(s.vatNumber);
      if (d.isNotEmpty) byVat[d] = s.id;
      byName[s.name.trim().toLowerCase()] = s.id;
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

    Future<String?> resolveSupplier(Map<String, String> first) async {
      final vat = _digits(first['P.IVA fornitore']);
      final name = (first['Fornitore'] ?? '').trim();
      if (vat.isNotEmpty && byVat.containsKey(vat)) return byVat[vat];
      if (name.isNotEmpty && byName.containsKey(name.toLowerCase())) {
        return byName[name.toLowerCase()];
      }
      if (name.isEmpty) return null;
      // suppliersRepo.create non restituisce l'id: lo recuperiamo rileggendo.
      await suppliersRepo.create(
        cid,
        Supplier(
            id: '',
            companyId: cid,
            name: name,
            vatNumber: vat.isEmpty ? null : vat),
      );
      final refreshed = await suppliersRepo.list(cid);
      final created = refreshed.firstWhere(
        (s) => s.name.trim().toLowerCase() == name.toLowerCase(),
        orElse: () => refreshed.last,
      );
      if (vat.isNotEmpty) byVat[vat] = created.id;
      byName[name.toLowerCase()] = created.id;
      return created.id;
    }

    var count = 0;
    for (final entry in groups.entries) {
      final lines = entry.value;
      final first = lines.first;
      final supplierId = await resolveSupplier(first);
      if (supplierId == null) continue;
      final tipo = (first['Tipo'] ?? '').trim().toLowerCase();
      final kind = (tipo.contains('offert') || tipo.contains('offer'))
          ? PurchaseKind.offer
          : (tipo.contains('contratt') || tipo.contains('contract'))
              ? PurchaseKind.contract
              : PurchaseKind.order;
      final items = <PurchaseItem>[];
      for (final m in lines) {
        final desc = (m['Descrizione'] ?? '').trim();
        if (desc.isEmpty) continue;
        final sku = (m['SKU'] ?? '').trim().toLowerCase();
        items.add(PurchaseItem(
          productId: sku.isEmpty ? null : bySku[sku],
          description: desc,
          quantity: Fmt.parseAmount(m['Quantità']) ?? 1,
          unitPrice: Fmt.parseAmount(m['Prezzo']) ?? 0,
          vatRate: Fmt.parseAmount(m['IVA']) ?? 22,
          discountPercent: Fmt.parseAmount(m['Sconto %']) ?? 0,
        ));
      }
      if (items.isEmpty) continue;
      await purchasesRepo.createDraft(PurchaseDocument(
        companyId: cid,
        supplierId: supplierId,
        kind: kind,
        issueDate: _parseDate(first['Data']) ?? DateTime.now(),
        validUntil: _parseDate(first['Validità']),
        supplierRef: (first['Rif. fornitore'] ?? '').trim().isEmpty
            ? null
            : first['Rif. fornitore']!.trim(),
        items: items,
      ));
      count++;
    }
    return count;
  },
);
