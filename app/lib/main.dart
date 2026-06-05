// ============================================================
//  SMARTERP · main.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    debug: !AppConfig.isProduction,
  );

  debugPrint('SmartERP avviato -> ${AppConfig.environmentLabel}'
      ' | URL: ${AppConfig.supabaseUrl}');

  runApp(const SmartErpApp());
}

/// Accesso rapido al client Supabase ovunque nell'app.
final SupabaseClient supabase = Supabase.instance.client;

class SmartErpApp extends StatelessWidget {
  const SmartErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0D47A1),
      ),
      home: const ConnectionCheckPage(),
    );
  }
}

/// Pagina diagnostica: verifica che il backend Docker risponda.
class ConnectionCheckPage extends StatelessWidget {
  const ConnectionCheckPage({super.key});

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
              FutureBuilder(
                future: supabase.from('companies').select('id,name').limit(1),
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
