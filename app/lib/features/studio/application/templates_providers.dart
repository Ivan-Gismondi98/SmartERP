// ============================================================
//  SMARTERP · templates_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/templates_repository.dart';
import '../domain/document_template.dart';

/// Modelli documento dell'azienda corrente.
final templatesListProvider = FutureProvider<List<DocumentTemplate>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <DocumentTemplate>[];
  return ref.watch(templatesRepositoryProvider).list(companyId);
});

/// Singolo modello per id (per applicarlo al PDF).
final templateByIdProvider =
    FutureProvider.family<DocumentTemplate?, String>((ref, id) async {
  return ref.watch(templatesRepositoryProvider).getById(id);
});
