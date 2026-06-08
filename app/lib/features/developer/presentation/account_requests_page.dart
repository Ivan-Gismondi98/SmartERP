// ============================================================
//  SMARTERP · account_requests_page.dart — richieste di account (super).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/account_requests_repository.dart';
import 'users_page.dart';

class AccountRequestsPage extends ConsumerWidget {
  const AccountRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountRequestsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Richieste account'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(accountRequestsListProvider),
          ),
          IconButton(
            tooltip: 'Crea utente',
            icon: const Icon(Icons.person_add_alt),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UsersPage())),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (reqs) {
          if (reqs.isEmpty) {
            return const Center(child: Text('Nessuna richiesta.'));
          }
          return ListView.separated(
            itemCount: reqs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = reqs[i];
              final when =
                  DateFormat('dd/MM/yyyy HH:mm').format(r.createdAt.toLocal());
              final color = switch (r.status) {
                'handled' => Colors.green,
                'rejected' => Colors.grey,
                _ => Colors.orange,
              };
              return ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(Icons.mail_outline, color: color),
                ),
                title: Text(r.name?.isNotEmpty == true ? r.name! : r.email),
                subtitle: Text(
                    '${r.email}${r.organization != null ? ' · ${r.organization}' : ''} · $when · ${r.status}'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  if (r.message != null)
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text(r.message!)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const UsersPage())),
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Crea utente'),
                      ),
                      if (r.status != 'handled')
                        OutlinedButton(
                          onPressed: () => _set(ref, r.id, 'handled'),
                          child: const Text('Segna gestita'),
                        ),
                      if (r.status != 'rejected')
                        OutlinedButton(
                          onPressed: () => _set(ref, r.id, 'rejected'),
                          child: const Text('Rifiuta'),
                        ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _set(WidgetRef ref, String id, String status) async {
    await ref.read(accountRequestsRepositoryProvider).setStatus(id, status);
    ref.invalidate(accountRequestsListProvider);
  }
}
