// ============================================================
//  SMARTERP · home_page.dart — dashboard post-login.
//  Mostra l'utente, l'azienda e i moduli del gestionale (placeholder
//  per le funzionalita' ancora da implementare nella roadmap).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/impersonation.dart';
import '../../../core/licensing.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../developer/presentation/impersonate_dialog.dart';
import '../../auth/application/auth_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/profile.dart';
import '../../tickets/data/tickets_repository.dart';

/// Modulo del gestionale mostrato come tile nella dashboard.
class _Module {
  const _Module(this.label, this.icon,
      {this.route,
      this.requiredPermission,
      this.app,
      this.adminOnly = false});
  final String label;
  final IconData icon;

  /// Rotta da aprire (null = modulo non ancora implementato).
  final String? route;

  /// Permesso necessario per vedere il modulo (null = nessuno).
  final String? requiredPermission;

  /// Codice app: il modulo è visibile solo se l'organizzazione ha una
  /// licenza attiva per quell'app (null = non soggetto a licenza).
  final String? app;

  /// Visibile solo ad amministratore/sviluppatore (non ai dipendenti).
  final bool adminOnly;
}

// Applicazioni mostrate come tile nella dashboard. Le pagine di sistema
// (Segnalazioni, Bug del giorno, Supporto, Utenti, Dashboard Sviluppatore)
// NON sono qui: sono icone nella barra in alto.
const _modules = <_Module>[
  _Module('CRM', Icons.handshake_outlined,
      route: '/crm', requiredPermission: Perm.crmView, app: 'crm'),
  _Module('Vendite', Icons.request_quote_outlined,
      route: '/sales', requiredPermission: Perm.salesView, app: 'invoices'),
  _Module('Fatture', Icons.receipt_long_outlined,
      route: '/invoices', requiredPermission: Perm.invoicesView, app: 'invoices'),
  _Module('Contabilità', Icons.account_balance_outlined,
      route: '/accounting', requiredPermission: Perm.accountingView, app: 'accounting'),
  _Module('Clienti', Icons.people_alt_outlined,
      route: '/customers', requiredPermission: Perm.customersView, app: 'customers'),
  _Module('Magazzino', Icons.inventory_2_outlined,
      route: '/products', requiredPermission: Perm.productsView, app: 'products'),
  _Module('Prodotti', Icons.sell_outlined,
      route: '/products', requiredPermission: Perm.productsView, app: 'products'),
  _Module('Produzione', Icons.precision_manufacturing_outlined,
      route: '/production', requiredPermission: Perm.productionView, app: 'production'),
  _Module('Acquisti', Icons.shopping_bag_outlined,
      route: '/purchases', requiredPermission: Perm.purchasesView, app: 'purchases'),
  // Fornitori fa parte del ciclo Acquisti: visibile con la stessa licenza.
  _Module('Fornitori', Icons.local_shipping_outlined,
      route: '/suppliers', requiredPermission: Perm.suppliersView, app: 'purchases'),
  _Module('Documenti', Icons.folder_open_outlined,
      route: '/documents', requiredPermission: Perm.documentsView, app: 'documents'),
  _Module('Manutenzione', Icons.build_outlined,
      route: '/maintenance', requiredPermission: Perm.maintenanceView, app: 'maintenance'),
  _Module('Progetti', Icons.assignment_outlined,
      route: '/projects', requiredPermission: Perm.projectsView, app: 'projects'),
  _Module('Chat', Icons.chat_bubble_outline,
      route: '/chat', requiredPermission: Perm.chatView, app: 'chat'),
  _Module('Studio', Icons.dashboard_customize_outlined,
      route: '/studio', requiredPermission: Perm.studioView, app: 'studio'),
  _Module('Organizzazioni', Icons.apartment_outlined,
      route: '/orgs', requiredPermission: Perm.companiesManage),
  // Impostazioni: solo admin/sviluppatore (anche senza licenze l'admin può
  // gestire il branding aziendale). I dipendenti non la vedono.
  _Module('Impostazioni', Icons.settings_outlined,
      route: '/settings', adminOnly: true),
];

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dashboard sul profilo EFFETTIVO (impersonato se attivo).
    final profileAsync = ref.watch(currentProfileProvider);
    final perms = ref.watch(allowedPermissionsProvider).valueOrNull ?? const {};
    final canTickets = perms.contains(Perm.ticketsView);
    final openTickets =
        canTickets ? ref.watch(openTicketsCountProvider) : 0;
    // L'impersonate è prerogativa dello sviluppatore REALE.
    final realRole = ref.watch(realProfileProvider).valueOrNull?.role;
    final isDeveloper = realRole == UserRole.superAdmin;
    final impersonating = ref.watch(impersonationProvider).active;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartERP'),
        actions: [
          if (canTickets)
            IconButton(
              tooltip: 'Segnalazioni',
              icon: Badge(
                isLabelVisible: openTickets > 0,
                label: Text('$openTickets'),
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () => context.push('/tickets'),
            ),
          if (perms.contains(Perm.errorsView))
            IconButton(
              tooltip: 'Bug del giorno',
              icon: const Icon(Icons.error_outline),
              onPressed: () => context.push('/errors'),
            ),
          IconButton(
            tooltip: 'Supporto',
            icon: const Icon(Icons.support_agent_outlined),
            onPressed: () => context.push('/support'),
          ),
          if (perms.contains(Perm.orgUsersManage))
            IconButton(
              tooltip: 'Utenti',
              icon: const Icon(Icons.manage_accounts_outlined),
              onPressed: () => context.push('/users'),
            ),
          if (perms.contains(Perm.devDashboard))
            IconButton(
              tooltip: 'Dashboard Sviluppatore',
              icon: const Icon(Icons.developer_board_outlined),
              onPressed: () => context.push('/dev'),
            ),
          if (isDeveloper)
            IconButton(
              tooltip: impersonating ? 'Interrompi impersonate' : 'Impersonate',
              icon: Icon(Icons.bug_report,
                  color: impersonating ? Colors.amber : null),
              onPressed: () => ImpersonateDialog.open(context, ref),
            ),
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
    final appStates = ref.watch(appLicenseStatesProvider).valueOrNull ??
        const <String, AppLicenseState>{};
    // Le app scadute sono visibili solo ad admin/sviluppatore.
    final isAdminLike =
        role == UserRole.admin || role == UserRole.superAdmin;

    final visible = <({_Module module, bool expired})>[];
    for (final m in _modules) {
      // La dashboard delle app è riservata allo staff.
      if (!role.isStaff) continue;
      if (m.adminOnly && !isAdminLike) continue;
      if (m.requiredPermission != null &&
          !perms.contains(m.requiredPermission)) {
        continue;
      }
      if (m.app != null) {
        final state = appStates[m.app];
        if (state == null) continue; // nessuna licenza: non mostrata
        if (state == AppLicenseState.expired) {
          if (!isAdminLike) continue; // scaduta: nascosta agli utenti semplici
          visible.add((module: m, expired: true));
        } else {
          visible.add((module: m, expired: false));
        }
      } else {
        visible.add((module: m, expired: false));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ProfileCard(profile: profile),
        const SizedBox(height: 24),
        if (visible.isEmpty)
          // Nessuna app disponibile (es. dipendente di un'organizzazione
          // senza licenze attive): messaggio informativo, niente griglia.
          _NoAppsBody(isAdminLike: isAdminLike)
        else ...[
          Text('Applicazioni', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: _columnsFor(context),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              for (final v in visible)
                _ModuleTile(
                  module: v.module,
                  expired: v.expired,
                  onTap: () => _open(context, v.module),
                ),
            ],
          ),
        ],
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
  const _ModuleTile(
      {required this.module, required this.onTap, this.expired = false});

  final _Module module;
  final VoidCallback onTap;

  /// Licenza scaduta: la tile è mostrata (solo all'admin) con barra rossa.
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(module.icon,
                      size: 36,
                      color: expired
                          ? theme.colorScheme.outline
                          : theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text(module.label, style: theme.textTheme.titleSmall),
                ],
              ),
            ),
            if (expired)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: theme.colorScheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'SCADUTO',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onError,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Messaggio mostrato quando non c'è alcuna applicazione disponibile
/// (tipicamente un dipendente di un'organizzazione senza licenze attive).
class _NoAppsBody extends StatelessWidget {
  const _NoAppsBody({required this.isAdminLike});
  final bool isAdminLike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.apps_outlined,
              size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('Nessuna applicazione disponibile',
              style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            isAdminLike
                ? 'La tua organizzazione non ha licenze attive. Attiva le '
                    'applicazioni dalla gestione licenze (sviluppatore).'
                : 'La tua organizzazione non ha applicazioni attive.\n'
                    'Contatta l\'amministratore della tua organizzazione per '
                    'sapere quali applicazioni sono abilitate.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
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
