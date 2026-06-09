// ============================================================
//  SMARTERP · production_order_detail_page.dart — dettaglio ordine di
//  produzione: fabbisogni materiali (distinta base × quantità) e azioni
//  di avanzamento. Il completamento consuma i componenti dal magazzino.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../products/application/products_providers.dart';
import '../application/production_providers.dart';
import '../data/production_repository.dart';
import '../domain/production_order.dart';
import 'production_order_form_page.dart';

class ProductionOrderDetailPage extends ConsumerWidget {
  const ProductionOrderDetailPage({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productionOrderDetailProvider(orderId));
    final canEdit = ref.watch(canProvider(Perm.productionEdit));
    final canDelete = ref.watch(canProvider(Perm.productionDelete));
    final canExec = ref.watch(canProvider(Perm.productionExecute));

    return Scaffold(
      appBar: AppBar(title: const Text('Ordine di produzione')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (order) => _Body(
          order: order,
          canEdit: canEdit,
          canDelete: canDelete,
          canExec: canExec,
          onChanged: () {
            ref.invalidate(productionOrderDetailProvider(orderId));
            ref.invalidate(productionOrdersProvider);
          },
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.order,
    required this.canEdit,
    required this.canDelete,
    required this.canExec,
    required this.onChanged,
  });
  final ProductionOrder order;
  final bool canEdit;
  final bool canDelete;
  final bool canExec;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(productionRepositoryProvider);
    final bomAsync = order.productId == null
        ? const AsyncValue.data(<dynamic>[])
        : ref.watch(bomProvider(order.productId!));

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
                    child: Text(order.displayNumber,
                        style: theme.textTheme.headlineSmall),
                  ),
                  Chip(label: Text(order.status.label)),
                ],
              ),
              const SizedBox(height: 8),
              Text(order.productName ?? '—', style: theme.textTheme.titleMedium),
              Text('Quantità da produrre: ${Fmt.qty(order.quantity)}'),
              if (order.plannedDate != null)
                Text('Data prevista: ${Fmt.date(order.plannedDate)}'),
              if (order.completedAt != null)
                Text('Completato il ${Fmt.date(order.completedAt)}'),
              const Divider(height: 32),
              Text('Fabbisogno materiali', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              bomAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Errore distinta base: $e'),
                data: (components) {
                  if (components.isEmpty) {
                    return const Card(
                      color: Color(0x33FF9800),
                      child: ListTile(
                        leading: Icon(Icons.warning_amber),
                        title: Text('Nessuna distinta base'),
                        subtitle: Text(
                            'Definisci la distinta base del prodotto per poter '
                            'produrre.'),
                      ),
                    );
                  }
                  var feasible = true;
                  final rows = <Widget>[];
                  for (final c in components) {
                    final needed = c.quantity * order.quantity;
                    final ok = c.componentStock >= needed;
                    if (!ok) feasible = false;
                    rows.add(ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                          ok ? Icons.check_circle : Icons.error_outline,
                          color: ok ? Colors.green : theme.colorScheme.error),
                      title: Text(c.componentName),
                      subtitle: Text(
                          'Servono ${Fmt.qty(needed)} ${c.componentUnit} · '
                          'disponibili ${c.componentStock}'),
                    ));
                  }
                  return Column(children: [
                    ...rows,
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: feasible
                            ? Colors.green.withValues(alpha: 0.12)
                            : theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(feasible ? Icons.check : Icons.block,
                              color: feasible
                                  ? Colors.green
                                  : theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(feasible
                                ? 'Materiali sufficienti per la produzione'
                                : 'Materiali insufficienti'),
                          ),
                        ],
                      ),
                    ),
                  ]);
                },
              ),
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                const Divider(height: 32),
                Text('Note', style: theme.textTheme.titleMedium),
                Text(order.notes!),
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
                if (order.status == ProductionStatus.draft && canDelete)
                  OutlinedButton.icon(
                    onPressed: () => _delete(context, repo),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Elimina'),
                  ),
                if (order.status == ProductionStatus.draft && canEdit)
                  OutlinedButton.icon(
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifica'),
                  ),
                if (order.status == ProductionStatus.draft && canEdit)
                  FilledButton.icon(
                    onPressed: () => _confirm(context, repo),
                    icon: const Icon(Icons.check),
                    label: const Text('Conferma'),
                  ),
                if (order.status == ProductionStatus.confirmed && canExec)
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _mark(context, repo, ProductionStatus.inProgress),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Avvia'),
                  ),
                if ((order.status == ProductionStatus.confirmed ||
                        order.status == ProductionStatus.inProgress) &&
                    canExec)
                  FilledButton.icon(
                    onPressed: () => _complete(context, ref, repo),
                    icon: const Icon(Icons.task_alt),
                    label: const Text('Completa'),
                  ),
                if (!order.status.isClosed && canEdit)
                  OutlinedButton.icon(
                    onPressed: () =>
                        _mark(context, repo, ProductionStatus.cancelled),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Annulla'),
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
      MaterialPageRoute(
          builder: (_) => ProductionOrderFormPage(orderId: order.id)),
    );
    if (changed == true) onChanged();
  }

  Future<void> _confirm(BuildContext context, ProductionRepository repo) async {
    try {
      final n = await repo.confirm(order.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ordine confermato: $n')));
      }
      onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  Future<void> _mark(BuildContext context, ProductionRepository repo,
      ProductionStatus s) async {
    try {
      await repo.setStatus(order.id!, s);
      onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  Future<void> _complete(
      BuildContext context, WidgetRef ref, ProductionRepository repo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Completare la produzione?'),
        content: const Text(
            'I componenti verranno scaricati dal magazzino e la giacenza del '
            'prodotto finito aumentata. L\'operazione non è reversibile.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Completa')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.complete(order.id!);
      // Le giacenze sono cambiate: aggiorna magazzino e distinte basi.
      ref.invalidate(productsListProvider);
      onChanged();
      if (context.mounted) {
        _snack(context, 'Produzione completata.');
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  Future<void> _delete(BuildContext context, ProductionRepository repo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare l\'ordine?'),
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
      await repo.delete(order.id!);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
