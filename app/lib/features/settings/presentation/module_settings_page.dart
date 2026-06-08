// ============================================================
//  SMARTERP · module_settings_page.dart
//  Impostazioni di un singolo applicativo: feature toggle del modulo
//  + accesso ai permessi (generici/feature) del modulo.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../application/settings_providers.dart';
import '../data/settings_repository.dart';
import 'permissions_settings_page.dart';

/// Definizione di un feature toggle (impostazione booleana) di un modulo.
class _Toggle {
  const _Toggle(this.key, this.title, this.subtitle);
  final String key;
  final String title;
  final String subtitle;
}

/// Toggle disponibili per modulo.
const _moduleToggles = <String, List<_Toggle>>{
  'invoices': [
    _Toggle('sdi_enabled', 'Firma / Invio allo SdI',
        'Mostra il blocco di firma e trasmissione SdI nel dettaglio fattura'),
  ],
};

class ModuleSettingsPage extends ConsumerWidget {
  const ModuleSettingsPage(
      {super.key, required this.module, required this.title});

  final String module;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(canProvider(Perm.settingsPermissionsManage));
    final toggles = _moduleToggles[module] ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text('Impostazioni · $title')),
      body: ListView(
        children: [
          if (toggles.isNotEmpty) ...[
            _header(context, 'Funzionalità'),
            for (final t in toggles)
              _FeatureToggle(
                  module: module, toggle: t, enabled: canManage),
            const Divider(),
          ],
          _header(context, 'Permessi'),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Permessi del modulo'),
            subtitle: const Text('Generici e di feature, per ruolo'),
            trailing: const Icon(Icons.chevron_right),
            enabled: canManage,
            onTap: canManage
                ? () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        PermissionsSettingsPage(moduleFilter: module)))
                : null,
          ),
          if (!canManage)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                  'Servono permessi amministrativi per modificare queste impostazioni.'),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary)),
      );
}

class _FeatureToggle extends ConsumerWidget {
  const _FeatureToggle(
      {required this.module, required this.toggle, required this.enabled});

  final String module;
  final _Toggle toggle;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async =
        ref.watch(boolSettingProvider((scope: module, key: toggle.key)));
    final value = async.valueOrNull ?? false;

    return SwitchListTile(
      title: Text(toggle.title),
      subtitle: Text(toggle.subtitle),
      value: value,
      onChanged: !enabled
          ? null
          : (v) async {
              final profile = await ref.read(currentProfileProvider.future);
              final companyId = profile?.companyId;
              if (companyId == null) return;
              try {
                await ref.read(settingsRepositoryProvider).setValue(
                    companyId, module, toggle.key, v);
                ref.invalidate(
                    boolSettingProvider((scope: module, key: toggle.key)));
                ref.invalidate(sdiEnabledProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Errore: $e')));
                }
              }
            },
    );
  }
}
