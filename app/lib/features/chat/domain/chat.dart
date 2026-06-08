// ============================================================
//  SMARTERP · chat.dart — modelli stanza e messaggio chat.
// ============================================================
class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.companyId,
    this.name,
    this.isGroup = true,
  });

  final String id;
  final String companyId;
  final String? name;
  final bool isGroup;

  String get displayName => (name == null || name!.trim().isEmpty)
      ? 'Stanza'
      : name!.trim();

  factory ChatRoom.fromJson(Map<String, dynamic> j) => ChatRoom(
        id: j['id'] as String,
        companyId: j['company_id'] as String,
        name: j['name'] as String?,
        isGroup: (j['is_group'] as bool?) ?? true,
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    this.attachmentUrl,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final String? attachmentUrl;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        roomId: j['room_id'] as String,
        senderId: j['sender_id'] as String,
        content: (j['content'] as String?) ?? '',
        attachmentUrl: j['attachment_url'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
