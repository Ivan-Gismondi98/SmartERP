// ============================================================
//  SMARTERP · connection_check_page.dart
//  Pagina diagnostica: verifica che il backend Docker risponda.
//  Raggiungibile da /diagnostics (utile in fase di sviluppo).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../core/supabase_providers.dart';

/// Probe: legge una company dal backend per provare la connessione.
final _connectionProbeProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return client.from('companies').select('id,name').limit(1);
});

class ConnectionCheckPage extends ConsumerWidget {
  const ConnectionCheckPage({super.key, this.initError});

  final String? initError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('SmartERP · Connessione')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_done_outlined, size: 64),
              const SizedBox(height: 16),
              Text('Ambiente: ${AppConfig.environmentLabel}'),
              Text('Backend: ${AppConfig.supabaseUrl}'),
              const SizedBox(height: 24),
              if (initError != null)
                Text(
                  'Inizializzazione Supabase fallita:\n$initError',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else
                Consumer(
                  builder: (context, ref, _) {
                    final probe = ref.watch(_connectionProbeProvider);
                    return probe.when(
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) => Text('Errore: $e',
                          textAlign: TextAlign.center),
                      data: (data) => Text('DB raggiungibile: $data',
                          textAlign: TextAlign.center),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
