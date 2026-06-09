// ============================================================
//  SMARTERP · accounting_report.dart — Report/Export prima nota.
// ============================================================
import '../../../core/format.dart';
import '../../../core/reporting/report_spec.dart';
import '../domain/journal_entry.dart';
import 'accounting_providers.dart';

final accountingReportSpec = ReportSpec<JournalEntry>(
  title: 'Contabilità · Prima nota',
  fileBase: 'prima_nota',
  columns: [
    ReportColumn('Numero', (e) => e.displayNumber),
    ReportColumn('Data', (e) => Fmt.date(e.entryDate)),
    ReportColumn('Causale', (e) => e.description),
    ReportColumn('Documento', (e) => e.docRef ?? ''),
    ReportColumn('Dare', (e) => Fmt.euro(e.totalDebit)),
    ReportColumn('Avere', (e) => Fmt.euro(e.totalCredit)),
  ],
  load: (ref) => ref.read(journalEntriesProvider.future),
);
