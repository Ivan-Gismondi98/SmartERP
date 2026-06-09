// ============================================================
//  SMARTERP · invoices_page.dart — elenco fatture con ricerca,
//  filtri per stato e riepilogo (KPI).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../../core/reporting/entity_report_page.dart';
import '../application/invoices_import_export.dart';
import '../application/invoices_providers.dart';
import '../application/invoices_report.dart';
import '../domain/invoice.dart';
import 'invoice_detail_page.dart';
import 'invoice_form_page.dart';

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  String _query = '';
  InvoiceStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(canProvider(Perm.invoicesCreate));
    final listAsync = ref.watch(invoicesListProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fatture'),
        actions: [
          IconButton(
            tooltip: 'Report / Export',
            icon: const Icon(Icons.assessment_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    EntityReportPage<Invoice>(spec: invoicesReportSpec))),
          ),
          IconButton(
            tooltip: 'Importa / Esporta righe',
            icon: const Icon(Icons.import_export),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    EntityReportPage<InvoiceLineRow>(spec: invoicesLinesSpec))),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(null),
              icon: const Icon(Icons.add),
              label: const Text('Nuova fattura'),
            )
          : null,
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (all) {
          final filtered = _applyFilters(all);
          return Column(
            children: [
              _SummaryHeader(invoices: all, now: now),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Cerca per numero o cliente',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              _StatusFilterBar(
                selected: _statusFilter,
                onSelected: (s) => setState(() => _statusFilter = s),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Nessuna fattura.'))
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(invoicesListProvider),
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, i) =>
                              _InvoiceTile(inv: filtered[i], now: now,
                                  onTap: () => _openDetail(filtered[i].id!)),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Invoice> _applyFilters(List<Invoice> all) {
    final q = _query.trim().toLowerCase();
    return all.where((inv) {
      if (_statusFilter != null && inv.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      final hay =
          '${inv.displayNumber} ${inv.customer?.name ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _openEditor(String? id) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => InvoiceFormPage(invoiceId: id)),
    );
    if (changed == true) ref.invalidate(invoicesListProvider);
  }

  Future<void> _openDetail(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoiceId: id)),
    );
    ref.invalidate(invoicesListProvider);
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.invoices, required this.now});
  final List<Invoice> invoices;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final issued = invoices.where((i) => i.isIssued).toList();
    final totEmesso =
        issued.fold<double>(0, (s, i) => s + (i.isCreditNote ? -i.total : i.total));
    final incassato = invoices
        .where((i) => i.status == InvoiceStatus.paid)
        .fold<double>(0, (s, i) => s + i.total);
    final scadute = invoices.where((i) => i.overdueAt(now)).length;

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        children: [
          _kpi(context, 'Documenti', '${invoices.length}'),
          _kpi(context, 'Emesso (netto)', Fmt.euro(totEmesso)),
          _kpi(context, 'Incassato', Fmt.euro(incassato)),
          _kpi(context, 'Scadute', '$scadute'),
        ],
      ),
    );
  }

  Widget _kpi(BuildContext context, String label, String value) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: t.bodySmall),
        Text(value, style: t.titleMedium),
      ],
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.selected, required this.onSelected});
  final InvoiceStatus? selected;
  final ValueChanged<InvoiceStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Tutte'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: 8),
          for (final s in InvoiceStatus.values) ...[
            ChoiceChip(
              label: Text(s.label),
              selected: selected == s,
              onSelected: (_) => onSelected(s),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile(
      {required this.inv, required this.now, required this.onTap});
  final Invoice inv;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = inv.overdueAt(now);
    return ListTile(
      leading: _StatusBadge(status: inv.status, overdue: overdue),
      title: Row(
        children: [
          Flexible(
            child: Text(
                '${inv.documentTypeLabel} ${inv.displayNumber} · ${Fmt.date(inv.issueDate)}',
                overflow: TextOverflow.ellipsis),
          ),
          if (overdue)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.warning_amber, size: 16, color: Colors.orange),
            ),
        ],
      ),
      subtitle: Text(inv.customer?.name ?? 'Cliente non indicato'),
      trailing: Text(
        '${inv.isCreditNote ? '−' : ''}${Fmt.euro(inv.total)}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: onTap,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, this.overdue = false});
  final InvoiceStatus status;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (status) {
      InvoiceStatus.draft => (scheme.outline, Icons.edit_note),
      InvoiceStatus.sent => overdue
          ? (Colors.orange, Icons.warning_amber)
          : (scheme.primary, Icons.send),
      InvoiceStatus.paid => (Colors.green, Icons.check_circle),
      InvoiceStatus.overdue => (scheme.error, Icons.warning_amber),
      InvoiceStatus.cancelled => (scheme.outline, Icons.cancel),
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color),
    );
  }
}
