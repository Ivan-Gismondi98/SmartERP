// ============================================================
//  SMARTERP · settings_page.dart — impostazioni: generali + per-applicativo.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import 'company_branding_page.dart';
import 'module_settings_page.dart';
import 'permissions_settings_page.dart';

/// Applicativi che hanno una pagina impostazioni dedicata.
const _modules = <(String, String, IconData)>[
  ('invoices', 'Fatture', Icons.receipt_long_outlined),
  ('products', 'Magazzino / Prodotti', Icons.inventory_2_outlined),
  ('customers', 'Clienti', Icons.people_alt_outlined),
  ('chat', 'Chat', Icons.chat_bubble_outline),
];

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(canProvider(Perm.settingsPermissionsManage));
    final canCompany = ref.watch(canProvider(Perm.settingsCompanyManage));

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        children: [
          _sectionHeader(context, 'Generali'),
          if (canCompany)
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Branding aziendale'),
              subtitle: const Text('Colori e logo applicati ai PDF'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CompanyBrandingPage())),
            ),
          if (canManage)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Permessi per ruolo (tutti i moduli)'),
              subtitle: const Text(
                  'Permessi generici e di feature, per ruolo (stile Odoo)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PermissionsSettingsPage())),
            )
          else
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Servono permessi amministrativi'),
              subtitle: Text(
                  'Solo chi può gestire i permessi vede le impostazioni avanzate.'),
            ),
          const Divider(),
          _sectionHeader(context, 'Per applicativo'),
          for (final (id, label, icon) in _modules)
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              subtitle: const Text('Opzioni e permessi del modulo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    ModuleSettingsPage(module: id, title: label),
              )),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary)),
      );
}
