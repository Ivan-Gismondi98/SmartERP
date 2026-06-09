// ============================================================
//  SMARTERP · licenses_page.dart — gestione licenze e pagamenti (dev).
//  Selezione multipla per eliminazione in blocco.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/licensing.dart';
import '../application/developer_providers.dart';
import '../data/developer_repository.dart';
import '../domain/license.dart';
import 'license_form_page.dart';

class LicensesPage extends ConsumerStatefulWidget {
  const LicensesPage({super.key, this.companyId, this.companyName});

  /// Se valorizzato, mostra solo le licenze di quell'organizzazione.
  final String? companyId;
  final String? companyName;

  @override
  ConsumerState<LicensesPage> createState() => _LicensesPageState();
}

class _LicensesPageState extends ConsumerState<LicensesPage> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(licensesListProvider);
    final now = DateTime.now();
    final hasSel = _selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(hasSel
            ? '${_selected.length} selezionate'
            : (widget.companyName != null
                ? 'Licenze · ${widget.companyName}'
                : 'Licenze')),
        leading: hasSel
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Annulla selezione',
                onPressed: () => setState(_selected.clear),
              )
            : null,
        actions: [
          if (hasSel)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Elimina selezionate',
              onPressed: () => _deleteSelected(context),
            ),
        ],
      ),
      floatingActionButton: hasSel
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _open(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Nuova licenza'),
            ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (all) {
          final licenses = widget.companyId == null
              ? all
              : all.where((l) => l.companyId == widget.companyId).toList();
          if (licenses.isEmpty) {
            return const Center(child: Text('Nessuna licenza.'));
          }
          return ListView.separated(
            itemCount: licenses.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final l = licenses[i];
              if (l.isDefault) return _defaultTile(context, l);
              final overdue = l.overdueAt(now);
              final sel = _selected.contains(l.id);
              return ListTile(
                leading: Checkbox(
                  value: sel,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected.add(l.id);
                    } else {
                      _selected.remove(l.id);
                    }
                  }),
                ),
                title: Text('${l.companyName ?? l.companyId ?? '—'} · ${l.name}'),
                subtitle: Text(
                    '${Fmt.euro(l.price)}/${l.period} · ${l.status}'
                    '${l.renewalDate != null ? ' · rinnovo ${Fmt.date(l.renewalDate)}' : ''}'
                    '${overdue ? '  ⚠ in ritardo' : ''}'),
                trailing: hasSel
                    ? null
                    : PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _open(context, l);
                          if (v == 'pay') _addPayment(context, l);
                          if (v == 'del') _delete(context, l);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'pay', child: Text('Registra pagamento')),
                          PopupMenuItem(value: 'edit', child: Text('Modifica')),
                          PopupMenuItem(value: 'del', child: Text('Elimina')),
                        ],
                      ),
                onTap: hasSel
                    ? () => setState(() {
                          if (sel) {
                            _selected.remove(l.id);
                          } else {
                            _selected.add(l.id);
                          }
                        })
                    : () => _open(context, l),
              );
            },
          );
        },
      ),
    );
  }

  /// Riga di un PACCHETTO PREDEFINITO (licenza is_default, senza org):
  /// stella, non selezionabile/eliminabile/modificabile, solo "Duplica".
  Widget _defaultTile(BuildContext context, License l) {
    return ListTile(
      leading: const Tooltip(
        message: 'Pacchetto predefinito (non assegnato, non eliminabile)',
        child: SizedBox(width: 48, child: Icon(Icons.star, color: Colors.amber)),
      ),
      title: Text('${l.name} · ${Fmt.euro(l.price)}/${l.period}'),
      subtitle: Text('Pacchetto · ${l.appCodes.map(appLabel).join(', ')}'),
      trailing: FilledButton.tonalIcon(
        onPressed: () => _duplicate(context, l),
        icon: const Icon(Icons.copy_all_outlined),
        label: const Text('Duplica e assegna'),
      ),
      onTap: () => _duplicate(context, l),
    );
  }

  Future<void> _duplicate(BuildContext context, License l) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => LicenseFormPage(
            license: l,
            duplicate: true,
            presetCompanyId: widget.companyId)));
    if (saved == true) {
      ref.invalidate(licensesListProvider);
      ref.invalidate(dashboardProvider);
    }
  }

  Future<void> _open(BuildContext context, License? l) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) =>
            LicenseFormPage(license: l, presetCompanyId: widget.companyId)));
    if (saved == true) {
      ref.invalidate(licensesListProvider);
      ref.invalidate(dashboardProvider);
    }
  }

  Future<void> _addPayment(BuildContext context, License l) async {
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
          .addPayment(l.id, l.companyId!, amount, DateTime.now());
      ref.invalidate(dashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Pagamento di ${Fmt.euro(amount)} registrato.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _delete(BuildContext context, License l) async {
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

  Future<void> _deleteSelected(BuildContext context) async {
    final n = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Eliminare $n licenze?'),
        content: const Text('Le licenze e i relativi pagamenti verranno eliminati.'),
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
    final repo = ref.read(developerRepositoryProvider);
    for (final id in _selected) {
      await repo.delete(id);
    }
    setState(_selected.clear);
    ref.invalidate(licensesListProvider);
    ref.invalidate(dashboardProvider);
  }
}
