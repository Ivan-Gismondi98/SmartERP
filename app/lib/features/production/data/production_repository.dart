// ============================================================
//  SMARTERP · production_repository.dart — CRUD ordini di produzione
//  + numerazione e completamento (RPC atomica di consumo materiali).
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/production_order.dart';

const _select =
    'id, company_id, product_id, quantity, status, order_number, '
    'numbering_year, numbering_seq, planned_date, started_at, completed_at, '
    'notes, products ( name )';

class ProductionRepository {
  ProductionRepository(this._client);
  final SupabaseClient _client;

  Future<List<ProductionOrder>> list(String companyId) async {
    final rows = await _client
        .from('production_orders')
        .select(_select)
        .eq('company_id', companyId)
        .order('planned_date', ascending: false, nullsFirst: false)
        .order('created_at', ascending: false);
    return rows.map(ProductionOrder.fromJson).toList();
  }

  Future<ProductionOrder> getById(String id) async {
    final row = await _client
        .from('production_orders')
        .select(_select)
        .eq('id', id)
        .single();
    return ProductionOrder.fromJson(row);
  }

  Future<String> create(ProductionOrder o) async {
    final row = await _client
        .from('production_orders')
        .insert(o.toJson())
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> update(ProductionOrder o) async {
    await _client.from('production_orders').update(o.toJson()).eq('id', o.id!);
  }

  Future<void> setStatus(String id, ProductionStatus status) async {
    final patch = <String, dynamic>{'status': status.db};
    if (status == ProductionStatus.inProgress) {
      patch['started_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await _client.from('production_orders').update(patch).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('production_orders').delete().eq('id', id);
  }

  /// Conferma: assegna il numero progressivo (OP n/anno).
  Future<String> confirm(String id) async {
    await setStatus(id, ProductionStatus.confirmed);
    final n = await _client
        .rpc('assign_production_number', params: {'p_order_id': id});
    return n as String;
  }

  /// Completa l'ordine: consuma i componenti e incrementa il finito (RPC).
  Future<void> complete(String id) async {
    await _client
        .rpc('complete_production_order', params: {'p_order_id': id});
  }
}

final productionRepositoryProvider = Provider<ProductionRepository>((ref) {
  return ProductionRepository(ref.watch(dataClientProvider));
});
