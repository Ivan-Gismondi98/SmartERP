// ============================================================
//  SMARTERP · cost_centers_page.dart — gestione centri di costo
//  (contabilità analitica).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../application/accounting_providers.dart';
import '../data/accounting_repository.dart';
import '../domain/cost_center.dart';

class CostCentersPage extends ConsumerWidget {
  const CostCentersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(costCentersListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Centri di costo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Centro di costo'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Nessun centro di costo.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = list[i];
              return ListTile(
                leading: Text(c.code),
                title: Text(c.name),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _edit(context, ref, c);
                    if (v == 'delete') _delete(context, ref, c);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifica')),
                    PopupMenuItem(value: 'delete', child: Text('Elimina')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, CostCenter? c) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CostCenterDialog(center: c),
    );
    if (saved == true) ref.invalidate(costCentersListProvider);
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, CostCenter c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Eliminare ${c.code}?'),
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
      await ref.read(accountingRepositoryProvider).deleteCostCenter(c.id!);
      ref.invalidate(costCentersListProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }
}

class _CostCenterDialog extends ConsumerStatefulWidget {
  const _CostCenterDialog({this.center});
  final CostCenter? center;

  @override
  ConsumerState<_CostCenterDialog> createState() => _CostCenterDialogState();
}

class _CostCenterDialogState extends ConsumerState<_CostCenterDialog> {
  late final TextEditingController _code;
  late final TextEditingController _name;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.center?.code ?? '');
    _name = TextEditingController(text: widget.center?.name ?? '');
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_code.text.trim().isEmpty || _name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(accountingRepositoryProvider);
      final existing = widget.center;
      if (existing == null) {
        final profile = await ref.read(currentProfileProvider.future);
        final companyId = profile?.companyId;
        if (companyId == null) throw 'Nessuna azienda associata';
        await repo.createCostCenter(
            CostCenter(companyId: companyId, code: _code.text, name: _name.text));
      } else {
        existing
          ..code = _code.text
          ..name = _name.text;
        await repo.updateCostCenter(existing);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.center == null ? 'Nuovo centro di costo' : 'Modifica centro'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Codice *')),
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Denominazione *')),
        ],
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Annulla')),
        FilledButton(
            onPressed: _busy ? null : _save, child: const Text('Salva')),
      ],
    );
  }
}
