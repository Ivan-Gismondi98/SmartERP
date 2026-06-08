// ============================================================
//  SMARTERP · tickets_repository.dart — segnalazioni/ticket + realtime.
// ============================================================
import 'dart:typed_data';

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

  // ----- Thread messaggi + allegati -----

  Future<List<TicketMessage>> messages(String ticketId) async {
    final rows = await _client
        .from('ticket_messages')
        .select('id, ticket_id, sender_id, content, attachment_url, attachment_name, created_at')
        .eq('ticket_id', ticketId)
        .order('created_at');
    return rows.map(TicketMessage.fromJson).toList();
  }

  Stream<List<TicketMessage>> messagesStream(String ticketId) {
    return _client
        .from('ticket_messages')
        .stream(primaryKey: ['id'])
        .eq('ticket_id', ticketId)
        .order('created_at')
        .map((rows) => rows.map(TicketMessage.fromJson).toList());
  }

  Future<void> sendMessage(String ticketId, String? content,
      {String? attachmentUrl, String? attachmentName}) async {
    await _client.from('ticket_messages').insert({
      'ticket_id': ticketId,
      'sender_id': _client.auth.currentUser?.id,
      'content': (content == null || content.trim().isEmpty) ? null : content.trim(),
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
    });
  }

  /// Carica un allegato nel bucket e ritorna l'URL pubblico.
  Future<String> uploadAttachment(
      String ticketId, List<int> bytes, String fileName, int stamp) async {
    final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = 'tickets/$ticketId/${stamp}_$safe';
    await _client.storage.from('ticket-attachments').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('ticket-attachments').getPublicUrl(path);
  }
}

final ticketsRepositoryProvider = Provider<TicketsRepository>((ref) {
  return TicketsRepository(ref.watch(supabaseClientProvider));
});

/// Lista ticket (fetch REST, robusta anche senza WebSocket Realtime).
final ticketsFutureProvider = FutureProvider<List<Ticket>>((ref) {
  return ref.watch(ticketsRepositoryProvider).list();
});

/// Conteggio ticket "aperti" rilevanti, per il badge di notifica.
final openTicketsCountProvider = Provider<int>((ref) {
  final tickets = ref.watch(ticketsFutureProvider).valueOrNull ?? const [];
  return tickets.where((t) => t.status == 'open').length;
});
