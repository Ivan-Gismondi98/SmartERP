// ============================================================
//  SMARTERP · account_requests_repository.dart
//  Invio richieste account (anche da non autenticati) + gestione (super).
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';

class AccountRequest {
  const AccountRequest({
    required this.id,
    this.name,
    required this.email,
    this.organization,
    this.message,
    this.status = 'new',
    required this.createdAt,
  });
  final String id;
  final String? name;
  final String email;
  final String? organization;
  final String? message;
  final String status;
  final DateTime createdAt;

  factory AccountRequest.fromJson(Map<String, dynamic> j) => AccountRequest(
        id: j['id'] as String,
        name: j['requester_name'] as String?,
        email: (j['requester_email'] as String?) ?? '',
        organization: j['organization'] as String?,
        message: j['message'] as String?,
        status: (j['status'] as String?) ?? 'new',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class AccountRequestsRepository {
  AccountRequestsRepository(this._client);
  final SupabaseClient _client;

  /// Invia una richiesta (usabile anche senza login → ruolo anon).
  Future<void> submit({
    required String email,
    String? name,
    String? organization,
    String? message,
  }) async {
    await _client.from('account_requests').insert({
      'requester_email': email.trim(),
      'requester_name': (name == null || name.trim().isEmpty) ? null : name.trim(),
      'organization':
          (organization == null || organization.trim().isEmpty) ? null : organization.trim(),
      'message': (message == null || message.trim().isEmpty) ? null : message.trim(),
    });
  }

  Future<List<AccountRequest>> list() async {
    final rows = await _client
        .from('account_requests')
        .select('id, requester_name, requester_email, organization, message, status, created_at')
        .order('created_at', ascending: false);
    return rows.map(AccountRequest.fromJson).toList();
  }

  Future<void> setStatus(String id, String status) async {
    await _client.from('account_requests').update({'status': status}).eq('id', id);
  }
}

final accountRequestsRepositoryProvider =
    Provider<AccountRequestsRepository>((ref) {
  return AccountRequestsRepository(ref.watch(supabaseClientProvider));
});

final accountRequestsListProvider =
    FutureProvider<List<AccountRequest>>((ref) async {
  return ref.watch(accountRequestsRepositoryProvider).list();
});
