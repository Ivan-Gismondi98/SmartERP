// ============================================================
//  SMARTERP · invoices_page.dart — elenco fatture.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../application/invoices_providers.dart';
import '../domain/invoice.dart';
import 'invoice_detail_page.dart';
import 'invoice_form_page.dart';

class InvoicesPage extends ConsumerWidget {
  const InvoicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreate = ref.watch(canProvider(Perm.invoicesCreate));
    final listAsync = ref.watch(invoicesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fatture')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Nuova fattura'),
            )
          : null,
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (invoices) {
          if (invoices.isEmpty) {
            return const Center(child: Text('Nessuna fattura.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(invoicesListProvider),
            child: ListView.separated(
              itemCount: invoices.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final inv = invoices[i];
                return ListTile(
                  leading: _StatusBadge(status: inv.status),
                  title: Text(
                      'Fattura ${inv.displayNumber} · ${Fmt.date(inv.issueDate)}'),
                  subtitle: Text(inv.customer?.name ?? 'Cliente non indicato'),
                  trailing: Text(Fmt.euro(inv.total),
                      style: Theme.of(context).textTheme.titleMedium),
                  onTap: () => _openDetail(context, ref, inv.id!),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEditor(
      BuildContext context, WidgetRef ref, String? id) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => InvoiceFormPage(invoiceId: id)),
    );
    if (changed == true) ref.invalidate(invoicesListProvider);
  }

  Future<void> _openDetail(
      BuildContext context, WidgetRef ref, String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoiceId: id)),
    );
    ref.invalidate(invoicesListProvider);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (status) {
      InvoiceStatus.draft => (scheme.outline, Icons.edit_note),
      InvoiceStatus.sent => (scheme.primary, Icons.send),
      InvoiceStatus.paid => (Colors.green, Icons.check_circle),
      InvoiceStatus.overdue => (scheme.error, Icons.warning_amber),
      InvoiceStatus.cancelled => (scheme.outline, Icons.cancel),
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color),
    );
  }
}
