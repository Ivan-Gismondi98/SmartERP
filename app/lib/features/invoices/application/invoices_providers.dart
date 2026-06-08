// ============================================================
//  SMARTERP · invoices_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/invoices_repository.dart';
import '../domain/invoice.dart';

/// Elenco fatture dell'azienda corrente.
final invoicesListProvider = FutureProvider<List<Invoice>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <Invoice>[];
  return ref.watch(invoicesRepositoryProvider).list(companyId);
});

/// Dettaglio singola fattura (con righe).
final invoiceDetailProvider =
    FutureProvider.family<Invoice, String>((ref, id) async {
  return ref.watch(invoicesRepositoryProvider).getById(id);
});
