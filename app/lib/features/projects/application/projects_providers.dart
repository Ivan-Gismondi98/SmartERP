// ============================================================
//  SMARTERP · projects_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/projects_repository.dart';
import '../domain/project.dart';

final projectsListProvider = FutureProvider<List<Project>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <Project>[];
  return ref.watch(projectsRepositoryProvider).list(companyId);
});

final projectDetailProvider =
    FutureProvider.family<Project, String>((ref, id) async {
  return ref.watch(projectsRepositoryProvider).getById(id);
});
