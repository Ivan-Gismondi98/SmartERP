// ============================================================
//  SMARTERP · support_page.dart — canale Supporto (DM dedicato).
//  Dipendente↔Amministratore, Amministratore↔Sviluppatore.
//  Sempre presente e NON cancellabile.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/support_repository.dart';
import 'support_thread_page.dart';

class SupportPage extends ConsumerWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(supportInboxProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supporto'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(supportInboxProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
                child: Text('Nessuna conversazione di supporto.'));
          }
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = entries[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Icon(e.thread.kind == 'admin_dev'
                      ? Icons.support_agent_outlined
                      : Icons.person_outline),
                ),
                title: Text(e.title),
                subtitle: Text(e.isMine
                    ? 'La tua chat di supporto (sempre attiva)'
                    : (e.thread.kind == 'admin_dev'
                        ? 'Richiesta da un amministratore'
                        : 'Richiesta da un dipendente')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SupportThreadPage(
                        threadId: e.thread.id, title: e.title))),
              );
            },
          );
        },
      ),
    );
  }
}
