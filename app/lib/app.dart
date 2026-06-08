// ============================================================
//  SMARTERP · app.dart — widget radice (MaterialApp.router).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/assistant/presentation/assistant_bar.dart';
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
        theme: AppTheme.light,
        home: ConnectionCheckPage(initError: initError),
      );
    }

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SmartERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      // L'Assistente IA compare in fondo a OGNI pagina (se la licenza è attiva).
      builder: (context, child) => Column(
        children: [
          Expanded(child: child ?? const SizedBox.shrink()),
          const AssistantBar(),
        ],
      ),
    );
  }
}
