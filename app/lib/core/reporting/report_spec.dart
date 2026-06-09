// ============================================================
//  SMARTERP · report_spec.dart — descrittore generico di un report/elenco
//  applicativo. Una sola definizione di colonne guida sia l'export sia
//  l'import (le intestazioni combaciano: la `key` è l'intestazione).
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Colonna del report: `key` è l'intestazione (usata in export E import),
/// `value` estrae il valore testuale della riga per l'export.
class ReportColumn<T> {
  const ReportColumn(this.key, this.value);
  final String key;
  final String Function(T row) value;
}

/// Specifica di un report applicativo.
class ReportSpec<T> {
  const ReportSpec({
    required this.title,
    required this.fileBase,
    required this.columns,
    required this.load,
    this.importRows,
    this.searchableExtra,
  });

  /// Titolo della pagina report.
  final String title;

  /// Base del nome file esportato (es. 'clienti').
  final String fileBase;

  final List<ReportColumn<T>> columns;

  /// Carica i dati (scope per azienda via RLS lato repository).
  final Future<List<T>> Function(WidgetRef ref) load;

  /// Import: riceve le righe come mappe intestazione→valore e le inserisce.
  /// Ritorna il numero di righe importate. null = import non disponibile.
  final Future<int> Function(WidgetRef ref, List<Map<String, String>> rows)?
      importRows;

  /// Testo aggiuntivo per la ricerca (oltre ai valori di colonna).
  final String Function(T row)? searchableExtra;

  bool get canImport => importRows != null;

  List<String> get headers => [for (final c in columns) c.key];

  List<String> rowValues(T row) => [for (final c in columns) c.value(row)];
}
