// ============================================================
//  SMARTERP · direct_thread.dart — canale di supporto (DM) e messaggi.
// ============================================================
class DirectThread {
  const DirectThread({
    required this.id,
    this.companyId,
    required this.kind, // user_admin | admin_dev
    required this.ownerId,
  });

  final String id;
  final String? companyId;
  final String kind;
  final String ownerId;

  factory DirectThread.fromJson(Map<String, dynamic> j) => DirectThread(
        id: j['id'] as String,
        companyId: j['company_id'] as String?,
        kind: j['kind'] as String,
        ownerId: j['owner_id'] as String,
      );
}

/// Voce della lista "Supporto" con titolo già risolto.
class SupportEntry {
  const SupportEntry({required this.thread, required this.title, this.isMine = false});
  final DirectThread thread;
  final String title;
  final bool isMine;
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    this.content,
    this.attachmentUrl,
    this.attachmentName,
    required this.createdAt,
  });

  final String id;
  final String threadId;
  final String senderId;
  final String? content;
  final String? attachmentUrl;
  final String? attachmentName;
  final DateTime createdAt;

  bool get isImage {
    final n = (attachmentName ?? attachmentUrl ?? '').toLowerCase();
    return n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.gif') ||
        n.endsWith('.webp');
  }

  factory DirectMessage.fromJson(Map<String, dynamic> j) => DirectMessage(
        id: j['id'] as String,
        threadId: j['thread_id'] as String,
        senderId: j['sender_id'] as String,
        content: j['content'] as String?,
        attachmentUrl: j['attachment_url'] as String?,
        attachmentName: j['attachment_name'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
