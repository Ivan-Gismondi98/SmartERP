// ============================================================
//  SMARTERP · projects_report.dart — Report/Import-Export progetti
//  (cliente risolto per nome, facoltativo).
// ============================================================
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/reporting/report_spec.dart';
import '../../customers/data/customers_repository.dart';
import '../../profile/application/profile_providers.dart';
import '../data/projects_repository.dart';
import '../domain/project.dart';
import 'projects_providers.dart';

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

ProjectStatus _status(String? v) {
  final s = (v ?? '').trim().toLowerCase();
  return ProjectStatus.values.firstWhere(
    (e) => e.db == s || e.label.toLowerCase() == s,
    orElse: () => ProjectStatus.planning,
  );
}

final projectsReportSpec = ReportSpec<Project>(
  title: 'Progetti',
  fileBase: 'progetti',
  columns: [
    ReportColumn('Nome', (p) => p.name),
    ReportColumn('Cliente', (p) => p.customer?.name ?? ''),
    ReportColumn('Responsabile', (p) => p.manager ?? ''),
    ReportColumn('Stato', (p) => p.status.label),
    ReportColumn('Inizio', (p) => Fmt.date(p.startDate)),
    ReportColumn('Scadenza', (p) => Fmt.date(p.dueDate)),
    ReportColumn('Budget', (p) => Fmt.amount(p.budget)),
    ReportColumn('Avanzamento',
        (p) => '${(p.progress * 100).round()}% (${p.doneTasks}/${p.totalTasks})'),
  ],
  load: (ref) => ref.read(projectsListProvider.future),
  importRows: (ref, rows) async {
    final profile = await ref.read(currentProfileProvider.future);
    final cid = profile?.companyId;
    if (cid == null) throw 'Nessuna azienda associata';
    final repo = ref.read(projectsRepositoryProvider);
    final customers = await ref.read(customersRepositoryProvider).list(cid);
    final byName = {for (final c in customers) c.name.trim().toLowerCase(): c.id};
    var n = 0;
    for (final m in rows) {
      final name = (m['Nome'] ?? '').trim();
      if (name.isEmpty) continue;
      final cust = (m['Cliente'] ?? '').trim();
      await repo.create(Project(
        companyId: cid,
        name: name,
        customerId: cust.isEmpty ? null : byName[cust.toLowerCase()],
        status: _status(m['Stato']),
        startDate: _parseDate(m['Inizio']),
        dueDate: _parseDate(m['Scadenza']),
        budget: Fmt.parseAmount(m['Budget']) ?? 0,
        manager: (m['Responsabile'] ?? '').trim().isEmpty
            ? null
            : m['Responsabile']!.trim(),
      ));
      n++;
    }
    return n;
  },
);
