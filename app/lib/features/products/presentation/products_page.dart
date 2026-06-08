// ============================================================
//  SMARTERP · products_page.dart — magazzino/prodotti con giacenze.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../application/products_providers.dart';
import '../data/products_repository.dart';
import '../domain/product.dart';
import 'product_form_page.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  String _query = '';
  bool _onlyLow = false;

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(canProvider(Perm.productsCreate));
    final canEdit = ref.watch(canProvider(Perm.productsEdit));
    final canDelete = ref.watch(canProvider(Perm.productsDelete));
    final listAsync = ref.watch(productsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Magazzino / Prodotti')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(null),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo prodotto'),
            )
          : null,
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (all) {
          final q = _query.trim().toLowerCase();
          var items = all.where((p) {
            if (_onlyLow && !p.belowReorder) return false;
            if (q.isEmpty) return true;
            return '${p.name} ${p.sku ?? ''}'.toLowerCase().contains(q);
          }).toList();
          final lowCount = all.where((p) => p.belowReorder).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Cerca per nome o SKU',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('Sotto scorta ($lowCount)'),
                      selected: _onlyLow,
                      onSelected: (v) => setState(() => _onlyLow = v),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Nessun prodotto.'))
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(productsListProvider),
                        child: ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final p = items[i];
                            return ListTile(
                              leading: _StockBadge(product: p),
                              title: Text(p.name),
                              subtitle: Text([
                                if (p.sku != null) 'SKU ${p.sku}',
                                '${Fmt.euro(p.unitPrice)} · IVA ${Fmt.percent(p.vatRate)}',
                              ].join(' · ')),
                              trailing: canDelete
                                  ? IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _confirmDelete(p),
                                    )
                                  : null,
                              onTap: canEdit ? () => _openForm(p) : null,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openForm(Product? existing) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormPage(product: existing)),
    );
    if (saved == true) ref.invalidate(productsListProvider);
  }

  Future<void> _confirmDelete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare il prodotto?'),
        content: Text('"${p.name}" e la sua giacenza verranno eliminati.'),
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
      await ref.read(productsRepositoryProvider).delete(p.id);
      ref.invalidate(productsListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final low = product.belowReorder;
    final color = low ? Colors.orange : Colors.green;
    return Tooltip(
      message: low
          ? 'Sotto scorta (min ${product.reorderLevel})'
          : 'Giacenza ok',
      child: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Text('${product.quantity}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
