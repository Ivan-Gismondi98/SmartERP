// ============================================================
//  SMARTERP · tickets_page.dart — segnalazioni/ticket (realtime).
//  Lista che si aggiorna in tempo reale, cambio stato, export Excel.
// ============================================================
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/xlsx.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/profile.dart';
import '../data/tickets_repository.dart';
import '../domain/ticket.dart';
import 'ticket_thread_page.dart';

class TicketsPage extends ConsumerWidget {
  const TicketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ticketsFutureProvider);
    final role = ref.watch(currentProfileProvider).valueOrNull?.role;
    final canManage = role == UserRole.admin || role == UserRole.superAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Segnalazioni / Ticket'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(ticketsFutureProvider),
          ),
          if (canManage)
            IconButton(
              tooltip: 'Esporta Excel',
              icon: const Icon(Icons.table_view_outlined),
              onPressed: () => _exportExcel(context, ref),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (tickets) {
          if (tickets.isEmpty) {
            return const Center(child: Text('Nessuna segnalazione.'));
          }
          return ListView.separated(
            itemCount: tickets.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) =>
                _TicketTile(ticket: tickets[i], canManage: canManage),
          );
        },
      ),
    );
  }

  Future<void> _exportExcel(BuildContext context, WidgetRef ref) async {
    final tickets = ref.read(ticketsFutureProvider).valueOrNull ?? const [];
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final rows = tickets
        .map((t) => [
              df.format(t.createdAt.toLocal()),
              t.companyName ?? '',
              t.title,
              ticketStatusLabel(t.status),
              t.priority,
              ticketTargetLabel(t.target),
            ])
        .toList();
    final bytes = XlsxBuilder.build(
      headers: const ['Data', 'Organizzazione', 'Titolo', 'Stato', 'Priorità', 'Destinatario'],
      rows: rows,
    );
    try {
      await FileSaver.instance.saveFile(
        name: 'segnalazioni',
        bytes: Uint8List.fromList(bytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Excel esportato.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore export: $e')));
      }
    }
  }
}

class _TicketTile extends ConsumerWidget {
  const _TicketTile({required this.ticket, required this.canManage});
  final Ticket ticket;
  final bool canManage;

  Color _statusColor(BuildContext context) {
    switch (ticket.status) {
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.orange; // open
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColor(context);
    final when = DateFormat('dd/MM/yyyy HH:mm').format(ticket.createdAt.toLocal());
    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(Icons.confirmation_number_outlined, color: color),
      ),
      title: Text(ticket.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '${ticketStatusLabel(ticket.status)} · ${ticketTargetLabel(ticket.target)}'
          '${ticket.companyName != null ? ' · ${ticket.companyName}' : ''} · $when'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        if (ticket.description != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(ticket.description!),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TicketThreadPage(ticket: ticket))),
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Conversazione'),
          ),
        ),
        if (canManage)
          Row(
            children: [
              const Text('Stato: '),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: ticket.status,
                items: [
                  for (final e in kTicketStatuses.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  try {
                    await ref
                        .read(ticketsRepositoryProvider)
                        .setStatus(ticket.id, v);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Errore: $e')));
                    }
                  }
                },
              ),
            ],
          ),
      ],
    );
  }
}
