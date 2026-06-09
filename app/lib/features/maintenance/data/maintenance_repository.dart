// ============================================================
//  SMARTERP · maintenance_repository.dart — CRUD attrezzature e richieste.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/equipment.dart';
import '../domain/maintenance_request.dart';

const _equipSelect =
    'id, company_id, name, code, category, location, status, purchase_date, '
    'last_service, next_service, notes';

const _reqSelect =
    'id, company_id, equipment_id, title, description, request_type, priority, '
    'status, requested_by, assigned_to, scheduled_date, completed_at, cost, '
    'notes, maintenance_equipment ( name )';

class MaintenanceRepository {
  MaintenanceRepository(this._client);
  final SupabaseClient _client;

  // ---------------- Attrezzature ----------------
  Future<List<Equipment>> listEquipment(String companyId) async {
    final rows = await _client
        .from('maintenance_equipment')
        .select(_equipSelect)
        .eq('company_id', companyId)
        .order('name');
    return rows.map(Equipment.fromJson).toList();
  }

  Future<void> createEquipment(Equipment e) async {
    await _client.from('maintenance_equipment').insert(e.toJson());
  }

  Future<void> updateEquipment(Equipment e) async {
    await _client
        .from('maintenance_equipment')
        .update(e.toJson())
        .eq('id', e.id!);
  }

  Future<void> deleteEquipment(String id) async {
    await _client.from('maintenance_equipment').delete().eq('id', id);
  }

  // ---------------- Richieste ----------------
  Future<List<MaintenanceRequest>> listRequests(String companyId) async {
    final rows = await _client
        .from('maintenance_requests')
        .select(_reqSelect)
        .eq('company_id', companyId)
        .order('scheduled_date', ascending: true, nullsFirst: false)
        .order('created_at', ascending: false);
    return rows.map(MaintenanceRequest.fromJson).toList();
  }

  Future<MaintenanceRequest> getRequest(String id) async {
    final row = await _client
        .from('maintenance_requests')
        .select(_reqSelect)
        .eq('id', id)
        .single();
    return MaintenanceRequest.fromJson(row);
  }

  Future<String> createRequest(MaintenanceRequest r) async {
    final row = await _client
        .from('maintenance_requests')
        .insert(r.toJson())
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> updateRequest(MaintenanceRequest r) async {
    await _client
        .from('maintenance_requests')
        .update(r.toJson())
        .eq('id', r.id!);
  }

  Future<void> setStatus(String id, MaintenanceStatus status) async {
    final patch = <String, dynamic>{'status': status.db};
    if (status == MaintenanceStatus.done) {
      patch['completed_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await _client.from('maintenance_requests').update(patch).eq('id', id);
  }

  Future<void> deleteRequest(String id) async {
    await _client.from('maintenance_requests').delete().eq('id', id);
  }
}

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  return MaintenanceRepository(ref.watch(dataClientProvider));
});
