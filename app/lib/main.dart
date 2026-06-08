// ============================================================
//  SMARTERP · main.dart — bootstrap dell'applicazione.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'core/error_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza Supabase in modo difensivo: se fallisce NON deve impedire
  // l'avvio dell'app, altrimenti la pagina resta bianca e non si capisce
  // perche'. L'eventuale errore viene mostrato nella pagina diagnostica.
  String? initError;
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      debug: !AppConfig.isProduction,
    );
    debugPrint('SmartERP avviato -> ${AppConfig.environmentLabel}'
        ' | URL: ${AppConfig.supabaseUrl}');
    // Cattura globale degli errori → registro DB (Bug del giorno).
    ErrorLogger.install();
  } catch (e, st) {
    initError = '$e';
    debugPrint('SmartERP: init Supabase FALLITA -> $e\n$st');
  }

  runApp(
    ProviderScope(
      child: SmartErpApp(initError: initError),
    ),
  );
}
