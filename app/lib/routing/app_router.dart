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

import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/customers/presentation/customers_page.dart';
import '../features/diagnostics/presentation/connection_check_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/invoices/presentation/invoices_page.dart';
import '../features/settings/presentation/permissions_settings_page.dart';
import '../features/settings/presentation/settings_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Notifier che fa rivalutare il redirect a ogni cambio di sessione.
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(isAuthenticatedProvider);
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
