// ============================================================
//  SMARTERP · purchases_page.dart — elenco documenti di acquisto
//  (offerte, ordini, contratti) con ricerca e filtri.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../../core/reporting/entity_report_page.dart';
import '../application/purchases_import_export.dart';
import '../application/purchases_providers.dart';
import '../application/purchases_report.dart';
import '../domain/purchase_document.dart';
import 'purchase_detail_page.dart';
import 'purchase_form_page.dart';

class PurchasesPage extends ConsumerStatefulWidget {
  const PurchasesPage({super.key});

  @override
  ConsumerState<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends ConsumerState<PurchasesPage> {
  String _query = '';
  PurchaseKind? _kindFilter;
  PurchaseStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(canProvider(Perm.purchasesCreate));
    final listAsync = ref.watch(purchasesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acquisti'),
        actions: [
          IconButton(
            tooltip: 'Report / Export',
            icon: const Icon(Icons.assessment_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => EntityReportPage<PurchaseDocument>(
                    spec: purchasesReportSpec))),
          ),
          IconButton(
            tooltip: 'Importa / Esporta righe',
            icon: const Icon(Icons.import_export),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => EntityReportPage<PurchaseLineRow>(
                    spec: purchasesLinesSpec))),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(null),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo documento'),
            )
          : null,
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (all) {
          final filtered = _applyFilters(all);
          return Column(
            children: [
              _SummaryHeader(docs: all),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Cerca per numero o fornitore',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              _FilterBar(
                kind: _kindFilter,
                status: _statusFilter,
                onKind: (k) => setState(() => _kindFilter = k),
                onStatus: (s) => setState(() => _statusFilter = s),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Nessun documento.'))
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(purchasesListProvider),
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) => _DocTile(
                            doc: filtered[i],
                            onTap: () => _openDetail(filtered[i].id!),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<PurchaseDocument> _applyFilters(List<PurchaseDocument> all) {
    final q = _query.trim().toLowerCase();
    return all.where((d) {
      if (_kindFilter != null && d.kind != _kindFilter) return false;
      if (_statusFilter != null && d.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      final hay = '${d.displayNumber} ${d.supplier?.name ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _openEditor(String? id) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PurchaseFormPage(documentId: id)),
    );
    if (changed == true) ref.invalidate(purchasesListProvider);
  }

  Future<void> _openDetail(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PurchaseDetailPage(documentId: id)),
    );
    ref.invalidate(purchasesListProvider);
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.docs});
  final List<PurchaseDocument> docs;

  @override
  Widget build(BuildContext context) {
    final orders = docs.where((d) => d.kind == PurchaseKind.order).length;
    final offers = docs.where((d) => d.kind == PurchaseKind.offer).length;
    final contracts =
        docs.where((d) => d.kind == PurchaseKind.contract).length;
    final openValue = docs
        .where((d) =>
            d.status != PurchaseStatus.cancelled &&
            d.status != PurchaseStatus.received)
        .fold<double>(0, (s, d) => s + d.total);

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        children: [
          _kpi(context, 'Ordini', '$orders'),
          _kpi(context, 'Offerte', '$offers'),
          _kpi(context, 'Contratti', '$contracts'),
          _kpi(context, 'Impegnato', Fmt.euro(openValue)),
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.kind,
    required this.status,
    required this.onKind,
    required this.onStatus,
  });
  final PurchaseKind? kind;
  final PurchaseStatus? status;
  final ValueChanged<PurchaseKind?> onKind;
  final ValueChanged<PurchaseStatus?> onStatus;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Tutti'),
            selected: kind == null && status == null,
            onSelected: (_) {
              onKind(null);
              onStatus(null);
            },
          ),
          const SizedBox(width: 8),
          for (final k in PurchaseKind.values) ...[
            ChoiceChip(
              label: Text(k.label),
              selected: kind == k,
              onSelected: (_) => onKind(kind == k ? null : k),
            ),
            const SizedBox(width: 8),
          ],
          const SizedBox(width: 4),
          for (final s in PurchaseStatus.values) ...[
            FilterChip(
              label: Text(s.label),
              selected: status == s,
              onSelected: (_) => onStatus(status == s ? null : s),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.doc, required this.onTap});
  final PurchaseDocument doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _StatusBadge(status: doc.status),
      title: Text(
          '${doc.kindLabel} ${doc.displayNumber} · ${Fmt.date(doc.issueDate)}',
          overflow: TextOverflow.ellipsis),
      subtitle: Text(doc.supplier?.name ?? 'Fornitore non indicato'),
      trailing: Text(Fmt.euro(doc.total),
          style: Theme.of(context).textTheme.titleMedium),
      onTap: onTap,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final PurchaseStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (status) {
      PurchaseStatus.draft => (scheme.outline, Icons.edit_note),
      PurchaseStatus.sent => (scheme.primary, Icons.send),
      PurchaseStatus.confirmed => (Colors.orange, Icons.handshake_outlined),
      PurchaseStatus.received => (Colors.green, Icons.inventory_2_outlined),
      PurchaseStatus.cancelled => (scheme.error, Icons.cancel_outlined),
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color),
    );
  }
}
