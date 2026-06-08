// ============================================================
//  SMARTERP · impersonate_dialog.dart
//  Avvio/arresto dell'impersonate (solo super_admin).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/impersonation.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/profile.dart';
import '../../support/data/support_repository.dart';
import '../application/developer_providers.dart';
import '../data/admin_repository.dart';
import '../domain/app_user.dart';

class ImpersonateDialog {
  /// Punto d'ingresso: se già in impersonate chiede se interrompere,
  /// altrimenti apre il selettore organizzazione/utente.
  static Future<void> open(BuildContext context, WidgetRef ref) async {
    final active = ref.read(impersonationProvider).active;
    if (active) {
      final stop = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Impersonate in corso'),
          content: const Text('Vuoi interrompere l\'impersonate e tornare al tuo profilo Sviluppatore?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Interrompi')),
          ],
        ),
      );
      if (stop == true) ref.read(impersonationProvider.notifier).stop();
      return;
    }
    await showDialog(context: context, builder: (_) => const _PickerDialog());
  }
}

class _PickerDialog extends ConsumerStatefulWidget {
  const _PickerDialog();

  @override
  ConsumerState<_PickerDialog> createState() => _PickerDialogState();
}

class _PickerDialogState extends ConsumerState<_PickerDialog> {
  String? _companyId;
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final orgs = ref.watch(organizationsProvider);
    final usersAsync = ref.watch(usersListProvider);

    return AlertDialog(
      title: const Text('Impersona un utente'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            orgs.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Errore org: $e'),
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _companyId,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Organizzazione'),
                items: [
                  for (final o in list)
                    DropdownMenuItem(value: o.id, child: Text(o.name)),
                ],
                onChanged: (v) => setState(() => _companyId = v),
              ),
            ),
            const SizedBox(height: 8),
            if (_companyId != null)
              SizedBox(
                height: 320,
                width: 400,
                child: usersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Errore utenti: $e'),
                  data: (users) {
                    final list = users
                        .where((u) => u.companyId == _companyId)
                        .toList();
                    if (list.isEmpty) {
                      return const Center(
                          child: Text('Nessun utente in questa organizzazione.'));
                    }
                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final u = list[i];
                        return ListTile(
                          leading: CircleAvatar(
                              child: Text((u.fullName ?? u.email)
                                  .characters
                                  .first
                                  .toUpperCase())),
                          title: Text(u.fullName ?? u.email),
                          subtitle: Text(
                              '${kRoleLabels[u.role] ?? u.role} · ${u.email}'),
                          onTap: _starting ? null : () => _start(u),
                        );
                      },
                    );
                  },
                ),
              ),
            if (_starting) const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla')),
      ],
    );
  }

  Future<void> _start(AppUser u) async {
    setState(() => _starting = true);
    final target = Profile(
      id: u.id,
      role: UserRole.fromDb(u.role),
      companyId: u.companyId,
      fullName: u.fullName,
      company: u.companyId != null
          ? Company(id: u.companyId!, name: u.companyName ?? '')
          : null,
    );
    final dev = ref.read(realProfileProvider).valueOrNull;
    try {
      // Token RLS-scoped del target → i dati mostrati sono quelli della sua org.
      final token =
          await ref.read(adminRepositoryProvider).impersonationToken(u.id);
      // Notifica nel canale di supporto del target (prima dello switch client).
      final when = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      try {
        await ref.read(supportRepositoryProvider).postImpersonationNotice(
              u.id,
              target.role,
              u.companyId,
              '🔒 Lo sviluppatore "${dev?.displayName ?? 'Sviluppatore'}" ha '
              'effettuato l\'accesso come questo utente il $when.',
            );
      } catch (_) {/* notifica best-effort */}
      ref.read(impersonationProvider.notifier).start(target, token);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _starting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Impersonate non riuscito: $e')));
      }
    }
  }
}
