// ============================================================
//  SMARTERP · supabase_providers.dart
//  Espone i client Supabase ai provider.
//   - supabaseClientProvider: client reale (auth/sessione dello sviluppatore).
//   - dataClientProvider: client per i DATI; in impersonate usa il JWT del
//     target, così le query girano con la RLS di quell'utente.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'impersonation.dart';

/// Client Supabase reale (inizializzato in `main()`). NON cambia mai:
/// gestisce auth/sessione e l'identità reale dello sviluppatore.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Client usato dai repository DATI. In impersonate usa un client dedicato
/// con il JWT del target (RLS come quell'utente); altrimenti quello reale.
final dataClientProvider = Provider<SupabaseClient>((ref) {
  final token = ref.watch(impersonationProvider).token;
  if (token == null) return Supabase.instance.client;
  final client = SupabaseClient(
    AppConfig.supabaseUrl,
    AppConfig.supabaseAnonKey,
    headers: {'Authorization': 'Bearer $token'},
  );
  ref.onDispose(() => client.dispose());
  return client;
});
