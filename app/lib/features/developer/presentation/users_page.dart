// ============================================================
//  SMARTERP · users_page.dart — gestione utenti (super_admin).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../../profile/domain/profile.dart';
import '../application/developer_providers.dart';
import '../data/admin_repository.dart';
import '../domain/app_user.dart';

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Utenti')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editDialog(context, ref, null),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nuovo utente'),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (users) => ListView.separated(
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final u = users[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: u.isActive ? null : Colors.grey.shade300,
                child: Text((u.fullName ?? u.email).characters.first.toUpperCase()),
              ),
              title: Text(u.fullName ?? u.email),
              subtitle: Text('${u.email}\n'
                  '${kRoleLabels[u.role] ?? u.role}'
                  '${u.companyName != null ? ' · ${u.companyName}' : ''}'
                  '${u.isActive ? '' : ' · DISATTIVO'}'),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _editDialog(context, ref, u);
                  if (v == 'del') _delete(context, ref, u);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Modifica')),
                  PopupMenuItem(value: 'del', child: Text('Elimina')),
                ],
              ),
              onTap: () => _editDialog(context, ref, u),
            );
          },
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, AppUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare l\'utente?'),
        content: Text('${u.email} verrà eliminato definitivamente.'),
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
      await ref.read(adminRepositoryProvider).deleteUser(u.id);
      ref.invalidate(usersListProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _editDialog(
      BuildContext context, WidgetRef ref, AppUser? user) async {
    await showDialog(
      context: context,
      builder: (_) => _UserDialog(user: user),
    );
    ref.invalidate(usersListProvider);
  }
}

class _UserDialog extends ConsumerStatefulWidget {
  const _UserDialog({this.user});
  final AppUser? user;

  @override
  ConsumerState<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends ConsumerState<_UserDialog> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  String _role = 'employee';
  String? _companyId;
  bool _active = true;
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.user == null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    if (u != null) {
      _email.text = u.email;
      _name.text = u.fullName ?? '';
      _role = u.role;
      _companyId = u.companyId;
      _active = u.isActive;
    }
  }

  @override
  void dispose() {
    for (final c in [_email, _name, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (_isNew) {
        if (_email.text.trim().isEmpty || _password.text.length < 6) {
          throw 'Email valida e password (min 6) obbligatorie';
        }
        await repo.createUser(
          email: _email.text.trim(),
          password: _password.text,
          fullName: _name.text.trim(),
          role: _role,
          companyId: _companyId,
        );
      } else {
        await repo.updateUser(
          widget.user!.id,
          fullName: _name.text.trim(),
          role: _role,
          companyId: _companyId,
          clearCompany: _companyId == null,
          isActive: _active,
        );
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
    final me = ref.watch(currentProfileProvider).valueOrNull;
    final isSuper = me?.role == UserRole.superAdmin;
    // L'admin opera solo sulla propria organizzazione.
    if (!isSuper && _companyId == null && me?.companyId != null) {
      _companyId = me!.companyId;
    }
    final roleEntries = kRoleLabels.entries
        .where((e) => isSuper || e.key != 'super_admin')
        .toList();
    final orgs = ref.watch(organizationsProvider);
    return AlertDialog(
      title: Text(_isNew ? 'Nuovo utente' : 'Modifica utente'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _email,
              enabled: _isNew,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            if (_isNew)
              TextField(
                controller: _password,
                decoration:
                    const InputDecoration(labelText: 'Password (min 6)'),
              ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome completo'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Ruolo'),
              items: [
                for (final e in roleEntries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'employee'),
            ),
            const SizedBox(height: 8),
            if (isSuper)
              orgs.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Errore org: $e'),
                data: (list) => DropdownButtonFormField<String?>(
                  initialValue: _companyId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Organizzazione'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Nessuna (globale)')),
                    for (final o in list)
                      DropdownMenuItem(value: o.id, child: Text(o.name)),
                  ],
                  onChanged: (v) => setState(() => _companyId = v),
                ),
              )
            else
              const InputDecorator(
                decoration: InputDecoration(labelText: 'Organizzazione'),
                child: Text('La tua organizzazione'),
              ),
            if (!_isNew)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Attivo'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
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
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salva'),
        ),
      ],
    );
  }
}
