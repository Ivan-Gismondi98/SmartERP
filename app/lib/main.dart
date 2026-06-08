// ============================================================
//  SMARTERP · main.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';

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
  } catch (e, st) {
    initError = '$e';
    debugPrint('SmartERP: init Supabase FALLITA -> $e\n$st');
  }

  runApp(SmartErpApp(initError: initError));
}

Future<List<Map<String, dynamic>>> _probeCompanies() {
  return Supabase.instance.client
      .from('companies')
      .select('id,name')
      .limit(1);
}

class SmartErpApp extends StatelessWidget {
  const SmartErpApp({super.key, this.initError});

  final String? initError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0D47A1),
      ),
      home: ConnectionCheckPage(initError: initError),
    );
  }
}

/// Pagina diagnostica: verifica che il backend Docker risponda.
class ConnectionCheckPage extends StatelessWidget {
  const ConnectionCheckPage({super.key, this.initError});

  final String? initError;

  @override
  Widget build(BuildContext context) {
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
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _probeCompanies(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (snapshot.hasError) {
                      return Text('Errore: ${snapshot.error}',
                          textAlign: TextAlign.center);
                    }
                    return Text('DB raggiungibile: ${snapshot.data}',
                        textAlign: TextAlign.center);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
