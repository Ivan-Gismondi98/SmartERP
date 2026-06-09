// ============================================================
//  SMARTERP · products_report.dart — descrittore Report/Import-Export
//  Prodotti/Magazzino.
// ============================================================
import '../../../core/format.dart';
import '../../../core/reporting/report_spec.dart';
import '../../profile/application/profile_providers.dart';
import '../data/products_repository.dart';
import '../domain/product.dart';

String _s(String? v) => v ?? '';
String? _n(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

final productsReportSpec = ReportSpec<Product>(
  title: 'Magazzino / Prodotti',
  fileBase: 'prodotti',
  columns: [
    ReportColumn('Nome', (p) => p.name),
    ReportColumn('SKU', (p) => _s(p.sku)),
    ReportColumn('Descrizione', (p) => _s(p.description)),
    ReportColumn('Prezzo', (p) => Fmt.amount(p.unitPrice)),
    ReportColumn('IVA', (p) => p.vatRate.toStringAsFixed(0)),
    ReportColumn('Unità', (p) => p.unit),
    ReportColumn('Giacenza', (p) => p.quantity.toString()),
    ReportColumn('Scorta minima', (p) => p.reorderLevel.toString()),
    ReportColumn('Ubicazione', (p) => _s(p.warehouseLocation)),
    ReportColumn('Componibile', (p) => p.isComposable ? 'Sì' : 'No'),
  ],
  load: (ref) async {
    final profile = await ref.read(currentProfileProvider.future);
    final cid = profile?.companyId;
    if (cid == null) return <Product>[];
    return ref.read(productsRepositoryProvider).list(cid);
  },
  importRows: (ref, rows) async {
    final profile = await ref.read(currentProfileProvider.future);
    final cid = profile?.companyId;
    if (cid == null) throw 'Nessuna azienda associata';
    final repo = ref.read(productsRepositoryProvider);
    var n = 0;
    for (final m in rows) {
      final name = (m['Nome'] ?? '').trim();
      if (name.isEmpty) continue;
      final comp = (m['Componibile'] ?? '').trim().toLowerCase();
      await repo.create(
        cid,
        Product(
          id: '',
          companyId: cid,
          name: name,
          sku: _n(m['SKU']),
          description: _n(m['Descrizione']),
          unitPrice: Fmt.parseAmount(m['Prezzo']) ?? 0,
          vatRate: Fmt.parseAmount(m['IVA']) ?? 22,
          unit: (m['Unità'] ?? '').trim().isEmpty ? 'pz' : m['Unità']!.trim(),
          isComposable: comp == 'sì' || comp == 'si' || comp == 'true',
          quantity: (Fmt.parseAmount(m['Giacenza']) ?? 0).round(),
          reorderLevel: (Fmt.parseAmount(m['Scorta minima']) ?? 0).round(),
          warehouseLocation: _n(m['Ubicazione']),
        ),
      );
      n++;
    }
    return n;
  },
);
