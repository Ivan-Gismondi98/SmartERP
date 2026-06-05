// ============================================================
//  SMARTERP · AppConfig
//  Risolve l'endpoint backend in base a:
//   - flag --dart-define PRODUCTION (cloud HTTPS vs locale)
//   - piattaforma (Web/iOS -> localhost, Android emu -> 10.0.2.2)
//  Usa `defaultTargetPlatform` (no dart:io) per restare web-safe.
// ============================================================
import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  // ----- Flag di build -----
  /// Passata con: --dart-define=PRODUCTION=true
  static const bool isProduction =
      bool.fromEnvironment('PRODUCTION', defaultValue: false);

  // ----- Produzione (Supabase Cloud / VPS HTTPS) -----
  static const String _prodUrl = String.fromEnvironment(
    'PROD_SUPABASE_URL',
    defaultValue: 'https://smarterp.example.com',
  );
  static const String _prodAnonKey = String.fromEnvironment(
    'PROD_ANON_KEY',
    defaultValue: '',
  );

  // ----- Locale (Docker self-hosted, gateway Kong su :8000) -----
  /// Web, iOS Simulator, Desktop -> la rete del container e' "localhost".
  static const String _localUrlLoopback = 'http://localhost:8000';

  /// Emulatore Android -> 10.0.2.2 e' l'alias verso l'host della macchina.
  static const String _localUrlAndroidEmu = 'http://10.0.2.2:8000';

  /// Override opzionale per dispositivo Android FISICO (IP del PC in LAN).
  /// Esempio: --dart-define=LOCAL_OVERRIDE_URL=http://192.168.1.50:8000
  static const String _localOverrideUrl = String.fromEnvironment(
    'LOCAL_OVERRIDE_URL',
    defaultValue: '',
  );

  /// Chiave anon DEMO (combacia con .env / kong.yml).
  static const String _localAnonKey = String.fromEnvironment(
    'LOCAL_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlLWRlbW8iLCJpYXQiOjE2NDE3NjkyMDAsImV4cCI6MTc5OTUzNTYwMH0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE',
  );

  /// URL del backend Supabase risolto a runtime.
  static String get supabaseUrl {
    if (isProduction) return _prodUrl;

    // Dispositivo fisico in LAN: override esplicito ha la precedenza.
    if (_localOverrideUrl.isNotEmpty) return _localOverrideUrl;

    // Locale: distinguiamo l'emulatore Android dal resto.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _localUrlAndroidEmu; // 10.0.2.2:8000
    }
    return _localUrlLoopback; // localhost:8000 (Web / iOS / Desktop)
  }

  /// Chiave anon risolta a runtime.
  static String get supabaseAnonKey =>
      isProduction ? _prodAnonKey : _localAnonKey;

  /// Etichetta diagnostica (mostrata nei log di debug).
  static String get environmentLabel =>
      isProduction ? 'PRODUCTION (cloud)' : 'LOCAL (docker)';
}
