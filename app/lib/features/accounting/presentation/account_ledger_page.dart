// ============================================================
//  SMARTERP · account_ledger_page.dart — mastrino (estratto conto)
//  di un singolo conto, con saldo progressivo.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../application/accounting_providers.dart';

class AccountLedgerPage extends ConsumerWidget {
  const AccountLedgerPage(
      {super.key, required this.accountId, required this.title});
  final String accountId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ledgerProvider(accountId));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Mastrino · $title')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (movs) {
          if (movs.isEmpty) {
            return const Center(child: Text('Nessun movimento.'));
          }
          var running = 0.0;
          final totDare = movs.fold<double>(0, (s, m) => s + m.debit);
          final totAvere = movs.fold<double>(0, (s, m) => s + m.credit);
          return ListView(
            children: [
              for (final m in movs)
                Builder(builder: (context) {
                  running = round2(running + m.debit - m.credit);
                  return ListTile(
                    dense: true,
                    title: Text(
                        '${Fmt.date(m.date)}'
                        '${m.entryNumber != null ? '  ·  n. ${m.entryNumber}' : ''}'),
                    subtitle: Text(m.description ?? ''),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                            (m.debit > 0 ? 'D ${Fmt.amount(m.debit)}' : '') +
                                (m.credit > 0
                                    ? '  A ${Fmt.amount(m.credit)}'
                                    : ''),
                            style: theme.textTheme.bodySmall),
                        Text('Saldo ${Fmt.amount(running)}',
                            style: theme.textTheme.titleSmall),
                      ],
                    ),
                  );
                }),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                    'Totale Dare ${Fmt.euro(totDare)}   ·   '
                    'Totale Avere ${Fmt.euro(totAvere)}   ·   '
                    'Saldo ${Fmt.euro(round2(totDare - totAvere))}',
                    style: theme.textTheme.titleMedium),
              ),
            ],
          );
        },
      ),
    );
  }
}
