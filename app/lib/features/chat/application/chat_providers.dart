// ============================================================
//  SMARTERP · chat_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/chat_repository.dart';
import '../domain/chat.dart';

/// Stanze chat dell'azienda corrente.
final chatRoomsProvider = FutureProvider<List<ChatRoom>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <ChatRoom>[];
  return ref.watch(chatRepositoryProvider).listRooms(companyId);
});

/// Mappa profileId -> nome per i mittenti dei messaggi.
final profileNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return {};
  return ref.watch(chatRepositoryProvider).profileNames(companyId);
});

/// Stream realtime dei messaggi di una stanza.
final messagesStreamProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, roomId) {
  return ref.watch(chatRepositoryProvider).messagesStream(roomId);
});
