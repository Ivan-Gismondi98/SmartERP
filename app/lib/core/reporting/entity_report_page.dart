// ============================================================
//  SMARTERP · entity_report_page.dart — pagina report generica per un
//  elenco applicativo: ricerca/filtri, selezione righe, export multi-formato
//  (Excel/CSV/XML/PDF/Word) della selezione e import (Excel/CSV) con colonne
//  speculari all'export.
// ============================================================
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'report_io.dart';
import 'report_spec.dart';

class EntityReportPage<T> extends ConsumerStatefulWidget {
  const EntityReportPage({super.key, required this.spec});
  final ReportSpec<T> spec;

  @override
  ConsumerState<EntityReportPage<T>> createState() =>
      _EntityReportPageState<T>();
}

class _EntityReportPageState<T> extends ConsumerState<EntityReportPage<T>> {
  late Future<List<T>> _future;
  String _query = '';
  final Set<T> _selected = {};
  bool _busy = false;

  ReportSpec<T> get spec => widget.spec;

  @override
  void initState() {
    super.initState();
    _future = spec.load(ref);
  }

  void _reload() {
    setState(() {
      _selected.clear();
      _future = spec.load(ref);
    });
  }

  List<T> _filter(List<T> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((row) {
      final hay = [
        ...spec.rowValues(row),
        if (spec.searchableExtra != null) spec.searchableExtra!(row),
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report · ${spec.title}'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<T>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Errore: ${snap.error}'));
          }
          final all = snap.data ?? const [];
          final rows = _filter(all);
          final allSelected =
              rows.isNotEmpty && rows.every(_selected.contains);
          return Column(
            children: [
              _toolbar(context, rows),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Filtra…',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: allSelected,
                title: Text(
                    'Seleziona tutto (${_selected.length}/${rows.length})'),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.addAll(rows);
                  } else {
                    _selected.removeAll(rows);
                  }
                }),
              ),
              const Divider(height: 1),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('Nessun dato.'))
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final row = rows[i];
                          final values = spec.rowValues(row);
                          final sel = _selected.contains(row);
                          return CheckboxListTile(
                            controlAffinity: ListTileControlAffinity.leading,
                            value: sel,
                            title: Text(values.isNotEmpty ? values.first : '—',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              [
                                for (var c = 1; c < spec.columns.length; c++)
                                  '${spec.columns[c].key}: ${values[c]}'
                              ].join('  ·  '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected.add(row);
                              } else {
                                _selected.remove(row);
                              }
                            }),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _toolbar(BuildContext context, List<T> filtered) {
    final exportTarget = _selected.isNotEmpty
        ? _selected.toList()
        : filtered; // se nulla selezionato, esporta i filtrati
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          PopupMenuButton<ReportFormat>(
            enabled: !_busy && exportTarget.isNotEmpty,
            onSelected: (f) => _export(context, f, exportTarget),
            itemBuilder: (_) => [
              for (final f in ReportFormat.values)
                PopupMenuItem(value: f, child: Text(f.label)),
            ],
            child: FilledButton.tonalIcon(
              onPressed: null,
              icon: const Icon(Icons.download),
              label: Text(_selected.isEmpty
                  ? 'Esporta (tutti i filtrati)'
                  : 'Esporta selezionati (${_selected.length})'),
            ),
          ),
          if (spec.canImport) ...[
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _import(context),
              icon: const Icon(Icons.upload_file),
              label: const Text('Importa (Excel/CSV)'),
            ),
            TextButton.icon(
              onPressed: _busy ? null : () => _downloadTemplate(),
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Modello'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _export(
      BuildContext context, ReportFormat format, List<T> target) async {
    setState(() => _busy = true);
    try {
      await ReportIO.export(
        format: format,
        fileBase: spec.fileBase,
        headers: spec.headers,
        rows: [for (final r in target) spec.rowValues(r)],
      );
      _snack('Esportati ${target.length} elementi in ${format.label}.');
    } catch (e) {
      _snack('Errore export: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      await ReportIO.export(
        format: ReportFormat.xlsx,
        fileBase: '${spec.fileBase}_modello',
        headers: spec.headers,
        rows: const [],
      );
      _snack('Modello scaricato: usa queste colonne per l\'import.');
    } catch (e) {
      _snack('Errore: $e');
    }
  }

  Future<void> _import(BuildContext context) async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.bytes == null) {
      _snack('Impossibile leggere il file.');
      return;
    }
    setState(() => _busy = true);
    try {
      final parsed = ReportIO.parse(f.bytes!, f.extension ?? 'xlsx');
      if (parsed.isEmpty) {
        _snack('Nessuna riga valida nel file.');
        return;
      }
      final n = await spec.importRows!(ref, parsed);
      _snack('Importati $n elementi.');
      _reload();
    } catch (e) {
      _snack('Errore import: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(m)));
    }
  }
}
