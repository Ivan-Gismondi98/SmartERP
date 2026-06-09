// ============================================================
//  SMARTERP · crm_report.dart — Report/Import-Export opportunità CRM.
// ============================================================
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/reporting/report_spec.dart';
import '../../profile/application/profile_providers.dart';
import '../data/crm_repository.dart';
import '../domain/opportunity.dart';
import 'crm_providers.dart';

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

CrmStage _stage(String? v) {
  final s = (v ?? '').trim().toLowerCase();
  return CrmStage.values.firstWhere(
    (e) => e.db == s || e.label.toLowerCase() == s,
    orElse: () => CrmStage.newLead,
  );
}

final crmReportSpec = ReportSpec<Opportunity>(
  title: 'CRM',
  fileBase: 'crm_opportunita',
  columns: [
    ReportColumn('Titolo', (o) => o.title),
    ReportColumn('Contatto', (o) => o.displayContact),
    ReportColumn('Stadio', (o) => o.stage.label),
    ReportColumn('Valore atteso', (o) => Fmt.amount(o.expectedValue)),
    ReportColumn('Probabilità', (o) => '${o.probability}'),
    ReportColumn('Chiusura prevista', (o) => Fmt.date(o.expectedClose)),
    ReportColumn('Origine', (o) => o.source ?? ''),
  ],
  load: (ref) => ref.read(opportunitiesListProvider.future),
  importRows: (ref, rows) async {
    final profile = await ref.read(currentProfileProvider.future);
    final cid = profile?.companyId;
    if (cid == null) throw 'Nessuna azienda associata';
    final repo = ref.read(crmRepositoryProvider);
    var n = 0;
    for (final m in rows) {
      final title = (m['Titolo'] ?? '').trim();
      if (title.isEmpty) continue;
      final prob = (Fmt.parseAmount(m['Probabilità']) ?? 0).round().clamp(0, 100);
      await repo.create(Opportunity(
        companyId: cid,
        title: title,
        contactCompany: (m['Contatto'] ?? '').trim().isEmpty
            ? null
            : m['Contatto']!.trim(),
        stage: _stage(m['Stadio']),
        expectedValue: Fmt.parseAmount(m['Valore atteso']) ?? 0,
        probability: prob,
        expectedClose: _parseDate(m['Chiusura prevista']),
        source: (m['Origine'] ?? '').trim().isEmpty ? null : m['Origine']!.trim(),
        ownerId: profile?.id,
      ));
      n++;
    }
    return n;
  },
);
