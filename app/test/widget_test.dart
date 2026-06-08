// Smoke test: l'app si avvia e, in caso di errore di init backend,
// mostra la pagina diagnostica senza dipendere dalla rete.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smarterp/app.dart';

void main() {
  testWidgets('Mostra la pagina diagnostica se init backend fallisce',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartErpApp(initError: 'backend non raggiungibile'),
      ),
    );

    expect(find.text('SmartERP · Connessione'), findsOneWidget);
    expect(find.text('Ambiente: LOCAL (docker)'), findsOneWidget);
  });
}
