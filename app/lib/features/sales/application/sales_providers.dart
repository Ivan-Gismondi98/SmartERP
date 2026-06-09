// ============================================================
//  SMARTERP · sales_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/sales_repository.dart';
import '../domain/sales_document.dart';

/// Elenco documenti di vendita dell'azienda corrente.
final salesListProvider = FutureProvider<List<SalesDocument>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <SalesDocument>[];
  return ref.watch(salesRepositoryProvider).list(companyId);
});

/// Dettaglio singolo documento (con righe).
final salesDetailProvider =
    FutureProvider.family<SalesDocument, String>((ref, id) async {
  return ref.watch(salesRepositoryProvider).getById(id);
});
