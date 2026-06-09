// ============================================================
//  SMARTERP · app_router.dart
//  go_router con redirect basato sullo stato di autenticazione:
//   - non loggato            -> /login
//   - loggato su /login      -> /
//  Il router si aggiorna automaticamente a ogni evento auth.
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/supabase_providers.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/accounting/presentation/accounting_page.dart';
import '../features/chat/presentation/chat_rooms_page.dart';
import '../features/crm/presentation/crm_page.dart';
import '../features/customers/presentation/customers_page.dart';
import '../features/documents/presentation/documents_page.dart';
import '../features/developer/presentation/account_requests_page.dart';
import '../features/developer/presentation/bundles_page.dart';
import '../features/developer/presentation/dev_dashboard_page.dart';
import '../features/developer/presentation/organizations_page.dart';
import '../features/developer/presentation/users_page.dart';
import '../features/errors/presentation/error_logs_page.dart';
import '../features/diagnostics/presentation/connection_check_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/invoices/presentation/invoices_page.dart';
import '../features/products/presentation/products_page.dart';
import '../features/sales/presentation/sales_page.dart';
import '../features/settings/presentation/permissions_settings_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/studio/presentation/studio_page.dart';
import '../features/suppliers/presentation/suppliers_page.dart';
import '../features/support/presentation/support_page.dart';
import '../features/tickets/presentation/tickets_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Notifier che fa rivalutare il redirect a ogni cambio di sessione.
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      // Verità immediata sulla sessione (aggiornata subito dopo signOut).
      final loggedIn =
          ref.read(supabaseClientProvider).auth.currentSession != null;
      final goingToLogin = state.matchedLocation == '/login';

      if (!loggedIn) {
        // Le pagine pubbliche: login e diagnostica.
        final isPublic = goingToLogin || state.matchedLocation == '/diagnostics';
        return isPublic ? null : '/login';
      }
      // Gia' loggato ma sulla pagina di login -> vai alla home.
      if (goingToLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomePage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/invoices', builder: (_, __) => const InvoicesPage()),
      GoRoute(path: '/customers', builder: (_, __) => const CustomersPage()),
      GoRoute(path: '/products', builder: (_, __) => const ProductsPage()),
      GoRoute(path: '/chat', builder: (_, __) => const ChatRoomsPage()),
      GoRoute(path: '/studio', builder: (_, __) => const StudioPage()),
      GoRoute(path: '/errors', builder: (_, __) => const ErrorLogsPage()),
      GoRoute(path: '/dev', builder: (_, __) => const DevDashboardPage()),
      GoRoute(path: '/bundles', builder: (_, __) => const BundlesPage()),
      GoRoute(path: '/account-requests',
          builder: (_, __) => const AccountRequestsPage()),
      GoRoute(path: '/tickets', builder: (_, __) => const TicketsPage()),
      GoRoute(path: '/suppliers', builder: (_, __) => const SuppliersPage()),
      GoRoute(path: '/sales', builder: (_, __) => const SalesPage()),
      GoRoute(path: '/crm', builder: (_, __) => const CrmPage()),
      GoRoute(path: '/accounting', builder: (_, __) => const AccountingPage()),
      GoRoute(path: '/documents', builder: (_, __) => const DocumentsPage()),
      GoRoute(path: '/support', builder: (_, __) => const SupportPage()),
      GoRoute(path: '/users', builder: (_, __) => const UsersPage()),
      GoRoute(path: '/orgs', builder: (_, __) => const OrganizationsPage()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      GoRoute(
        path: '/settings/permissions',
        builder: (_, __) => const PermissionsSettingsPage(),
      ),
      GoRoute(
        path: '/diagnostics',
        builder: (_, __) => const ConnectionCheckPage(),
      ),
    ],
  );
});

/// Ponte tra lo StreamProvider auth e il refreshListenable di go_router.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    _sub = ref.listen(
      authStateChangesProvider,
      (_, __) => notifyListeners(),
      fireImmediately: false,
    );
  }

  late final ProviderSubscription _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
