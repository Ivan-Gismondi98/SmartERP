// ============================================================
//  SMARTERP · production_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/application/products_providers.dart';
import '../../products/domain/product.dart';
import '../../profile/application/profile_providers.dart';
import '../data/production_repository.dart';
import '../domain/production_order.dart';

final productionOrdersProvider =
    FutureProvider<List<ProductionOrder>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <ProductionOrder>[];
  return ref.watch(productionRepositoryProvider).list(companyId);
});

final productionOrderDetailProvider =
    FutureProvider.family<ProductionOrder, String>((ref, id) async {
  return ref.watch(productionRepositoryProvider).getById(id);
});

/// Prodotti componibili (con distinta base) selezionabili in produzione.
final composableProductsProvider = FutureProvider<List<Product>>((ref) async {
  final products = await ref.watch(productsListProvider.future);
  return products.where((p) => p.isComposable).toList();
});
