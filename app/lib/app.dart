// ============================================================
//  SMARTERP · app.dart — widget radice (MaterialApp.router).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/assistant/presentation/assistant_bar.dart';
import 'features/profile/application/profile_providers.dart';
import 'features/diagnostics/presentation/connection_check_page.dart';
import 'routing/app_router.dart';

class SmartErpApp extends ConsumerWidget {
  const SmartErpApp({super.key, this.initError});

  /// Se l'inizializzazione di Supabase e' fallita, mostriamo subito la
  /// pagina diagnostica con l'errore invece del router (che richiede auth).
  final String? initError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initError != null) {
      return MaterialApp(
        title: 'SmartERP',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: ConnectionCheckPage(initError: initError),
      );
    }

    final router = ref.watch(routerProvider);
    // Colore primario dell'organizzazione (deciso dall'admin): tutti gli
    // utenti dell'azienda vedono il branding scelto.
    final company = ref.watch(currentProfileProvider).valueOrNull?.company;
    final seed = AppTheme.hexToColor(company?.brandPrimaryHex);
    return MaterialApp.router(
      title: 'SmartERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(seed),
      darkTheme: AppTheme.dark(seed),
      routerConfig: router,
      // L'Assistente IA: icona tonda ancorata a destra, quasi in fondo,
      // sopra OGNI pagina (se la licenza è attiva).
      builder: (context, child) => Stack(
        children: [
          Positioned.fill(child: child ?? const SizedBox.shrink()),
          const Positioned(right: 16, bottom: 96, child: AssistantBar()),
        ],
      ),
    );
  }
}
