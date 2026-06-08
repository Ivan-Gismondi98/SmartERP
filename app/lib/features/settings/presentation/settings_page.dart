// ============================================================
//  SMARTERP · settings_page.dart — impostazioni applicazione.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManagePerms = ref.watch(canProvider(Perm.settingsPermissionsManage));

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        children: [
          if (canManagePerms)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Permessi per ruolo'),
              subtitle: const Text(
                  'Definisci cosa puo\' fare ogni ruolo (stile Odoo)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/permissions'),
            ),
          if (!canManagePerms)
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Nessuna impostazione disponibile'),
              subtitle:
                  Text('Servono permessi amministrativi per modificare le impostazioni.'),
            ),
        ],
      ),
    );
  }
}
