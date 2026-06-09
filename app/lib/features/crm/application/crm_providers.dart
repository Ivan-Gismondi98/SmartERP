// ============================================================
//  SMARTERP · crm_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/crm_repository.dart';
import '../domain/opportunity.dart';

/// Elenco opportunità dell'azienda corrente.
final opportunitiesListProvider =
    FutureProvider<List<Opportunity>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <Opportunity>[];
  return ref.watch(crmRepositoryProvider).list(companyId);
});

/// Dettaglio singola opportunità.
final opportunityDetailProvider =
    FutureProvider.family<Opportunity, String>((ref, id) async {
  return ref.watch(crmRepositoryProvider).getById(id);
});
