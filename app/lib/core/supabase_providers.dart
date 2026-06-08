// ============================================================
//  SMARTERP · supabase_providers.dart
//  Espone il client Supabase gia' inizializzato in main() ai provider.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client Supabase condiviso (inizializzato in `main()` prima di runApp).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
