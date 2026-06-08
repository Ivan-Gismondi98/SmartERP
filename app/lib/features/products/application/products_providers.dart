// ============================================================
//  SMARTERP · products_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/products_repository.dart';
import '../domain/bom_component.dart';
import '../domain/product.dart';

/// Prodotti (con giacenza) dell'azienda corrente.
final productsListProvider = FutureProvider<List<Product>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <Product>[];
  return ref.watch(productsRepositoryProvider).list(companyId);
});

/// Distinta base di un prodotto.
final bomProvider =
    FutureProvider.family<List<BomComponent>, String>((ref, productId) async {
  return ref.watch(productsRepositoryProvider).getBom(productId);
});
