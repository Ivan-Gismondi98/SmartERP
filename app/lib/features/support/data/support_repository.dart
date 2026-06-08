// ============================================================
//  SMARTERP · support_repository.dart — canale Supporto (DM dedicato).
// ============================================================
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/profile.dart';
import '../domain/direct_thread.dart';

class SupportRepository {
  SupportRepository(this._client);
  final SupabaseClient _client;

  /// Garantisce che esista il canale dell'utente corrente e ne ritorna l'id.
  /// employee/customer -> 'user_admin'; admin -> 'admin_dev'; super -> null.
  Future<String?> ensureMyThread(UserRole role, String? companyId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    String? kind;
    if (role == UserRole.admin) {
      kind = 'admin_dev';
    } else if (role == UserRole.employee || role == UserRole.customer) {
      kind = 'user_admin';
    } else {
      return null; // super_admin: solo destinatario
    }
    final existing = await _client
        .from('direct_threads')
        .select('id')
        .eq('kind', kind)
        .eq('owner_id', uid)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;
    final row = await _client
        .from('direct_threads')
        .insert({'kind': kind, 'owner_id': uid, 'company_id': companyId})
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Inbox del Supporto, con titoli risolti in base al ruolo.
  Future<List<SupportEntry>> inbox(
      UserRole role, String? companyId, String myId) async {
    final rows = await _client
        .from('direct_threads')
        .select('id, company_id, kind, owner_id');
    final threads = rows.map(DirectThread.fromJson).toList();

    // Nomi proprietari + aziende (per i titoli).
    final ownerIds = threads.map((t) => t.ownerId).toSet().toList();
    final names = <String, String>{};
    if (ownerIds.isNotEmpty) {
      final profs = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', ownerIds);
      for (final p in profs) {
        names[p['id'] as String] = (p['full_name'] as String?) ?? 'Utente';
      }
    }
    final companyNames = <String, String>{};
    if (role == UserRole.superAdmin) {
      final comps = await _client.from('companies').select('id, name');
      for (final c in comps) {
        companyNames[c['id'] as String] = (c['name'] as String?) ?? '';
      }
    }

    final entries = <SupportEntry>[];
    for (final t in threads) {
      final mine = t.ownerId == myId;
      String title;
      if (mine) {
        title = t.kind == 'admin_dev' ? 'Sviluppatore' : 'Amministratore';
      } else {
        final name = names[t.ownerId] ?? 'Utente';
        title = t.kind == 'admin_dev'
            ? '$name${companyNames[t.companyId] != null ? ' · ${companyNames[t.companyId]}' : ''}'
            : name;
      }
      entries.add(SupportEntry(thread: t, title: title, isMine: mine));
    }
    // I "miei" canali in cima.
    entries.sort((a, b) => (b.isMine ? 1 : 0) - (a.isMine ? 1 : 0));
    return entries;
  }

  Future<List<DirectMessage>> messages(String threadId) async {
    final rows = await _client
        .from('direct_messages')
        .select('id, thread_id, sender_id, content, attachment_url, attachment_name, created_at')
        .eq('thread_id', threadId)
        .order('created_at');
    return rows.map(DirectMessage.fromJson).toList();
  }

  Future<void> sendMessage(String threadId, String? content,
      {String? attachmentUrl, String? attachmentName}) async {
    await _client.from('direct_messages').insert({
      'thread_id': threadId,
      'sender_id': _client.auth.currentUser?.id,
      'content': (content == null || content.trim().isEmpty) ? null : content.trim(),
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
    });
  }

  Future<String> uploadAttachment(
      String threadId, List<int> bytes, String fileName, int stamp) async {
    final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = 'support/$threadId/${stamp}_$safe';
    await _client.storage.from('ticket-attachments').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('ticket-attachments').getPublicUrl(path);
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(supabaseClientProvider));
});

/// Inbox del Supporto (fetch; assicura anche il proprio canale).
final supportInboxProvider = FutureProvider<List<SupportEntry>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return <SupportEntry>[];
  final repo = ref.watch(supportRepositoryProvider);
  await repo.ensureMyThread(profile.role, profile.companyId);
  return repo.inbox(profile.role, profile.companyId, profile.id);
});

final supportMessagesProvider =
    FutureProvider.family<List<DirectMessage>, String>((ref, threadId) {
  return ref.watch(supportRepositoryProvider).messages(threadId);
});
