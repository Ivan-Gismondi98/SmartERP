// ============================================================
//  SMARTERP · customers_page.dart — elenco clienti.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../application/customers_providers.dart';
import '../data/customers_repository.dart';
import '../domain/customer.dart';
import 'customer_form_page.dart';

class CustomersPage extends ConsumerWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreate = ref.watch(canProvider(Perm.customersCreate));
    final canEdit = ref.watch(canProvider(Perm.customersEdit));
    final canDelete = ref.watch(canProvider(Perm.customersDelete));
    final listAsync = ref.watch(customersListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Clienti')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo cliente'),
            )
          : null,
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (customers) {
          if (customers.isEmpty) {
            return const Center(child: Text('Nessun cliente. Aggiungine uno.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(customersListProvider),
            child: ListView.separated(
              itemCount: customers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = customers[i];
                return ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                        c.isCompany ? Icons.business : Icons.person),
                  ),
                  title: Text(c.name),
                  subtitle: Text([
                    if (c.vatNumber != null) 'P.IVA ${c.vatNumber}',
                    if (c.fullAddress.isNotEmpty) c.fullAddress,
                  ].join(' · ')),
                  trailing: canDelete
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(context, ref, c),
                        )
                      : null,
                  onTap: canEdit ? () => _openForm(context, ref, c) : null,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openForm(
      BuildContext context, WidgetRef ref, Customer? existing) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CustomerFormPage(customer: existing)),
    );
    if (saved == true) ref.invalidate(customersListProvider);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Customer c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare il cliente?'),
        content: Text('"${c.name}" verra\' eliminato.'),
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
    try {
      await ref.read(customersRepositoryProvider).delete(c.id);
      ref.invalidate(customersListProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }
}
