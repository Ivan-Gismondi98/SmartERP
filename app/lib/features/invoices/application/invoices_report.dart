// ============================================================
//  SMARTERP · invoices_report.dart — Report/Export Fatture.
// ============================================================
import '../../../core/format.dart';
import '../../../core/reporting/report_spec.dart';
import '../domain/invoice.dart';
import 'invoices_providers.dart';

final invoicesReportSpec = ReportSpec<Invoice>(
  title: 'Fatture',
  fileBase: 'fatture',
  columns: [
    ReportColumn('Tipo', (i) => i.documentTypeLabel),
    ReportColumn('Numero', (i) => i.displayNumber),
    ReportColumn('Data', (i) => Fmt.date(i.issueDate)),
    ReportColumn('Scadenza', (i) => Fmt.date(i.dueDate)),
    ReportColumn('Cliente', (i) => i.customer?.name ?? ''),
    ReportColumn('Stato', (i) => i.status.label),
    ReportColumn('Imponibile', (i) => Fmt.euro(i.subtotal)),
    ReportColumn('IVA', (i) => Fmt.euro(i.taxAmount)),
    ReportColumn('Totale', (i) => Fmt.euro(i.total)),
  ],
  load: (ref) => ref.read(invoicesListProvider.future),
);
