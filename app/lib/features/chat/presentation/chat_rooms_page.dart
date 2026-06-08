// ============================================================
//  SMARTERP · chat_rooms_page.dart — elenco stanze chat.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../application/chat_providers.dart';
import '../data/chat_repository.dart';
import 'chat_room_page.dart';

class ChatRoomsPage extends ConsumerWidget {
  const ChatRoomsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(canProvider(Perm.chatManage));
    final roomsAsync = ref.watch(chatRoomsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _createRoom(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nuova stanza'),
            )
          : null,
      body: roomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (rooms) {
          if (rooms.isEmpty) {
            return const Center(child: Text('Nessuna stanza chat.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(chatRoomsProvider),
            child: ListView.separated(
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = rooms[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.forum_outlined)),
                  title: Text(r.displayName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChatRoomPage(room: r))),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _createRoom(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuova stanza'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome stanza'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Crea')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final profile = await ref.read(currentProfileProvider.future);
    if (profile?.companyId == null) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .createRoom(profile!.companyId!, profile.id, name);
      ref.invalidate(chatRoomsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }
}
