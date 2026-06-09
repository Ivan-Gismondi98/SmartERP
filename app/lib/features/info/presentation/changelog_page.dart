// ============================================================
//  SMARTERP · changelog_page.dart — novità e correzioni per versione.
// ============================================================
import 'package:flutter/material.dart';

import '../../../core/app_info.dart';
import '../../../core/widgets/smart_erp_logo.dart';

class _Release {
  const _Release(this.version, this.date, this.changes);
  final String version;
  final String date;
  final List<String> changes;
}

const _releases = <_Release>[
  _Release('2026.06.09.1', '09/06/2026', [
    '🎨 Nuova interfaccia: tema moderno, più colorato e responsive, nuovo logo.',
    '🧾 Report dedicato per ogni applicativo con filtri e selezione righe.',
    '⬇️ Esportazione in Excel, CSV, XML, PDF e Word dei dati selezionati.',
    '⬆️ Import da Excel/CSV con colonne speculari (anche documenti con righe e collegamenti).',
    '🧪 Ambiente di prova per organizzazione (dati demo attivabili dallo sviluppatore).',
    '🧩 Pacchetti di licenze predefiniti duplicabili per ogni cliente.',
    '🔔 Segnalazioni: la lista mostra solo le attive; sezione Report per tutte.',
  ]),
  _Release('2026.05.xx', 'Rilasci precedenti', [
    'Nuovi applicativi: CRM, Contabilità, Documenti, Produzione, Acquisti, Manutenzione, Progetti.',
    'Vendite con preventivi/ordini ed export PDF/Word dei preventivi.',
    'Gestione licenze per applicativo, impersonate sviluppatore, branding aziendale.',
  ]),
];

class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Novità e changelog')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Row(
            children: [
              SmartErpLogo(size: 44),
              Spacer(),
              Chip(label: Text('v${AppInfo.version}')),
            ],
          ),
          const SizedBox(height: 8),
          Text('Tutte le novità e le correzioni, versione per versione.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          for (final r in _releases) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.new_releases_outlined,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Versione ${r.version}',
                            style: theme.textTheme.titleMedium),
                        const Spacer(),
                        Text(r.date, style: theme.textTheme.bodySmall),
                      ],
                    ),
                    const Divider(height: 20),
                    for (final c in r.changes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  '),
                            Expanded(child: Text(c)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
