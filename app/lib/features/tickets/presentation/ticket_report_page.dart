// ============================================================
//  SMARTERP · ticket_report_page.dart — Report segnalazioni con filtri.
//  È l'unico punto da cui consultare le segnalazioni in QUALSIASI stato
//  (aperte, in lavorazione, risolte, chiuse, abbandonate).
// ============================================================
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/xlsx.dart';
import '../data/tickets_repository.dart';
import '../domain/ticket.dart';
import 'ticket_thread_page.dart';

const _priorities = <String, String>{
  'low': 'Bassa',
  'medium': 'Media',
  'high': 'Alta',
};

class TicketReportPage extends ConsumerStatefulWidget {
  const TicketReportPage({super.key});

  @override
  ConsumerState<TicketReportPage> createState() => _TicketReportPageState();
}

class _TicketReportPageState extends ConsumerState<TicketReportPage> {
  String _query = '';
  String? _status; // null = tutti
  String? _priority;
  String? _target;
  DateTime? _from;
  DateTime? _to;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ticketsFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report segnalazioni'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(ticketsFutureProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (all) {
          final filtered = _apply(all);
          return Column(
            children: [
              _filters(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    Text('${filtered.length} risultati',
                        style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: filtered.isEmpty
                          ? null
                          : () => _export(context, filtered),
                      icon: const Icon(Icons.table_view_outlined, size: 18),
                      label: const Text('Esporta Excel'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Nessun risultato con i filtri.'))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final t = filtered[i];
                          final when = DateFormat('dd/MM/yyyy HH:mm')
                              .format(t.createdAt.toLocal());
                          return ListTile(
                            leading: _StatusDot(status: t.status),
                            title: Text(t.title,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                '${ticketStatusLabel(t.status)} · ${_priorities[t.priority] ?? t.priority}'
                                ' · ${ticketTargetLabel(t.target)}'
                                '${t.companyName != null ? ' · ${t.companyName}' : ''} · $when'),
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        TicketThreadPage(ticket: t))),
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

  List<Ticket> _apply(List<Ticket> all) {
    final q = _query.trim().toLowerCase();
    return all.where((t) {
      if (_status != null && t.status != _status) return false;
      if (_priority != null && t.priority != _priority) return false;
      if (_target != null && t.target != _target) return false;
      final d = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
      if (_from != null && d.isBefore(_from!)) return false;
      if (_to != null && d.isAfter(_to!)) return false;
      if (q.isNotEmpty) {
        final hay =
            '${t.title} ${t.description ?? ''} ${t.companyName ?? ''}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Widget _filters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Cerca per titolo, descrizione o organizzazione',
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _drop('Stato', _status, kTicketStatuses,
                  (v) => setState(() => _status = v)),
              _drop('Priorità', _priority, _priorities,
                  (v) => setState(() => _priority = v)),
              _drop('Destinatario', _target, const {
                'admin': 'Amministratore',
                'developer': 'Sviluppatore',
              }, (v) => setState(() => _target = v)),
              ActionChip(
                avatar: const Icon(Icons.date_range, size: 18),
                label: Text(_from == null && _to == null
                    ? 'Periodo'
                    : '${_from != null ? Fmt.date(_from) : '…'} → ${_to != null ? Fmt.date(_to) : '…'}'),
                onPressed: _pickRange,
              ),
              if (_status != null ||
                  _priority != null ||
                  _target != null ||
                  _from != null ||
                  _to != null ||
                  _query.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.clear, size: 18),
                  label: const Text('Azzera filtri'),
                  onPressed: () => setState(() {
                    _status = null;
                    _priority = null;
                    _target = null;
                    _from = null;
                    _to = null;
                    _query = '';
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drop(String label, String? value, Map<String, String> options,
      ValueChanged<String?> onChanged) {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Tutti')),
          for (final e in options.entries)
            DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: (_from != null && _to != null)
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (range != null) {
      setState(() {
        _from = DateTime(range.start.year, range.start.month, range.start.day);
        _to = DateTime(range.end.year, range.end.month, range.end.day);
      });
    }
  }

  Future<void> _export(BuildContext context, List<Ticket> tickets) async {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final rows = tickets
        .map((t) => [
              df.format(t.createdAt.toLocal()),
              t.companyName ?? '',
              t.title,
              ticketStatusLabel(t.status),
              _priorities[t.priority] ?? t.priority,
              ticketTargetLabel(t.target),
            ])
        .toList();
    final bytes = XlsxBuilder.build(
      headers: const [
        'Data', 'Organizzazione', 'Titolo', 'Stato', 'Priorità', 'Destinatario'
      ],
      rows: rows,
    );
    try {
      await FileSaver.instance.saveFile(
        name: 'report_segnalazioni',
        bytes: Uint8List.fromList(bytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Excel esportato.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore export: $e')));
      }
    }
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'in_progress' => Colors.blue,
      'resolved' => Colors.green,
      'closed' => Colors.grey,
      'cancelled' => Colors.brown,
      _ => Colors.orange,
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(Icons.confirmation_number_outlined, color: color),
    );
  }
}
