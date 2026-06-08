// ============================================================
//  SMARTERP · error_logs_page.dart — "Bug del giorno".
//  Elenco errori (ultimo periodo), filtri per gravità, periodo e testo.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../application/error_logs_providers.dart';
import '../data/error_logs_repository.dart';
import '../domain/error_log.dart';

class ErrorLogsPage extends ConsumerStatefulWidget {
  const ErrorLogsPage({super.key});

  @override
  ConsumerState<ErrorLogsPage> createState() => _ErrorLogsPageState();
}

class _ErrorLogsPageState extends ConsumerState<ErrorLogsPage> {
  String _text = '';

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(canProvider(Perm.errorsView))) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bug del giorno')),
        body: const Center(child: Text('Permesso non disponibile.')),
      );
    }

    final filter = ref.watch(errorFilterProvider);
    final logsAsync = ref.watch(errorLogsProvider);
    final canDelete = ref.watch(canProvider(Perm.errorsView)); // super_admin lato RLS

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bug del giorno'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(errorLogsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filtra per messaggio o modulo',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _text = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Periodo
                DropdownButton<int>(
                  value: filter.days,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Oggi')),
                    DropdownMenuItem(value: 7, child: Text('7 giorni')),
                    DropdownMenuItem(value: 30, child: Text('30 giorni')),
                    DropdownMenuItem(value: 90, child: Text('90 giorni')),
                  ],
                  onChanged: (v) => ref.read(errorFilterProvider.notifier).state =
                      filter.copyWith(days: v ?? 30),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Tutte'),
                  selected: filter.severity == null,
                  onSelected: (_) => ref
                      .read(errorFilterProvider.notifier)
                      .state = filter.copyWith(clearSeverity: true),
                ),
                const SizedBox(width: 8),
                for (final s in kSeverities) ...[
                  ChoiceChip(
                    label: Text(severityLabel(s)),
                    selected: filter.severity == s,
                    onSelected: (_) => ref
                        .read(errorFilterProvider.notifier)
                        .state = filter.copyWith(severity: s),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Errore: $e')),
              data: (logs) {
                final q = _text.trim().toLowerCase();
                final filtered = q.isEmpty
                    ? logs
                    : logs
                        .where((l) =>
                            '${l.message} ${l.module ?? ''} ${l.route ?? ''}'
                                .toLowerCase()
                                .contains(q))
                        .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('Nessun errore registrato.'));
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _ErrorTile(log: filtered[i], canDelete: canDelete),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorTile extends ConsumerWidget {
  const _ErrorTile({required this.log, required this.canDelete});
  final ErrorLog log;
  final bool canDelete;

  Color _color(BuildContext context) {
    switch (log.severity) {
      case 'info':
        return Colors.blueGrey;
      case 'warning':
        return Colors.orange;
      case 'fatal':
        return Colors.red.shade900;
      default:
        return Theme.of(context).colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _color(context);
    final when = DateFormat('dd/MM/yyyy HH:mm').format(log.createdAt.toLocal());
    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(Icons.bug_report_outlined, color: color),
      ),
      title: Text(log.message, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${severityLabel(log.severity)} · '
          '${log.module ?? '—'} · $when'
          '${log.route != null ? ' · ${log.route}' : ''}'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        if (log.details != null)
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(log.details!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
        if (canDelete)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                try {
                  await ref.read(errorLogsRepositoryProvider).delete(log.id);
                  ref.invalidate(errorLogsProvider);
                } catch (_) {}
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Elimina'),
            ),
          ),
      ],
    );
  }
}
