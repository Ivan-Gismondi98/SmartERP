// ============================================================
//  SMARTERP · documents_report.dart — Report/Export documenti interni.
// ============================================================
import '../../../core/format.dart';
import '../../../core/reporting/report_spec.dart';
import '../domain/document_file.dart';
import 'documents_providers.dart';

final documentsReportSpec = ReportSpec<DocumentFile>(
  title: 'Documenti',
  fileBase: 'documenti',
  columns: [
    ReportColumn('Titolo', (d) => d.title),
    ReportColumn('Categoria', (d) => d.category),
    ReportColumn('File', (d) => d.fileName),
    ReportColumn('Dimensione', (d) => d.sizeLabel),
    ReportColumn('Data', (d) => Fmt.date(d.createdAt)),
  ],
  load: (ref) => ref.read(documentsListProvider.future),
);
