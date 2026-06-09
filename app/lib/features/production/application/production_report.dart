// ============================================================
//  SMARTERP · production_report.dart — Report/Import-Export ordini di
//  produzione (prodotto risolto per nome).
// ============================================================
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/reporting/report_spec.dart';
import '../../products/data/products_repository.dart';
import '../../profile/application/profile_providers.dart';
import '../data/production_repository.dart';
import '../domain/production_order.dart';
import 'production_providers.dart';

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

ProductionStatus _status(String? v) {
  final s = (v ?? '').trim().toLowerCase();
  return ProductionStatus.values.firstWhere(
    (e) => e.db == s || e.label.toLowerCase() == s,
    orElse: () => ProductionStatus.draft,
  );
}

final productionReportSpec = ReportSpec<ProductionOrder>(
  title: 'Produzione',
  fileBase: 'ordini_produzione',
  columns: [
    ReportColumn('Numero', (o) => o.displayNumber),
    ReportColumn('Prodotto', (o) => o.productName ?? ''),
    ReportColumn('Quantità', (o) => Fmt.qty(o.quantity)),
    ReportColumn('Stato', (o) => o.status.label),
    ReportColumn('Data prevista', (o) => Fmt.date(o.plannedDate)),
  ],
  load: (ref) => ref.read(productionOrdersProvider.future),
  importRows: (ref, rows) async {
    final profile = await ref.read(currentProfileProvider.future);
    final cid = profile?.companyId;
    if (cid == null) throw 'Nessuna azienda associata';
    final repo = ref.read(productionRepositoryProvider);
    final products = await ref.read(productsRepositoryProvider).list(cid);
    final byName = {for (final p in products) p.name.trim().toLowerCase(): p.id};
    var n = 0;
    for (final m in rows) {
      final pname = (m['Prodotto'] ?? '').trim();
      final productId = byName[pname.toLowerCase()];
      if (productId == null) continue; // serve un prodotto esistente
      await repo.create(ProductionOrder(
        companyId: cid,
        productId: productId,
        productName: pname,
        quantity: Fmt.parseAmount(m['Quantità']) ?? 1,
        status: _status(m['Stato']),
        plannedDate: _parseDate(m['Data prevista']),
      ));
      n++;
    }
    return n;
  },
);
