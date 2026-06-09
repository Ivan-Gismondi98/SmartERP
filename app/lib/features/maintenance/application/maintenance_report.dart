// ============================================================
//  SMARTERP · maintenance_report.dart — Report/Import-Export richieste e
//  attrezzature.
// ============================================================
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/reporting/report_spec.dart';
import '../../profile/application/profile_providers.dart';
import '../data/maintenance_repository.dart';
import '../domain/equipment.dart';
import '../domain/maintenance_request.dart';
import 'maintenance_providers.dart';

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

String? _n(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

EquipmentStatus _eqStatus(String? v) {
  final s = (v ?? '').trim().toLowerCase();
  return EquipmentStatus.values.firstWhere(
    (e) => e.db == s || e.label.toLowerCase() == s,
    orElse: () => EquipmentStatus.operational,
  );
}

MaintenanceType _reqType(String? v) {
  final s = (v ?? '').trim().toLowerCase();
  return MaintenanceType.values.firstWhere(
    (e) => e.db == s || e.label.toLowerCase() == s,
    orElse: () => MaintenanceType.corrective,
  );
}

MaintenancePriority _reqPriority(String? v) {
  final s = (v ?? '').trim().toLowerCase();
  return MaintenancePriority.values.firstWhere(
    (e) => e.db == s || e.label.toLowerCase() == s,
    orElse: () => MaintenancePriority.medium,
  );
}

MaintenanceStatus _reqStatus(String? v) {
  final s = (v ?? '').trim().toLowerCase();
  return MaintenanceStatus.values.firstWhere(
    (e) => e.db == s || e.label.toLowerCase() == s,
    orElse: () => MaintenanceStatus.open,
  );
}

final maintenanceRequestsReportSpec = ReportSpec<MaintenanceRequest>(
  title: 'Manutenzione · Richieste',
  fileBase: 'manutenzione_richieste',
  columns: [
    ReportColumn('Titolo', (r) => r.title),
    ReportColumn('Attrezzatura', (r) => r.equipmentName ?? ''),
    ReportColumn('Tipo', (r) => r.type.label),
    ReportColumn('Priorità', (r) => r.priority.label),
    ReportColumn('Stato', (r) => r.status.label),
    ReportColumn('Programmata', (r) => Fmt.date(r.scheduledDate)),
    ReportColumn('Costo', (r) => Fmt.amount(r.cost)),
  ],
  load: (ref) => ref.read(maintenanceRequestsProvider.future),
  importRows: (ref, rows) async {
    final profile = await ref.read(currentProfileProvider.future);
    final cid = profile?.companyId;
    if (cid == null) throw 'Nessuna azienda associata';
    final repo = ref.read(maintenanceRepositoryProvider);
    final equip = await repo.listEquipment(cid);
    final byName = {for (final e in equip) e.name.trim().toLowerCase(): e.id!};
    var n = 0;
    for (final m in rows) {
      final title = (m['Titolo'] ?? '').trim();
      if (title.isEmpty) continue;
      final eqName = (m['Attrezzatura'] ?? '').trim();
      await repo.createRequest(MaintenanceRequest(
        companyId: cid,
        equipmentId: byName[eqName.toLowerCase()],
        title: title,
        type: _reqType(m['Tipo']),
        priority: _reqPriority(m['Priorità']),
        status: _reqStatus(m['Stato']),
        scheduledDate: _parseDate(m['Programmata']),
        cost: Fmt.parseAmount(m['Costo']) ?? 0,
        requestedBy: profile?.id,
      ));
      n++;
    }
    return n;
  },
);

final equipmentReportSpec = ReportSpec<Equipment>(
  title: 'Manutenzione · Attrezzature',
  fileBase: 'attrezzature',
  columns: [
    ReportColumn('Nome', (e) => e.name),
    ReportColumn('Codice', (e) => e.code ?? ''),
    ReportColumn('Categoria', (e) => e.category ?? ''),
    ReportColumn('Ubicazione', (e) => e.location ?? ''),
    ReportColumn('Stato', (e) => e.status.label),
    ReportColumn('Prossima manutenzione', (e) => Fmt.date(e.nextService)),
  ],
  load: (ref) => ref.read(equipmentListProvider.future),
  importRows: (ref, rows) async {
    final profile = await ref.read(currentProfileProvider.future);
    final cid = profile?.companyId;
    if (cid == null) throw 'Nessuna azienda associata';
    final repo = ref.read(maintenanceRepositoryProvider);
    var n = 0;
    for (final m in rows) {
      final name = (m['Nome'] ?? '').trim();
      if (name.isEmpty) continue;
      await repo.createEquipment(Equipment(
        companyId: cid,
        name: name,
        code: _n(m['Codice']),
        category: _n(m['Categoria']),
        location: _n(m['Ubicazione']),
        status: _eqStatus(m['Stato']),
        nextService: _parseDate(m['Prossima manutenzione']),
      ));
      n++;
    }
    return n;
  },
);
