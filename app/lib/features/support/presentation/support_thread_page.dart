// ============================================================
//  SMARTERP · support_thread_page.dart — conversazione di supporto.
// ============================================================
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../profile/application/profile_providers.dart';
import '../data/support_repository.dart';

class SupportThreadPage extends ConsumerStatefulWidget {
  const SupportThreadPage({super.key, required this.threadId, required this.title});
  final String threadId;
  final String title;

  @override
  ConsumerState<SupportThreadPage> createState() => _SupportThreadPageState();
}

class _SupportThreadPageState extends ConsumerState<SupportThreadPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reload() => ref.invalidate(supportMessagesProvider(widget.threadId));

  Future<void> _send() async {
    final t = _input.text.trim();
    if (t.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(supportRepositoryProvider).sendMessage(widget.threadId, t);
      _input.clear();
      _reload();
    } catch (e) {
      _snack('Errore invio: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attach() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    final f = res.files.first;
    setState(() => _busy = true);
    try {
      final repo = ref.read(supportRepositoryProvider);
      final url = await repo.uploadAttachment(
          widget.threadId, f.bytes!, f.name, DateTime.now().millisecondsSinceEpoch);
      await repo.sendMessage(widget.threadId, null,
          attachmentUrl: url, attachmentName: f.name);
      _reload();
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
    final async = ref.watch(supportMessagesProvider(widget.threadId));
    final myId = ref.watch(currentProfileProvider).valueOrNull?.id;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
              tooltip: 'Aggiorna',
              icon: const Icon(Icons.refresh),
              onPressed: _reload),
        ],
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
                      child: Text('Scrivi il primo messaggio di supporto.'));
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
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final mine = m.senderId == myId;
                    final time =
                        DateFormat('dd/MM HH:mm').format(m.createdAt.toLocal());
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
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
                          crossAxisAlignment: mine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (m.attachmentUrl != null) ...[
                              if (m.isImage)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(m.attachmentUrl!,
                                      height: 160, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Text('[immagine]')),
                                )
                              else
                                TextButton.icon(
                                  onPressed: () => launchUrl(
                                      Uri.parse(m.attachmentUrl!),
                                      mode: LaunchMode.externalApplication),
                                  icon: const Icon(
                                      Icons.insert_drive_file_outlined),
                                  label: Text(m.attachmentName ?? 'Allegato'),
                                ),
                            ],
                            if (m.content != null) Text(m.content!),
                            Text(time,
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.outline)),
                          ],
                        ),
                      ),
                    );
                  },
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
                      tooltip: 'Allega',
                      onPressed: _busy ? null : _attach,
                      icon: const Icon(Icons.attach_file)),
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
                      icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
