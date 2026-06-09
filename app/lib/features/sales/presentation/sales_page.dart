// ============================================================
//  SMARTERP · sales_page.dart — elenco documenti di vendita
//  (preventivi e ordini) con ricerca e filtri per tipo/stato.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../application/sales_providers.dart';
import '../domain/sales_document.dart';
import 'sales_detail_page.dart';
import 'sales_form_page.dart';

class SalesPage extends ConsumerStatefulWidget {
  const SalesPage({super.key});

  @override
  ConsumerState<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends ConsumerState<SalesPage> {
  String _query = '';
  SalesKind? _kindFilter;
  SalesStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(canProvider(Perm.salesCreate));
    final listAsync = ref.watch(salesListProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Vendite')),
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
                    hintText: 'Cerca per numero o cliente',
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
                            ref.invalidate(salesListProvider),
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) => _DocTile(
                            doc: filtered[i],
                            now: now,
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

  List<SalesDocument> _applyFilters(List<SalesDocument> all) {
    final q = _query.trim().toLowerCase();
    return all.where((d) {
      if (_kindFilter != null && d.kind != _kindFilter) return false;
      if (_statusFilter != null && d.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      final hay = '${d.displayNumber} ${d.customer?.name ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _openEditor(String? id) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SalesFormPage(documentId: id)),
    );
    if (changed == true) ref.invalidate(salesListProvider);
  }

  Future<void> _openDetail(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SalesDetailPage(documentId: id)),
    );
    ref.invalidate(salesListProvider);
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.docs});
  final List<SalesDocument> docs;

  @override
  Widget build(BuildContext context) {
    final quotes = docs.where((d) => d.kind == SalesKind.quote).length;
    final orders = docs.where((d) => d.kind == SalesKind.order).length;
    final accepted =
        docs.where((d) => d.status == SalesStatus.accepted).length;
    final openValue = docs
        .where((d) =>
            d.status == SalesStatus.sent || d.status == SalesStatus.accepted)
        .fold<double>(0, (s, d) => s + d.total);

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        children: [
          _kpi(context, 'Preventivi', '$quotes'),
          _kpi(context, 'Ordini', '$orders'),
          _kpi(context, 'Accettati', '$accepted'),
          _kpi(context, 'Valore aperto', Fmt.euro(openValue)),
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
  final SalesKind? kind;
  final SalesStatus? status;
  final ValueChanged<SalesKind?> onKind;
  final ValueChanged<SalesStatus?> onStatus;

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
          for (final k in SalesKind.values) ...[
            ChoiceChip(
              label: Text(k.label),
              selected: kind == k,
              onSelected: (_) => onKind(kind == k ? null : k),
            ),
            const SizedBox(width: 8),
          ],
          const SizedBox(width: 4),
          for (final s in SalesStatus.values) ...[
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
  const _DocTile({required this.doc, required this.now, required this.onTap});
  final SalesDocument doc;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final expired = doc.expiredAt(now);
    return ListTile(
      leading: _StatusBadge(status: doc.status, expired: expired),
      title: Row(
        children: [
          Flexible(
            child: Text(
                '${doc.kindLabel} ${doc.displayNumber} · ${Fmt.date(doc.issueDate)}',
                overflow: TextOverflow.ellipsis),
          ),
          if (expired)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.schedule, size: 16, color: Colors.orange),
            ),
        ],
      ),
      subtitle: Text(doc.customer?.name ?? 'Cliente non indicato'),
      trailing: Text(Fmt.euro(doc.total),
          style: Theme.of(context).textTheme.titleMedium),
      onTap: onTap,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, this.expired = false});
  final SalesStatus status;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (status) {
      SalesStatus.draft => (scheme.outline, Icons.edit_note),
      SalesStatus.sent => expired
          ? (Colors.orange, Icons.schedule)
          : (scheme.primary, Icons.send),
      SalesStatus.accepted => (Colors.green, Icons.thumb_up_alt_outlined),
      SalesStatus.rejected => (scheme.error, Icons.thumb_down_alt_outlined),
      SalesStatus.converted => (Colors.teal, Icons.receipt_long),
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color),
    );
  }
}
