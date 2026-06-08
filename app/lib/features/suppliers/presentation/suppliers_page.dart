// ============================================================
//  SMARTERP · suppliers_page.dart — anagrafica fornitori (CRUD).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../data/suppliers_repository.dart';
import '../domain/supplier.dart';

class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key});

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(canProvider(Perm.suppliersCreate));
    final canEdit = ref.watch(canProvider(Perm.suppliersEdit));
    final canDelete = ref.watch(canProvider(Perm.suppliersDelete));
    final listAsync = ref.watch(suppliersListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fornitori')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo fornitore'),
            )
          : null,
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (all) {
          final q = _query.trim().toLowerCase();
          final items = q.isEmpty
              ? all
              : all
                  .where((s) => '${s.name} ${s.vatNumber ?? ''}'
                      .toLowerCase()
                      .contains(q))
                  .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Cerca per nome o P.IVA',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Nessun fornitore.'))
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(suppliersListProvider),
                        child: ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final s = items[i];
                            return ListTile(
                              leading: const CircleAvatar(
                                  child: Icon(Icons.local_shipping_outlined)),
                              title: Text(s.name),
                              subtitle: Text([
                                if (s.vatNumber != null) 'P.IVA ${s.vatNumber}',
                                if (s.phone != null) s.phone,
                                if (s.address != null) s.address,
                              ].whereType<String>().join(' · ')),
                              trailing: canDelete
                                  ? IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _delete(context, s),
                                    )
                                  : null,
                              onTap: canEdit ? () => _edit(context, s) : null,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context, Supplier s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare il fornitore?'),
        content: Text('"${s.name}" verrà eliminato.'),
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
      await ref.read(suppliersRepositoryProvider).delete(s.id);
      ref.invalidate(suppliersListProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _edit(BuildContext context, Supplier? s) async {
    await showDialog(context: context, builder: (_) => _SupplierDialog(supplier: s));
    ref.invalidate(suppliersListProvider);
  }
}

class _SupplierDialog extends ConsumerStatefulWidget {
  const _SupplierDialog({this.supplier});
  final Supplier? supplier;

  @override
  ConsumerState<_SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends ConsumerState<_SupplierDialog> {
  final _name = TextEditingController();
  final _vat = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.supplier == null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    if (s != null) {
      _name.text = s.name;
      _vat.text = s.vatNumber ?? '';
      _email.text = s.email ?? '';
      _phone.text = s.phone ?? '';
      _address.text = s.address ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _vat, _email, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Il nome è obbligatorio');
      return;
    }
    final profile = await ref.read(currentProfileProvider.future);
    final companyId = profile?.companyId;
    if (companyId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final s = Supplier(
      id: widget.supplier?.id ?? '',
      companyId: companyId,
      name: _name.text,
      vatNumber: _vat.text,
      email: _email.text,
      phone: _phone.text,
      address: _address.text,
    );
    try {
      final repo = ref.read(suppliersRepositoryProvider);
      if (_isNew) {
        await repo.create(companyId, s);
      } else {
        await repo.update(s);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? 'Nuovo fornitore' : 'Modifica fornitore'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nome *')),
            TextField(
                controller: _vat,
                decoration: const InputDecoration(labelText: 'Partita IVA')),
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email')),
            TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefono')),
            TextField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Indirizzo')),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Annulla')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salva'),
        ),
      ],
    );
  }
}
