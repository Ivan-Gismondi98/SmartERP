// ============================================================
//  SMARTERP · products_repository.dart — CRUD prodotti + giacenze.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/bom_component.dart';
import '../domain/product.dart';

const _select = 'id, company_id, sku, name, description, unit_price, vat_rate, '
    'unit, is_composable, inventory ( quantity, reorder_level, warehouse_location )';

class ProductsRepository {
  ProductsRepository(this._client);
  final SupabaseClient _client;

  Future<List<Product>> list(String companyId) async {
    final rows = await _client
        .from('products')
        .select(_select)
        .eq('company_id', companyId)
        .order('name');
    return rows.map(Product.fromJson).toList();
  }

  Future<String> create(String companyId, Product p) async {
    final row = await _client
        .from('products')
        .insert({...p.productJson(), 'company_id': companyId})
        .select('id')
        .single();
    final productId = row['id'] as String;
    await _client.from('inventory').insert({
      ...p.inventoryJson(),
      'company_id': companyId,
      'product_id': productId,
    });
    return productId;
  }

  Future<void> update(Product p) async {
    await _client.from('products').update(p.productJson()).eq('id', p.id);
    // La giacenza ha unique(product_id): upsert sul prodotto.
    await _client.from('inventory').upsert(
      {
        ...p.inventoryJson(),
        'company_id': p.companyId,
        'product_id': p.id,
      },
      onConflict: 'product_id',
    );
  }

  Future<void> delete(String id) async {
    // inventory ha FK on delete cascade verso products.
    await _client.from('products').delete().eq('id', id);
  }

  // ---------- Distinta base (BOM) ----------

  /// Componenti della distinta base di [productId], con nome e giacenza.
  Future<List<BomComponent>> getBom(String productId) async {
    final rows = await _client
        .from('bom_components')
        .select('id, component_id, quantity, note, '
            'products!bom_components_component_id_fkey '
            '( name, unit, inventory ( quantity ) )')
        .eq('product_id', productId);
    return rows.map(BomComponent.fromJson).toList();
  }

  /// Sostituisce l'intera distinta base del prodotto.
  Future<void> replaceBom(
      String companyId, String productId, List<BomComponent> components) async {
    await _client.from('bom_components').delete().eq('product_id', productId);
    final valid = components.where((c) => c.componentId.isNotEmpty).toList();
    if (valid.isEmpty) return;
    await _client.from('bom_components').insert(
          valid.map((c) => c.toJson(companyId, productId)).toList(),
        );
  }

  /// Produce [qty] unita' del prodotto: consuma i componenti e incrementa
  /// la giacenza del finito (RPC atomica lato DB).
  Future<void> produce(String productId, double qty) async {
    await _client.rpc('produce_product',
        params: {'p_product_id': productId, 'p_qty': qty});
  }
}

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(ref.watch(supabaseClientProvider));
});
