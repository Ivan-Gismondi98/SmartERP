// ============================================================
//  SMARTERP · home_page.dart — dashboard post-login.
//  Mostra l'utente, l'azienda e i moduli del gestionale (placeholder
//  per le funzionalita' ancora da implementare nella roadmap).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/profile.dart';

/// Modulo del gestionale mostrato come tile nella dashboard.
class _Module {
  const _Module(this.label, this.icon,
      {this.route, this.requiredPermission, this.staffOnly = true});
  final String label;
  final IconData icon;

  /// Rotta da aprire (null = modulo non ancora implementato).
  final String? route;

  /// Permesso necessario per vedere il modulo (null = nessuno).
  final String? requiredPermission;

  /// Visibile solo allo staff (admin/employee/super_admin).
  final bool staffOnly;
}

const _modules = <_Module>[
  _Module('Fatture', Icons.receipt_long_outlined,
      route: '/invoices', requiredPermission: Perm.invoicesView),
  _Module('Clienti', Icons.people_alt_outlined,
      route: '/customers', requiredPermission: Perm.customersView),
  _Module('Magazzino', Icons.inventory_2_outlined,
      route: '/products', requiredPermission: Perm.productsView),
  _Module('Prodotti', Icons.sell_outlined,
      route: '/products', requiredPermission: Perm.productsView),
  _Module('Fornitori', Icons.local_shipping_outlined),
  _Module('Chat', Icons.chat_bubble_outline,
      route: '/chat', requiredPermission: Perm.chatView),
  _Module('Studio', Icons.dashboard_customize_outlined,
      route: '/studio', requiredPermission: Perm.studioView),
  _Module('Bug del giorno', Icons.bug_report_outlined,
      route: '/errors', requiredPermission: Perm.errorsView),
  _Module('Dashboard Sviluppatore', Icons.developer_board_outlined,
      route: '/dev', requiredPermission: Perm.devDashboard),
  _Module('Utenti', Icons.manage_accounts_outlined,
      route: '/users', requiredPermission: Perm.usersManage),
  _Module('Organizzazioni', Icons.apartment_outlined,
      route: '/orgs', requiredPermission: Perm.companiesManage),
  _Module('Impostazioni', Icons.settings_outlined,
      route: '/settings', staffOnly: false),
];

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartERP'),
        actions: [
          IconButton(
            tooltip: 'Esci',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(message: '$e', ref: ref),
        data: (profile) => _DashboardBody(profile: profile),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final role = profile?.role ?? UserRole.customer;
    final perms = ref.watch(allowedPermissionsProvider).valueOrNull ?? const {};

    final visibleModules = _modules.where((m) {
      if (m.staffOnly && !role.isStaff) return false;
      if (m.requiredPermission != null &&
          !perms.contains(m.requiredPermission)) {
        return false;
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ProfileCard(profile: profile),
        const SizedBox(height: 24),
        Text('Moduli', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: _columnsFor(context),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            for (final m in visibleModules)
              _ModuleTile(
                module: m,
                onTap: () => _open(context, m),
              ),
          ],
        ),
      ],
    );
  }

  int _columnsFor(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1000) return 4;
    if (w >= 600) return 3;
    return 2;
  }

  void _open(BuildContext context, _Module m) {
    if (m.route != null) {
      context.push(m.route!);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Modulo "${m.label}" in arrivo.')),
        );
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile?.displayName ?? 'Utente';
    final companyName = profile?.company?.name ?? 'Nessuna azienda associata';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(initial,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  )),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(companyName, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text((profile?.role ?? UserRole.customer).label),
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.badge_outlined, size: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module, required this.onTap});

  final _Module module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(module.icon, size: 36, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(module.label, style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.ref});

  final String message;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text('Impossibile caricare il profilo:\n$message',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(currentProfileProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}
