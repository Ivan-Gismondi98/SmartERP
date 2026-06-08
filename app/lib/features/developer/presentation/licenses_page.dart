// ============================================================
//  SMARTERP · licenses_page.dart — gestione licenze e pagamenti (dev).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../application/developer_providers.dart';
import '../data/developer_repository.dart';
import '../domain/license.dart';
import 'license_form_page.dart';

class LicensesPage extends ConsumerWidget {
  const LicensesPage({super.key, this.companyId, this.companyName});

  /// Se valorizzato, mostra solo le licenze di quell'organizzazione.
  final String? companyId;
  final String? companyName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(licensesListProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
          title: Text(companyName != null ? 'Licenze · $companyName' : 'Licenze')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Nuova licenza'),
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (all) {
          final licenses = companyId == null
              ? all
              : all.where((l) => l.companyId == companyId).toList();
          if (licenses.isEmpty) {
            return const Center(child: Text('Nessuna licenza.'));
          }
          return ListView.separated(
            itemCount: licenses.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final l = licenses[i];
              final overdue = l.overdueAt(now);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: (overdue ? Colors.orange : Colors.green)
                      .withValues(alpha: 0.15),
                  child: Icon(Icons.workspace_premium_outlined,
                      color: overdue ? Colors.orange : Colors.green),
                ),
                title: Text('${l.companyName ?? l.companyId} · ${l.name}'),
                subtitle: Text(
                    '${Fmt.euro(l.price)}/${l.period} · ${l.status}'
                    '${l.renewalDate != null ? ' · rinnovo ${Fmt.date(l.renewalDate)}' : ''}'
                    '${overdue ? '  ⚠ in ritardo' : ''}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _open(context, ref, l);
                    if (v == 'pay') _addPayment(context, ref, l);
                    if (v == 'del') _delete(context, ref, l);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'pay', child: Text('Registra pagamento')),
                    PopupMenuItem(value: 'edit', child: Text('Modifica')),
                    PopupMenuItem(value: 'del', child: Text('Elimina')),
                  ],
                ),
                onTap: () => _open(context, ref, l),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, License? l) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) =>
            LicenseFormPage(license: l, presetCompanyId: companyId)));
    if (saved == true) {
      ref.invalidate(licensesListProvider);
      ref.invalidate(dashboardProvider);
    }
  }

  Future<void> _addPayment(
      BuildContext context, WidgetRef ref, License l) async {
    final ctrl = TextEditingController(text: Fmt.amount(l.price));
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registra pagamento'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Importo €'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, Fmt.parseAmount(ctrl.text) ?? 0),
              child: const Text('Salva')),
        ],
      ),
    );
    if (amount == null || amount <= 0) return;
    try {
      await ref
          .read(developerRepositoryProvider)
          .addPayment(l.id, l.companyId, amount, DateTime.now());
      ref.invalidate(dashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pagamento di ${Fmt.euro(amount)} registrato.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, License l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare la licenza?'),
        content: Text('"${l.name}" e i suoi pagamenti verranno eliminati.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(developerRepositoryProvider).delete(l.id);
    ref.invalidate(licensesListProvider);
    ref.invalidate(dashboardProvider);
  }
}
