// ============================================================
//  SMARTERP · tickets_repository.dart — segnalazioni/ticket + realtime.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/ticket.dart';

class TicketsRepository {
  TicketsRepository(this._client);
  final SupabaseClient _client;

  static const _select =
      'id, company_id, title, description, status, priority, target, '
      'error_log_id, created_by, created_at, companies ( name )';

  Future<List<Ticket>> list() async {
    final rows = await _client
        .from('tickets')
        .select(_select)
        .order('created_at', ascending: false);
    return rows.map(Ticket.fromJson).toList();
  }

  /// Stream realtime dei ticket visibili (RLS applica lo scope).
  Stream<List<Ticket>> stream() {
    return _client
        .from('tickets')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows.map(Ticket.fromJson).toList());
  }

  /// Crea una segnalazione a partire da un errore.
  Future<void> createFromError({
    required String title,
    String? description,
    required String target, // 'admin' | 'developer'
    required String priority,
    String? companyId,
    String? errorLogId,
  }) async {
    await _client.from('tickets').insert({
      'title': title.length > 200 ? title.substring(0, 200) : title,
      'description': description,
      'target': target,
      'priority': priority,
      'company_id': companyId,
      'error_log_id': errorLogId,
      'created_by': _client.auth.currentUser?.id,
      'status': 'open',
    });
  }

  Future<void> setStatus(String id, String status) async {
    await _client.from('tickets').update({'status': status}).eq('id', id);
  }
}

final ticketsRepositoryProvider = Provider<TicketsRepository>((ref) {
  return TicketsRepository(ref.watch(supabaseClientProvider));
});

/// Stream realtime (per notifiche live + lista che si aggiorna da sola).
final ticketsStreamProvider = StreamProvider<List<Ticket>>((ref) {
  return ref.watch(ticketsRepositoryProvider).stream();
});

/// Conteggio ticket "aperti" rilevanti, per il badge di notifica.
final openTicketsCountProvider = Provider<int>((ref) {
  final tickets = ref.watch(ticketsStreamProvider).valueOrNull ?? const [];
  return tickets.where((t) => t.status == 'open').length;
});
