// ============================================================
//  SMARTERP · assistant_bar.dart — barra "Assistente IA" in fondo a
//  ogni pagina (se la licenza dell'app è attiva). Apre un pannello chat
//  la cui conversazione persiste tra un'app e l'altra.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/licensing.dart';
import '../../profile/application/profile_providers.dart';
import '../application/assistant_controller.dart';

class AssistantBar extends ConsumerWidget {
  const AssistantBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final licensed = ref.watch(licensedAppsProvider).valueOrNull ?? const {};
    // Visibile solo se autenticato e con licenza "assistant" attiva.
    if (profile == null || !licensed.contains('assistant')) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: () => _open(context),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.smart_toy_outlined,
                    color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Assistente IA — chiedimi come usare l\'app',
                      style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer)),
                ),
                Icon(Icons.keyboard_arrow_up,
                    color: theme.colorScheme.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final path = GoRouter.of(context).routeInformationProvider.value.uri.path;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AssistantPanel(currentPath: path),
    );
  }
}

class _AssistantPanel extends ConsumerStatefulWidget {
  const _AssistantPanel({required this.currentPath});
  final String currentPath;

  @override
  ConsumerState<_AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends ConsumerState<_AssistantPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final q = _input.text.trim();
    if (q.isEmpty) return;
    _input.clear();
    await ref
        .read(assistantControllerProvider.notifier)
        .ask(q, currentPath: widget.currentPath);
    await Future.delayed(const Duration(milliseconds: 50));
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantControllerProvider);
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: const Text('Assistente IA'),
              subtitle: Text('Sei in: ${appFromPath(widget.currentPath)}'),
              trailing: IconButton(
                tooltip: 'Pulisci conversazione',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () =>
                    ref.read(assistantControllerProvider.notifier).reset(),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: state.messages.isEmpty
                  ? _Suggestions(onTap: (s) {
                      _input.text = s;
                      _send();
                    })
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: state.messages.length,
                      itemBuilder: (context, i) {
                        final m = state.messages[i];
                        return Align(
                          alignment: m.fromUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(10),
                            constraints:
                                const BoxConstraints(maxWidth: 460),
                            decoration: BoxDecoration(
                              color: m.fromUser
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(m.text),
                          ),
                        );
                      },
                    ),
            ),
            if (state.thinking)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Row(children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Sto cercando…'),
                ]),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Es. "come creo una fattura?"',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                      onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onTap});
  final ValueChanged<String> onTap;

  static const _items = [
    'Come creo la mia prima fattura?',
    'Come carico il magazzino?',
    'Come emetto una fattura?',
    'Come funziona la distinta base?',
    'Come esporto l\'XML per lo SdI?',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Ciao! Chiedimi come funziona una pagina o un\'operazione.',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        for (final s in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ActionChip(label: Text(s), onPressed: () => onTap(s)),
          ),
      ],
    );
  }
}
