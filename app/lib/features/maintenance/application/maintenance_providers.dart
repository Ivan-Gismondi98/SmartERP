// ============================================================
//  SMARTERP · maintenance_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/maintenance_repository.dart';
import '../domain/equipment.dart';
import '../domain/maintenance_request.dart';

final equipmentListProvider = FutureProvider<List<Equipment>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <Equipment>[];
  return ref.watch(maintenanceRepositoryProvider).listEquipment(companyId);
});

final maintenanceRequestsProvider =
    FutureProvider<List<MaintenanceRequest>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <MaintenanceRequest>[];
  return ref.watch(maintenanceRepositoryProvider).listRequests(companyId);
});

final maintenanceRequestDetailProvider =
    FutureProvider.family<MaintenanceRequest, String>((ref, id) async {
  return ref.watch(maintenanceRepositoryProvider).getRequest(id);
});
