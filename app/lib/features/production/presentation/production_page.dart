// ============================================================
//  SMARTERP · production_page.dart — hub Produzione a schede:
//  Ordini di produzione · Distinte basi.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../../core/reporting/entity_report_page.dart';
import '../../products/application/products_providers.dart';
import '../application/production_providers.dart';
import '../application/production_report.dart';
import '../domain/production_order.dart';
import 'bom_editor_page.dart';
import 'production_order_detail_page.dart';
import 'production_order_form_page.dart';

class ProductionPage extends ConsumerStatefulWidget {
  const ProductionPage({super.key});

  @override
  ConsumerState<ProductionPage> createState() => _ProductionPageState();
}

class _ProductionPageState extends ConsumerState<ProductionPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(canProvider(Perm.productionCreate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produzione'),
        actions: [
          IconButton(
            tooltip: 'Report / Export',
            icon: const Icon(Icons.assessment_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => EntityReportPage<ProductionOrder>(
                    spec: productionReportSpec))),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Ordini'),
            Tab(text: 'Distinte basi'),
          ],
        ),
      ),
      floatingActionButton: (_tab.index == 0 && canCreate)
          ? FloatingActionButton.extended(
              onPressed: () => _openOrder(null),
              icon: const Icon(Icons.add),
              label: const Text('Ordine'),
            )
          : null,
      body: TabBarView(
        controller: _tab,
        children: const [
          _OrdersTab(),
          _BomTab(),
        ],
      ),
    );
  }

  Future<void> _openOrder(String? id) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductionOrderFormPage(orderId: id)),
    );
    if (changed == true) ref.invalidate(productionOrdersProvider);
  }
}

// ============================================================
//  TAB — Ordini di produzione
// ============================================================
class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productionOrdersProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore: $e')),
      data: (orders) {
        if (orders.isEmpty) {
          return const Center(child: Text('Nessun ordine di produzione.'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(productionOrdersProvider),
          child: ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final o = orders[i];
              return ListTile(
                leading: _StatusBadge(status: o.status),
                title: Text(
                    '${o.displayNumber} · ${o.productName ?? 'Prodotto'}',
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    'Qtà ${Fmt.qty(o.quantity)}'
                    '${o.plannedDate != null ? '  ·  ${Fmt.date(o.plannedDate)}' : ''}'),
                trailing: Text(o.status.label,
                    style: Theme.of(context).textTheme.bodySmall),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          ProductionOrderDetailPage(orderId: o.id!)));
                  ref.invalidate(productionOrdersProvider);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ProductionStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (status) {
      ProductionStatus.draft => (scheme.outline, Icons.edit_note),
      ProductionStatus.confirmed => (scheme.primary, Icons.check),
      ProductionStatus.inProgress => (Colors.orange, Icons.build_circle_outlined),
      ProductionStatus.done => (Colors.green, Icons.task_alt),
      ProductionStatus.cancelled => (scheme.error, Icons.cancel_outlined),
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color),
    );
  }
}

// ============================================================
//  TAB — Distinte basi (prodotti componibili)
// ============================================================
class _BomTab extends ConsumerWidget {
  const _BomTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(composableProductsProvider);
    final canBom = ref.watch(canProvider(Perm.productionBom));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore: $e')),
      data: (products) {
        if (products.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'Nessun prodotto componibile.\n'
                  'Imposta un prodotto come "componibile" nel Magazzino per '
                  'definirne la distinta base.',
                  textAlign: TextAlign.center),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(productsListProvider);
            ref.invalidate(composableProductsProvider);
          },
          child: ListView.separated(
            itemCount: products.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = products[i];
              return ListTile(
                leading: const Icon(Icons.account_tree_outlined),
                title: Text(p.name),
                subtitle: Text('Giacenza ${p.quantity} ${p.unit}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BomEditorPage(
                        productId: p.id, productName: p.name, readOnly: !canBom),
                  ));
                  ref.invalidate(composableProductsProvider);
                },
              );
            },
          ),
        );
      },
    );
  }
}
