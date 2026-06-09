// ============================================================
//  SMARTERP · organizations_page.dart — CRUD organizzazioni (super_admin).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/developer_providers.dart';
import '../data/admin_repository.dart';
import 'licenses_page.dart';

class OrganizationsPage extends ConsumerWidget {
  const OrganizationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(companiesAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Organizzazioni')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Nuova organizzazione'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (orgs) => ListView.separated(
          itemCount: orgs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final o = orgs[i];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.business)),
              title: Text((o['name'] as String?) ?? '—'),
              subtitle: Text([
                if (o['vat_number'] != null) 'P.IVA ${o['vat_number']}',
                if (o['city'] != null) o['city'],
                if (o['demo_mode'] == true) '🧪 dati di prova attivi',
              ].join(' · ')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Dati di prova',
                    child: Switch(
                      value: o['demo_mode'] == true,
                      onChanged: (v) => _toggleDemo(context, ref, o, v),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _edit(context, ref, o);
                      if (v == 'del') _delete(context, ref, o);
                      if (v == 'lic') {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => LicensesPage(
                            companyId: o['id'] as String,
                            companyName: o['name'] as String?,
                          ),
                        ));
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'lic', child: Text('Licenze')),
                      PopupMenuItem(value: 'edit', child: Text('Modifica')),
                      PopupMenuItem(value: 'del', child: Text('Elimina')),
                    ],
                  ),
                ],
              ),
              onTap: () => _edit(context, ref, o),
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggleDemo(BuildContext context, WidgetRef ref,
      Map<String, dynamic> o, bool on) async {
    if (!on) {
      // Spegnimento: i dati di prova (e quelli aggiunti durante il test)
      // vengono eliminati definitivamente.
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Disattivare i dati di prova?'),
          content: Text(
              'Tutti i dati di prova di "${o['name']}" e quelli inseriti '
              'durante il test verranno eliminati DEFINITIVAMENTE, lasciando '
              'l\'ambiente di produzione pulito.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Disattiva ed elimina')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await ref
          .read(adminRepositoryProvider)
          .setDemoMode(o['id'] as String, on);
      ref.invalidate(companiesAdminProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(on
                ? 'Dati di prova attivati per "${o['name']}".'
                : 'Dati di prova eliminati per "${o['name']}".')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Map<String, dynamic> o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare l\'organizzazione?'),
        content: Text(
            '"${o['name']}" e TUTTI i suoi dati (utenti, fatture, magazzino…) verranno eliminati.'),
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
      await ref.read(adminRepositoryProvider).deleteCompany(o['id'] as String);
      ref.invalidate(companiesAdminProvider);
      ref.invalidate(organizationsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, Map<String, dynamic>? o) async {
    await showDialog(context: context, builder: (_) => _OrgDialog(org: o));
    ref.invalidate(companiesAdminProvider);
    ref.invalidate(organizationsProvider);
  }
}

class _OrgDialog extends ConsumerStatefulWidget {
  const _OrgDialog({this.org});
  final Map<String, dynamic>? org;

  @override
  ConsumerState<_OrgDialog> createState() => _OrgDialogState();
}

class _OrgDialogState extends ConsumerState<_OrgDialog> {
  final _name = TextEditingController();
  final _vat = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.org == null;

  @override
  void initState() {
    super.initState();
    final o = widget.org;
    if (o != null) {
      _name.text = (o['name'] as String?) ?? '';
      _vat.text = (o['vat_number'] as String?) ?? '';
      _email.text = (o['email'] as String?) ?? '';
      _city.text = (o['city'] as String?) ?? '';
      _province.text = (o['province'] as String?) ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _vat, _email, _city, _province]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Il nome è obbligatorio');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final data = <String, dynamic>{
      'name': _name.text.trim(),
      'vat_number': _vat.text.trim().isEmpty ? null : _vat.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
      'province':
          _province.text.trim().isEmpty ? null : _province.text.trim().toUpperCase(),
    };
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (_isNew) {
        await repo.createCompany(data);
      } else {
        await repo.updateCompany(widget.org!['id'] as String, data);
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
      title: Text(_isNew ? 'Nuova organizzazione' : 'Modifica organizzazione'),
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
                decoration: const InputDecoration(labelText: 'Email')),
            Row(children: [
              Expanded(
                child: TextField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'Città')),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                    controller: _province,
                    maxLength: 2,
                    decoration: const InputDecoration(
                        labelText: 'Prov.', counterText: '')),
              ),
            ]),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
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
