// ============================================================
//  SMARTERP · purchases_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/purchases_repository.dart';
import '../domain/purchase_document.dart';

final purchasesListProvider =
    FutureProvider<List<PurchaseDocument>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <PurchaseDocument>[];
  return ref.watch(purchasesRepositoryProvider).list(companyId);
});

final purchaseDetailProvider =
    FutureProvider.family<PurchaseDocument, String>((ref, id) async {
  return ref.watch(purchasesRepositoryProvider).getById(id);
});
