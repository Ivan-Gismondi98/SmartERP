// ============================================================
//  SMARTERP · settings_page.dart — impostazioni: generali + per-applicativo.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/licensing.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import 'company_branding_page.dart';
import 'module_settings_page.dart';
import 'permissions_settings_page.dart';

/// Voci "per applicativo": ognuna gestisce opzioni/permessi di un modulo.
/// `module` = codice modulo permessi; `app` = codice licenza che la abilita.
/// (Alcune licenze abilitano più moduli: es. 'invoices' → Fatture + Vendite,
///  'purchases' → Acquisti + Fornitori.)
const _appSettings =
    <({String module, String label, IconData icon, String app})>[
  (module: 'invoices', label: 'Fatture', icon: Icons.receipt_long_outlined, app: 'invoices'),
  (module: 'sales', label: 'Vendite', icon: Icons.request_quote_outlined, app: 'invoices'),
  (module: 'customers', label: 'Clienti', icon: Icons.people_alt_outlined, app: 'customers'),
  (module: 'products', label: 'Magazzino / Prodotti', icon: Icons.inventory_2_outlined, app: 'products'),
  (module: 'crm', label: 'CRM', icon: Icons.handshake_outlined, app: 'crm'),
  (module: 'accounting', label: 'Contabilità', icon: Icons.account_balance_outlined, app: 'accounting'),
  (module: 'documents', label: 'Documenti', icon: Icons.folder_open_outlined, app: 'documents'),
  (module: 'production', label: 'Produzione', icon: Icons.precision_manufacturing_outlined, app: 'production'),
  (module: 'purchases', label: 'Acquisti', icon: Icons.shopping_bag_outlined, app: 'purchases'),
  (module: 'suppliers', label: 'Fornitori', icon: Icons.local_shipping_outlined, app: 'purchases'),
  (module: 'maintenance', label: 'Manutenzione', icon: Icons.build_outlined, app: 'maintenance'),
  (module: 'projects', label: 'Progetti', icon: Icons.assignment_outlined, app: 'projects'),
  (module: 'chat', label: 'Chat', icon: Icons.chat_bubble_outline, app: 'chat'),
  (module: 'studio', label: 'Studio', icon: Icons.dashboard_customize_outlined, app: 'studio'),
];

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(canProvider(Perm.settingsPermissionsManage));
    final canCompany = ref.watch(canProvider(Perm.settingsCompanyManage));
    // App con licenza attiva (il super_admin le ha tutte).
    final licensed =
        ref.watch(licensedAppsProvider).valueOrNull ?? const <String>{};
    final appItems =
        _appSettings.where((e) => licensed.contains(e.app)).toList();

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
          if (appItems.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                  'Nessuna applicazione con licenza attiva da configurare.',
                  style: TextStyle(color: Colors.grey)),
            ),
          for (final e in appItems)
            ListTile(
              leading: Icon(e.icon),
              title: Text(e.label),
              subtitle: const Text('Opzioni e permessi del modulo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    ModuleSettingsPage(module: e.module, title: e.label),
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
