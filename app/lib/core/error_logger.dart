// ============================================================
//  SMARTERP · error_logger.dart
//  Registra in DB (tabella error_logs) ogni errore dell'app, così lo
//  sviluppatore può leggerli dall'app ("Bug del giorno") senza accedere
//  ai log del server. È best-effort: non solleva mai eccezioni.
// ============================================================
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorLogger {
  ErrorLogger._();

  /// Rotta corrente (impostata dal router) per contestualizzare gli errori.
  static String? currentRoute;

  /// Registra un errore. severity: info | warning | error | fatal.
  static Future<void> report(
    Object error, {
    StackTrace? stack,
    String severity = 'error',
    String? module,
    String? route,
    String? messageOverride,
  }) async {
    try {
      final client = Supabase.instance.client;
      // Logga solo se c'è una sessione (RLS richiede authenticated).
      if (client.auth.currentSession == null) return;
      final msg = (messageOverride ?? error.toString());
      await client.from('error_logs').insert({
        'severity': severity,
        'module': module,
        'message': msg.length > 1000 ? msg.substring(0, 1000) : msg,
        'details': stack?.toString(),
        'route': route ?? currentRoute,
      });
    } catch (_) {
      // Mai propagare errori dal logger.
    }
  }

  /// Installa i gestori globali di errore Flutter/async.
  static void install() {
    final prev = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      prev?.call(details);
      report(details.exception,
          stack: details.stack,
          severity: 'error',
          module: details.library ?? 'flutter',
          messageOverride: details.exceptionAsString());
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack: stack, severity: 'fatal', module: 'async');
      return false; // lascia che l'errore segua il flusso normale
    };
  }
}
