// ============================================================
//  SMARTERP · chat_repository.dart — stanze, stream realtime, invio.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/chat.dart';

class ChatRepository {
  ChatRepository(this._client);
  final SupabaseClient _client;

  Future<List<ChatRoom>> listRooms(String companyId) async {
    final rows = await _client
        .from('chat_rooms')
        .select('id, company_id, name, is_group')
        .eq('company_id', companyId)
        .order('created_at');
    return rows.map(ChatRoom.fromJson).toList();
  }

  Future<ChatRoom> createRoom(
      String companyId, String createdBy, String name) async {
    final row = await _client
        .from('chat_rooms')
        .insert({
          'company_id': companyId,
          'name': name,
          'is_group': true,
          'created_by': createdBy,
        })
        .select('id, company_id, name, is_group')
        .single();
    final room = ChatRoom.fromJson(row);
    // Il creatore entra come partecipante.
    await _client.from('chat_participants').insert(
        {'room_id': room.id, 'profile_id': createdBy}).select().maybeSingle();
    return room;
  }

  /// Stream realtime dei messaggi di una stanza (ordine cronologico).
  Stream<List<ChatMessage>> messagesStream(String roomId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at')
        .map((rows) => rows.map(ChatMessage.fromJson).toList());
  }

  Future<void> sendMessage(
      String roomId, String senderId, String content) async {
    await _client.from('chat_messages').insert({
      'room_id': roomId,
      'sender_id': senderId,
      'content': content,
    });
  }

  /// Mappa profileId -> nome, per mostrare il mittente dei messaggi.
  Future<Map<String, String>> profileNames(String companyId) async {
    final rows = await _client
        .from('profiles')
        .select('id, full_name')
        .eq('company_id', companyId);
    return {
      for (final r in rows)
        r['id'] as String: (r['full_name'] as String?) ?? 'Utente'
    };
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseClientProvider));
});
