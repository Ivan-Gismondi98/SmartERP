// ============================================================
//  SMARTERP · customers_report.dart — descrittore Report/Import-Export Clienti.
// ============================================================
import '../../../core/reporting/report_spec.dart';
import '../../profile/application/profile_providers.dart';
import '../data/customers_repository.dart';
import '../domain/customer.dart';

String _s(String? v) => v ?? '';

final customersReportSpec = ReportSpec<Customer>(
  title: 'Clienti',
  fileBase: 'clienti',
  columns: [
    ReportColumn('Nome', (c) => c.name),
    ReportColumn('Tipo', (c) => c.isCompany ? 'Azienda' : 'Persona'),
    ReportColumn('P.IVA', (c) => _s(c.vatNumber)),
    ReportColumn('Cod.Fiscale', (c) => _s(c.taxCode)),
    ReportColumn('Email', (c) => _s(c.email)),
    ReportColumn('Telefono', (c) => _s(c.phone)),
    ReportColumn('Indirizzo', (c) => _s(c.address)),
    ReportColumn('CAP', (c) => _s(c.zip)),
    ReportColumn('Città', (c) => _s(c.city)),
    ReportColumn('Provincia', (c) => _s(c.province)),
    ReportColumn('SDI', (c) => c.sdiCode),
    ReportColumn('PEC', (c) => _s(c.pec)),
  ],
  load: (ref) async {
    final profile = await ref.read(currentProfileProvider.future);
    final cid = profile?.companyId;
    if (cid == null) return <Customer>[];
    return ref.read(customersRepositoryProvider).list(cid);
  },
  importRows: (ref, rows) async {
    final profile = await ref.read(currentProfileProvider.future);
    final cid = profile?.companyId;
    if (cid == null) throw 'Nessuna azienda associata';
    final repo = ref.read(customersRepositoryProvider);
    var n = 0;
    for (final m in rows) {
      final name = (m['Nome'] ?? '').trim();
      if (name.isEmpty) continue;
      final tipo = (m['Tipo'] ?? '').trim().toLowerCase();
      final sdi = (m['SDI'] ?? '').trim();
      await repo.create(
        cid,
        Customer(
          id: '',
          companyId: cid,
          name: name,
          isCompany: tipo.isEmpty ? true : tipo.startsWith('a'),
          vatNumber: _n(m['P.IVA']),
          taxCode: _n(m['Cod.Fiscale']),
          email: _n(m['Email']),
          phone: _n(m['Telefono']),
          address: _n(m['Indirizzo']),
          zip: _n(m['CAP']),
          city: _n(m['Città']),
          province: _n(m['Provincia']),
          sdiCode: sdi.isEmpty ? '0000000' : sdi,
          pec: _n(m['PEC']),
        ),
      );
      n++;
    }
    return n;
  },
);

String? _n(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
