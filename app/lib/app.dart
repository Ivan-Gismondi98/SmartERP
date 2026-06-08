// ============================================================
//  SMARTERP · app.dart — widget radice (MaterialApp.router).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/impersonation.dart';
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
      // Assistente IA + bordo "impersonate" sopra OGNI pagina.
      builder: (context, child) {
        final impersonating = ref.watch(impersonationProvider).active;
        return Stack(
          children: [
            Positioned.fill(child: child ?? const SizedBox.shrink()),
            const Positioned(right: 16, bottom: 96, child: AssistantBar()),
            if (impersonating) ..._hazardBorder(),
          ],
        );
      },
    );
  }

  /// Strisce gialle sui 4 bordi: indicano l'impersonate attivo.
  static List<Widget> _hazardBorder() {
    const thickness = 8.0;
    const hazard = DecoratedBox(
      decoration: BoxDecoration(color: Colors.amber),
      child: SizedBox.expand(),
    );
    return const [
      Positioned(top: 0, left: 0, right: 0, height: thickness,
          child: IgnorePointer(child: hazard)),
      Positioned(bottom: 0, left: 0, right: 0, height: thickness,
          child: IgnorePointer(child: hazard)),
      Positioned(top: 0, bottom: 0, left: 0, width: thickness,
          child: IgnorePointer(child: hazard)),
      Positioned(top: 0, bottom: 0, right: 0, width: thickness,
          child: IgnorePointer(child: hazard)),
    ];
  }
}
