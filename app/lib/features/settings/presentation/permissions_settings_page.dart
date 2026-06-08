// ============================================================
//  SMARTERP · permissions_settings_page.dart
//  Matrice permessi per ruolo, modificabile (stile Odoo).
//  Visibile solo a chi ha 'settings.permissions.manage'.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../../core/permissions/permissions_repository.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/profile.dart';

/// (catalogo, matrice ruolo->codice->allowed) per l'azienda corrente.
final _permissionsDataProvider = FutureProvider.autoDispose<
    ({List<PermissionDef> catalog, Map<String, Map<String, bool>> matrix})>(
  (ref) async {
    final repo = ref.watch(permissionsRepositoryProvider);
    final profile = await ref.watch(currentProfileProvider.future);
    final catalog = await repo.fetchCatalog();
    final matrix = await repo.fetchRoleMatrix(profile?.companyId);
    return (catalog: catalog, matrix: matrix);
  },
);

// Ruoli gestibili dalla matrice (super_admin ha sempre tutto, escluso).
const _roles = <(String, String)>[
  ('admin', 'Amministratore'),
  ('employee', 'Dipendente'),
  ('customer', 'Cliente'),
];

class PermissionsSettingsPage extends ConsumerWidget {
  const PermissionsSettingsPage({super.key, this.moduleFilter});

  /// Se valorizzato, mostra solo i permessi di quel modulo.
  final String? moduleFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(canProvider(Perm.settingsPermissionsManage));
    if (!canManage) {
      return Scaffold(
        appBar: AppBar(title: const Text('Permessi')),
        body: const Center(
          child: Text('Non hai il permesso di gestire i permessi.'),
        ),
      );
    }

    final dataAsync = ref.watch(_permissionsDataProvider);
    final title = moduleFilter == null
        ? 'Permessi per ruolo'
        : 'Permessi · ${moduleFilter!.toUpperCase()}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (data) {
          final isSuper =
              ref.watch(currentProfileProvider).valueOrNull?.role ==
                  UserRole.superAdmin;
          var catalog = moduleFilter == null
              ? data.catalog
              : data.catalog.where((p) => p.module == moduleFilter).toList();
          // L'admin gestisce solo i permessi marcati "delegabile" dallo
          // sviluppatore; il super_admin vede e gestisce tutto.
          if (!isSuper) {
            catalog = catalog.where((p) => p.adminManageable).toList();
          }
          if (catalog.isEmpty) {
            return const Center(
                child: Text('Nessun permesso gestibile per il tuo ruolo.'));
          }
          return _Matrix(catalog: catalog, matrix: data.matrix, isSuper: isSuper);
        },
      ),
    );
  }
}

class _Matrix extends ConsumerWidget {
  const _Matrix(
      {required this.catalog, required this.matrix, this.isSuper = false});
  final List<PermissionDef> catalog;
  final Map<String, Map<String, bool>> matrix;
  final bool isSuper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Raggruppa per modulo, e dentro ogni modulo per tipo (generic/feature).
    final byModule = <String, List<PermissionDef>>{};
    for (final p in catalog) {
      (byModule[p.module] ??= []).add(p);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final entry in byModule.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text(entry.key.toUpperCase(),
                style: Theme.of(context).textTheme.titleMedium),
          ),
          ..._kindSection(context, ref, 'Permessi generici',
              entry.value.where((p) => !p.isFeature).toList()),
          ..._kindSection(context, ref, 'Permessi di feature',
              entry.value.where((p) => p.isFeature).toList()),
        ],
      ],
    );
  }

  List<Widget> _kindSection(BuildContext context, WidgetRef ref, String title,
      List<PermissionDef> perms) {
    if (perms.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
        child: Text(title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary)),
      ),
      for (final perm in perms)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(perm.description,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(perm.code,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  children: [
                    for (final (roleDb, roleLabel) in _roles)
                      _RoleToggle(
                        roleDb: roleDb,
                        roleLabel: roleLabel,
                        code: perm.code,
                        value: matrix[roleDb]?[perm.code] ?? false,
                      ),
                  ],
                ),
                // Solo lo sviluppatore: decide se questo permesso è
                // delegabile/gestibile da un admin.
                if (isSuper)
                  _DelegaToggle(code: perm.code, value: perm.adminManageable),
              ],
            ),
          ),
        ),
    ];
  }
}

/// Toggle (super_admin) per rendere un permesso gestibile dall'admin.
class _DelegaToggle extends ConsumerStatefulWidget {
  const _DelegaToggle({required this.code, required this.value});
  final String code;
  final bool value;

  @override
  ConsumerState<_DelegaToggle> createState() => _DelegaToggleState();
}

class _DelegaToggleState extends ConsumerState<_DelegaToggle> {
  late bool _value = widget.value;
  bool _busy = false;

  Future<void> _toggle(bool v) async {
    setState(() {
      _value = v;
      _busy = true;
    });
    try {
      await ref
          .read(permissionsRepositoryProvider)
          .setAdminManageable(widget.code, v);
      ref.invalidate(_permissionsDataProvider);
      ref.invalidate(allowedPermissionsProvider);
    } catch (e) {
      setState(() => _value = !v);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          _busy
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Switch(value: _value, onChanged: _toggle),
          const Expanded(child: Text('Delegabile all\'admin')),
        ],
      ),
    );
  }
}

class _RoleToggle extends ConsumerStatefulWidget {
  const _RoleToggle({
    required this.roleDb,
    required this.roleLabel,
    required this.code,
    required this.value,
  });
  final String roleDb;
  final String roleLabel;
  final String code;
  final bool value;

  @override
  ConsumerState<_RoleToggle> createState() => _RoleToggleState();
}

class _RoleToggleState extends ConsumerState<_RoleToggle> {
  late bool _value = widget.value;
  bool _busy = false;

  Future<void> _toggle(bool v) async {
    final profile = await ref.read(currentProfileProvider.future);
    final companyId = profile?.companyId;
    if (companyId == null) return;
    setState(() {
      _value = v;
      _busy = true;
    });
    try {
      await ref.read(permissionsRepositoryProvider).setRolePermission(
            companyId: companyId,
            role: widget.roleDb,
            code: widget.code,
            allowed: v,
          );
      // Ricarica i permessi effettivi dell'utente corrente.
      ref.invalidate(allowedPermissionsProvider);
    } catch (e) {
      setState(() => _value = !v);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.roleLabel),
        _busy
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : Switch(value: _value, onChanged: _toggle),
      ],
    );
  }
}
