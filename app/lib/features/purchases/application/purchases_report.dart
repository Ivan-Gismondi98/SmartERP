// ============================================================
//  SMARTERP · purchases_report.dart — Report/Export documenti di acquisto.
// ============================================================
import '../../../core/format.dart';
import '../../../core/reporting/report_spec.dart';
import '../domain/purchase_document.dart';
import 'purchases_providers.dart';

final purchasesReportSpec = ReportSpec<PurchaseDocument>(
  title: 'Acquisti',
  fileBase: 'acquisti',
  columns: [
    ReportColumn('Tipo', (d) => d.kindLabel),
    ReportColumn('Numero', (d) => d.displayNumber),
    ReportColumn('Data', (d) => Fmt.date(d.issueDate)),
    ReportColumn('Fornitore', (d) => d.supplier?.name ?? ''),
    ReportColumn('Rif. fornitore', (d) => d.supplierRef ?? ''),
    ReportColumn('Stato', (d) => d.status.label),
    ReportColumn('Imponibile', (d) => Fmt.euro(d.subtotal)),
    ReportColumn('IVA', (d) => Fmt.euro(d.taxAmount)),
    ReportColumn('Totale', (d) => Fmt.euro(d.total)),
  ],
  load: (ref) => ref.read(purchasesListProvider.future),
);
