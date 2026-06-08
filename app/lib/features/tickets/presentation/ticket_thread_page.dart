// ============================================================
//  SMARTERP · ticket_thread_page.dart — chat sul ticket con allegati.
//  Messaggi realtime tra admin e sviluppatore; immagini/file su Storage.
// ============================================================
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../profile/application/profile_providers.dart';
import '../data/tickets_repository.dart';
import '../domain/ticket.dart';

final _messagesProvider =
    FutureProvider.family<List<TicketMessage>, String>((ref, ticketId) {
  return ref.watch(ticketsRepositoryProvider).messages(ticketId);
});

class TicketThreadPage extends ConsumerStatefulWidget {
  const TicketThreadPage({super.key, required this.ticket});
  final Ticket ticket;

  @override
  ConsumerState<TicketThreadPage> createState() => _TicketThreadPageState();
}

class _TicketThreadPageState extends ConsumerState<TicketThreadPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;

  String get _ticketId => widget.ticket.id;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(ticketsRepositoryProvider).sendMessage(_ticketId, text);
      _input.clear();
      ref.invalidate(_messagesProvider(_ticketId));
    } catch (e) {
      _snack('Errore invio: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attach() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.bytes == null) {
      _snack('File non leggibile.');
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(ticketsRepositoryProvider);
      final url = await repo.uploadAttachment(
          _ticketId, f.bytes!, f.name, DateTime.now().millisecondsSinceEpoch);
      await repo.sendMessage(_ticketId, null,
          attachmentUrl: url, attachmentName: f.name);
      ref.invalidate(_messagesProvider(_ticketId));
    } catch (e) {
      _snack('Errore allegato: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_messagesProvider(_ticketId));
    final myId = ref.watch(currentProfileProvider).valueOrNull?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ticket.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_messagesProvider(_ticketId)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
                '${ticketStatusLabel(widget.ticket.status)} · ${ticketTargetLabel(widget.ticket.target)}',
                style: const TextStyle(fontSize: 12)),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Errore: $e')),
              data: (msgs) {
                if (msgs.isEmpty) {
                  return const Center(
                      child: Text('Nessun messaggio. Scrivi per iniziare.'));
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) =>
                      _Bubble(message: msgs[i], mine: msgs[i].senderId == myId),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Allega file/immagine',
                    onPressed: _busy ? null : _attach,
                    icon: const Icon(Icons.attach_file),
                  ),
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
                    onPressed: _busy ? null : _send,
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
  const _Bubble({required this.message, required this.mine});
  final TicketMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateFormat('dd/MM HH:mm').format(message.createdAt.toLocal());
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(maxWidth: 380),
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
            if (message.attachmentUrl != null) ...[
              if (message.isImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(message.attachmentUrl!,
                      height: 160, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Text('[immagine non disponibile]')),
                )
              else
                TextButton.icon(
                  onPressed: () =>
                      launchUrl(Uri.parse(message.attachmentUrl!),
                          mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.insert_drive_file_outlined),
                  label: Text(message.attachmentName ?? 'Allegato'),
                ),
            ],
            if (message.content != null) Text(message.content!),
            Text(time,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
