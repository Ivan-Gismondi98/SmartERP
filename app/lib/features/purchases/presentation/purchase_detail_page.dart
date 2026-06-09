// ============================================================
//  SMARTERP · purchase_detail_page.dart — dettaglio documento d'acquisto.
//  Azioni: modifica/elimina, conferma (numerazione), avanzamento stato,
//  duplica.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../application/purchases_providers.dart';
import '../data/purchases_repository.dart';
import '../domain/purchase_document.dart';
import 'purchase_form_page.dart';

class PurchaseDetailPage extends ConsumerWidget {
  const PurchaseDetailPage({super.key, required this.documentId});
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(purchaseDetailProvider(documentId));
    final canEdit = ref.watch(canProvider(Perm.purchasesEdit));
    final canIssue = ref.watch(canProvider(Perm.purchasesIssue));
    final canDelete = ref.watch(canProvider(Perm.purchasesDelete));
    final canCreate = ref.watch(canProvider(Perm.purchasesCreate));

    return Scaffold(
      appBar: AppBar(title: const Text('Dettaglio documento')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (doc) => _DetailBody(
          doc: doc,
          canEdit: canEdit,
          canIssue: canIssue,
          canDelete: canDelete,
          canCreate: canCreate,
          onChanged: () => ref.invalidate(purchaseDetailProvider(documentId)),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.doc,
    required this.canEdit,
    required this.canIssue,
    required this.canDelete,
    required this.canCreate,
    required this.onChanged,
  });

  final PurchaseDocument doc;
  final bool canEdit;
  final bool canIssue;
  final bool canDelete;
  final bool canCreate;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(purchasesRepositoryProvider);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('${doc.kindLabel} ${doc.displayNumber}',
                        style: theme.textTheme.headlineSmall),
                  ),
                  Chip(label: Text(doc.status.label)),
                ],
              ),
              Text('Data: ${Fmt.date(doc.issueDate)}'
                  '${doc.validUntil != null ? '  ·  ${doc.kind == PurchaseKind.contract ? 'Scadenza' : 'Validità'}: ${Fmt.date(doc.validUntil)}' : ''}'),
              if (doc.supplierRef != null && doc.supplierRef!.isNotEmpty)
                Text('Rif. fornitore: ${doc.supplierRef}'),
              const Divider(height: 32),
              Text('Fornitore', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(doc.supplier?.name ?? '—',
                  style: theme.textTheme.titleSmall),
              if (doc.supplier?.vatNumber != null)
                Text('P.IVA ${doc.supplier!.vatNumber}'),
              if (doc.supplier?.address != null)
                Text(doc.supplier!.address!),
              const Divider(height: 32),
              Text('Righe', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _ItemsTable(doc: doc),
              const Divider(height: 32),
              Text('Riepilogo IVA', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _VatSummaryTable(doc: doc),
              const SizedBox(height: 16),
              _TotalsBox(doc: doc),
              if (doc.paymentTerms != null && doc.paymentTerms!.isNotEmpty) ...[
                const Divider(height: 32),
                Text('Pagamento', style: theme.textTheme.titleMedium),
                Text(doc.paymentTerms!),
              ],
              if (doc.notes != null && doc.notes!.isNotEmpty) ...[
                const Divider(height: 32),
                Text('Note', style: theme.textTheme.titleMedium),
                Text(doc.notes!),
              ],
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (doc.isDraft && canDelete)
                  OutlinedButton.icon(
                    onPressed: () => _delete(context, repo),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Elimina'),
                  ),
                if (doc.isDraft && canEdit)
                  OutlinedButton.icon(
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifica'),
                  ),
                if (doc.isDraft && canIssue)
                  FilledButton.icon(
                    onPressed: () => _confirm(context, repo),
                    icon: const Icon(Icons.send),
                    label: const Text('Conferma'),
                  ),
                if (doc.status == PurchaseStatus.sent && canEdit)
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _mark(context, repo, PurchaseStatus.confirmed),
                    icon: const Icon(Icons.handshake_outlined),
                    label: const Text('Confermato dal fornitore'),
                  ),
                if ((doc.status == PurchaseStatus.confirmed ||
                        doc.status == PurchaseStatus.sent) &&
                    canEdit)
                  FilledButton.icon(
                    onPressed: () =>
                        _mark(context, repo, PurchaseStatus.received),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Ricevuto'),
                  ),
                if (doc.status != PurchaseStatus.cancelled &&
                    doc.status != PurchaseStatus.received &&
                    canEdit)
                  OutlinedButton.icon(
                    onPressed: () =>
                        _mark(context, repo, PurchaseStatus.cancelled),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Annulla'),
                  ),
                if (canCreate)
                  OutlinedButton.icon(
                    onPressed: () => _duplicate(context, ref),
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Duplica'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PurchaseFormPage(documentId: doc.id)),
    );
    if (changed == true) onChanged();
  }

  Future<void> _confirm(BuildContext context, PurchasesRepository repo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confermare il ${doc.kind.label.toLowerCase()}?'),
        content: const Text(
            'Verrà assegnato un numero progressivo e il documento passerà in '
            'stato "Inviato".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Conferma')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final n = await repo.confirm(doc);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Documento n. $n')));
      }
      onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref) async {
    try {
      final newId =
          await ref.read(purchasesRepositoryProvider).duplicateFrom(doc);
      if (!context.mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => PurchaseFormPage(documentId: newId)),
      );
      onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  Future<void> _mark(BuildContext context, PurchasesRepository repo,
      PurchaseStatus s) async {
    try {
      await repo.setStatus(doc.id!, s);
      onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  Future<void> _delete(BuildContext context, PurchasesRepository repo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare la bozza?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.delete(doc.id!);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ItemsTable extends StatelessWidget {
  const _ItemsTable({required this.doc});
  final PurchaseDocument doc;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final it in doc.items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(it.description),
            subtitle: Text(
                '${Fmt.qty(it.quantity)} × ${Fmt.euro(it.unitPrice)}'
                '${it.discountPercent > 0 ? '  −${Fmt.percent(it.discountPercent)}' : ''}'
                '   ·   IVA ${it.vatRate == 0 ? (it.vatNature?.code ?? '0%') : Fmt.percent(it.vatRate)}'),
            trailing: Text(Fmt.euro(it.taxableBase)),
          ),
      ],
    );
  }
}

class _VatSummaryTable extends StatelessWidget {
  const _VatSummaryTable({required this.doc});
  final PurchaseDocument doc;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      children: [
        const TableRow(children: [
          Text('Aliquota', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Imponibile',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Imposta',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        for (final l in doc.vatSummary)
          TableRow(children: [
            Text(l.vatRate == 0
                ? (l.nature?.code ?? 'Esente')
                : Fmt.percent(l.vatRate)),
            Text(Fmt.euro(l.taxable), textAlign: TextAlign.right),
            Text(Fmt.euro(l.tax), textAlign: TextAlign.right),
          ]),
      ],
    );
  }
}

class _TotalsBox extends StatelessWidget {
  const _TotalsBox({required this.doc});
  final PurchaseDocument doc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: bold
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.bodyMedium),
              Text(value,
                  style: bold
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.bodyMedium),
            ],
          ),
        );

    return Column(
      children: [
        row('Imponibile', Fmt.euro(doc.subtotal)),
        row('IVA', Fmt.euro(doc.taxAmount)),
        const Divider(),
        row('TOTALE', Fmt.euro(doc.total), bold: true),
      ],
    );
  }
}
