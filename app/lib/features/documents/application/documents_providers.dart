// ============================================================
//  SMARTERP · documents_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/documents_repository.dart';
import '../domain/document_file.dart';

final documentsListProvider = FutureProvider<List<DocumentFile>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <DocumentFile>[];
  return ref.watch(documentsRepositoryProvider).list(companyId);
});
