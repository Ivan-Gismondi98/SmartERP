// ============================================================
//  SMARTERP · suppliers_report.dart — descrittore Report/Import-Export Fornitori.
// ============================================================
import '../../../core/reporting/report_spec.dart';
import '../../profile/application/profile_providers.dart';
import '../data/suppliers_repository.dart';
import '../domain/supplier.dart';

String _s(String? v) => v ?? '';
String? _n(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

final suppliersReportSpec = ReportSpec<Supplier>(
  title: 'Fornitori',
  fileBase: 'fornitori',
  columns: [
    ReportColumn('Nome', (s) => s.name),
    ReportColumn('P.IVA', (s) => _s(s.vatNumber)),
    ReportColumn('Email', (s) => _s(s.email)),
    ReportColumn('Telefono', (s) => _s(s.phone)),
    ReportColumn('Indirizzo', (s) => _s(s.address)),
  ],
  load: (ref) async {
    final profile = await ref.read(currentProfileProvider.future);
    final cid = profile?.companyId;
    if (cid == null) return <Supplier>[];
    return ref.read(suppliersRepositoryProvider).list(cid);
  },
  importRows: (ref, rows) async {
    final profile = await ref.read(currentProfileProvider.future);
    final cid = profile?.companyId;
    if (cid == null) throw 'Nessuna azienda associata';
    final repo = ref.read(suppliersRepositoryProvider);
    var n = 0;
    for (final m in rows) {
      final name = (m['Nome'] ?? '').trim();
      if (name.isEmpty) continue;
      await repo.create(
        cid,
        Supplier(
          id: '',
          companyId: cid,
          name: name,
          vatNumber: _n(m['P.IVA']),
          email: _n(m['Email']),
          phone: _n(m['Telefono']),
          address: _n(m['Indirizzo']),
        ),
      );
      n++;
    }
    return n;
  },
);
