// ============================================================
//  SMARTERP · customers_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/customers_repository.dart';
import '../domain/customer.dart';

/// Lista clienti dell'azienda dell'utente loggato.
final customersListProvider = FutureProvider<List<Customer>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <Customer>[];
  return ref.watch(customersRepositoryProvider).list(companyId);
});
