// ============================================================
//  SMARTERP · sales_report.dart — Report/Export Vendite (preventivi/ordini).
// ============================================================
import '../../../core/format.dart';
import '../../../core/reporting/report_spec.dart';
import '../domain/sales_document.dart';
import 'sales_providers.dart';

final salesReportSpec = ReportSpec<SalesDocument>(
  title: 'Vendite',
  fileBase: 'vendite',
  columns: [
    ReportColumn('Tipo', (d) => d.kindLabel),
    ReportColumn('Numero', (d) => d.displayNumber),
    ReportColumn('Data', (d) => Fmt.date(d.issueDate)),
    ReportColumn('Validità', (d) => Fmt.date(d.validUntil)),
    ReportColumn('Cliente', (d) => d.customer?.name ?? ''),
    ReportColumn('Stato', (d) => d.status.label),
    ReportColumn('Imponibile', (d) => Fmt.euro(d.subtotal)),
    ReportColumn('IVA', (d) => Fmt.euro(d.taxAmount)),
    ReportColumn('Totale', (d) => Fmt.euro(d.total)),
  ],
  load: (ref) => ref.read(salesListProvider.future),
);
