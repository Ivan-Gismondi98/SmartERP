// ============================================================
//  SMARTERP · chat_room_page.dart — stanza chat realtime.
//  Messaggi in streaming + invio. Videochiamata Jitsi opzionale
//  (mostrata solo se abilitata dalle impostazioni e con permesso).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../application/chat_providers.dart';
import '../data/chat_repository.dart';
import '../domain/chat.dart';

class ChatRoomPage extends ConsumerStatefulWidget {
  const ChatRoomPage({super.key, required this.room});
  final ChatRoom room;

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? overrideText]) async {
    final text = (overrideText ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(widget.room.id, profile.id, text);
      if (overrideText == null) _input.clear();
      ref.invalidate(messagesFutureProvider(widget.room.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore invio: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startVideoCall() async {
    // Stanza Jitsi deterministica per questa chat-room.
    final url = 'https://meet.jit.si/SmartERP-${widget.room.id}';
    // Condivide il link nel canale così gli altri possono unirsi.
    await _send('📹 Videochiamata avviata: $url');
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossibile aprire la videochiamata.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = ref.watch(canProvider(Perm.chatSend));
    final canVideo = ref.watch(canProvider(Perm.chatVideo));
    final videoEnabled =
        ref.watch(boolSettingProvider((scope: 'chat', key: 'video_enabled')))
                .valueOrNull ??
            false;
    final messagesAsync = ref.watch(messagesFutureProvider(widget.room.id));
    final names = ref.watch(profileNamesProvider).valueOrNull ?? const {};
    final myId = ref.watch(currentProfileProvider).valueOrNull?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.displayName),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(messagesFutureProvider(widget.room.id)),
          ),
          if (videoEnabled && canVideo)
            IconButton(
              tooltip: 'Videochiamata',
              icon: const Icon(Icons.videocam_outlined),
              onPressed: _startVideoCall,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Errore: $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('Nessun messaggio.'));
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _Bubble(
                    message: messages[i],
                    mine: messages[i].senderId == myId,
                    senderName: names[messages[i].senderId] ?? 'Utente',
                  ),
                );
              },
            ),
          ),
          if (canSend)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Scrivi un messaggio…',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : () => _send(),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(
      {required this.message, required this.mine, required this.senderName});
  final ChatMessage message;
  final bool mine;
  final String senderName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateFormat('HH:mm').format(message.createdAt.toLocal());
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: mine
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(senderName,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            Text(message.content),
            Text(time,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
