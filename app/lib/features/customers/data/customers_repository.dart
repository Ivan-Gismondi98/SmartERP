// ============================================================
//  SMARTERP · customers_repository.dart
//  CRUD clienti, scoping per azienda (RLS lato DB lo rafforza).
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/customer.dart';

class CustomersRepository {
  CustomersRepository(this._client);
  final SupabaseClient _client;

  Future<List<Customer>> list(String companyId) async {
    final rows = await _client
        .from('customers')
        .select()
        .eq('company_id', companyId)
        .order('name');
    return rows.map(Customer.fromJson).toList();
  }

  Future<Customer> create(String companyId, Customer c) async {
    final row = await _client
        .from('customers')
        .insert({...c.toJson(), 'company_id': companyId})
        .select()
        .single();
    return Customer.fromJson(row);
  }

  Future<Customer> update(Customer c) async {
    final row = await _client
        .from('customers')
        .update(c.toJson())
        .eq('id', c.id)
        .select()
        .single();
    return Customer.fromJson(row);
  }

  Future<void> delete(String id) async {
    await _client.from('customers').delete().eq('id', id);
  }
}

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return CustomersRepository(ref.watch(dataClientProvider));
});
