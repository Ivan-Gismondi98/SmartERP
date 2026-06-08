// ============================================================
//  SMARTERP · dev_dashboard_page.dart — Dashboard Sviluppatore.
//  Riepilogo organizzazioni/licenze/incassato/ritardi + KPI bug e ticket.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../errors/domain/error_log.dart';
import '../application/developer_providers.dart';
import 'licenses_page.dart';

class DevDashboardPage extends ConsumerWidget {
  const DevDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Sviluppatore'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dashboardProvider),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (d) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Clienti e licenze',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: _cols(context),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _Kpi(label: 'Organizzazioni', value: '${d.organizations}', icon: Icons.business),
                _Kpi(label: 'Licenze attive', value: '${d.activeLicenses}', icon: Icons.workspace_premium_outlined),
                _Kpi(label: 'Incassato', value: Fmt.euro(d.totalPaid), icon: Icons.payments_outlined, color: Colors.green),
                _Kpi(
                    label: 'Licenze in ritardo',
                    value: '${d.overdueLicenses}',
                    icon: Icons.warning_amber,
                    color: d.overdueLicenses > 0 ? Colors.orange : null),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const LicensesPage())),
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('Gestisci licenze e pagamenti'),
            ),
            const Divider(height: 32),
            Text('Bug rilevati (ultimi 30 giorni)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _SeverityBars(counts: d.bugBySeverity),
            const Divider(height: 32),
            Text('Ticket', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _TicketRow(counts: d.ticketsByStatus),
          ],
        ),
      ),
    );
  }

  int _cols(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 700 ? 4 : 2;
}

class _Kpi extends StatelessWidget {
  const _Kpi(
      {required this.label,
      required this.value,
      required this.icon,
      this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: c),
            const Spacer(),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: c, fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SeverityBars extends StatelessWidget {
  const _SeverityBars({required this.counts});
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (s, v) => s + v);
    if (total == 0) return const Text('Nessun bug nel periodo. 🎉');
    Color color(String s) => switch (s) {
          'info' => Colors.blueGrey,
          'warning' => Colors.orange,
          'fatal' => Colors.red.shade900,
          _ => Theme.of(context).colorScheme.error,
        };
    return Column(
      children: [
        for (final s in kSeverities)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text(severityLabel(s))),
                Expanded(
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : (counts[s] ?? 0) / total,
                    color: color(s),
                    backgroundColor: color(s).withValues(alpha: 0.12),
                    minHeight: 10,
                  ),
                ),
                SizedBox(
                    width: 36,
                    child: Text(' ${counts[s] ?? 0}',
                        textAlign: TextAlign.right)),
              ],
            ),
          ),
      ],
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.counts});
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    const labels = {
      'open': 'Aperti',
      'in_progress': 'In corso',
      'resolved': 'Risolti',
      'closed': 'Chiusi',
    };
    final total = counts.values.fold<int>(0, (s, v) => s + v);
    if (total == 0) {
      return const Text('Nessun ticket. (verranno generati dalle segnalazioni)');
    }
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final e in labels.entries)
          Chip(
            label: Text('${e.value}: ${counts[e.key] ?? 0}'),
          ),
      ],
    );
  }
}
