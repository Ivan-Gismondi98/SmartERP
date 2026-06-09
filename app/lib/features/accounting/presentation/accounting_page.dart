// ============================================================
//  SMARTERP · accounting_page.dart — hub Contabilità a schede:
//  Prima nota · Piano dei conti · Bilancio di verifica.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../../core/reporting/entity_report_page.dart';
import '../../profile/application/profile_providers.dart';
import '../application/accounting_import_export.dart';
import '../application/accounting_providers.dart';
import '../application/accounting_report.dart';
import '../data/accounting_repository.dart';
import '../domain/account.dart';
import '../domain/journal_entry.dart';
import 'account_ledger_page.dart';
import 'cost_centers_page.dart';
import 'journal_entry_form_page.dart';

class AccountingPage extends ConsumerStatefulWidget {
  const AccountingPage({super.key});

  @override
  ConsumerState<AccountingPage> createState() => _AccountingPageState();
}

class _AccountingPageState extends ConsumerState<AccountingPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(canProvider(Perm.accountingCreate));
    final canManage = ref.watch(canProvider(Perm.accountingManage));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contabilità'),
        actions: [
          IconButton(
            tooltip: 'Report / Export prima nota',
            icon: const Icon(Icons.assessment_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    EntityReportPage<JournalEntry>(spec: accountingReportSpec))),
          ),
          IconButton(
            tooltip: 'Importa / Esporta prima nota (righe)',
            icon: const Icon(Icons.import_export),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => EntityReportPage<JournalLineRow>(
                    spec: accountingLinesSpec))),
          ),
          if (canManage)
            IconButton(
              tooltip: 'Centri di costo',
              icon: const Icon(Icons.account_tree_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CostCentersPage())),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Prima nota'),
            Tab(text: 'Piano dei conti'),
            Tab(text: 'Bilancio'),
          ],
        ),
      ),
      floatingActionButton: _fab(context, canCreate, canManage),
      body: TabBarView(
        controller: _tab,
        children: const [
          _JournalTab(),
          _AccountsTab(),
          _TrialBalanceTab(),
        ],
      ),
    );
  }

  Widget? _fab(BuildContext context, bool canCreate, bool canManage) {
    if (_tab.index == 0 && canCreate) {
      return FloatingActionButton.extended(
        onPressed: () => _openEntry(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Registrazione'),
      );
    }
    if (_tab.index == 1 && canManage) {
      return FloatingActionButton.extended(
        onPressed: () => _editAccount(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Conto'),
      );
    }
    return null;
  }

  Future<void> _openEntry(BuildContext context, String? id) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => JournalEntryFormPage(entryId: id)),
    );
    if (changed == true) {
      ref.invalidate(journalEntriesProvider);
      ref.invalidate(trialBalanceProvider);
    }
  }

  Future<void> _editAccount(BuildContext context, Account? a) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AccountEditorDialog(account: a),
    );
    if (saved == true) ref.invalidate(accountsListProvider);
  }
}

// ============================================================
//  TAB — Prima nota
// ============================================================
class _JournalTab extends ConsumerWidget {
  const _JournalTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(journalEntriesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore: $e')),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(child: Text('Nessuna registrazione.'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(journalEntriesProvider),
          child: ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = entries[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(e.displayNumber.split('/').first,
                      style: const TextStyle(fontSize: 12)),
                ),
                title: Text(
                    '${e.displayNumber} · ${Fmt.date(e.entryDate)}',
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    '${e.description}${e.docRef != null ? '  ·  ${e.docRef}' : ''}'),
                trailing: Text(Fmt.euro(e.totalDebit),
                    style: Theme.of(context).textTheme.titleMedium),
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                        builder: (_) => JournalEntryFormPage(entryId: e.id)),
                  );
                  if (changed == true) {
                    ref.invalidate(journalEntriesProvider);
                    ref.invalidate(trialBalanceProvider);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

// ============================================================
//  TAB — Piano dei conti
// ============================================================
class _AccountsTab extends ConsumerWidget {
  const _AccountsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountsListProvider);
    final canManage = ref.watch(canProvider(Perm.accountingManage));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore: $e')),
      data: (accounts) {
        if (accounts.isEmpty) {
          return const Center(child: Text('Piano dei conti vuoto.'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(accountsListProvider),
          child: ListView(
            children: [
              for (final nature in AccountNature.values)
                ..._section(context, ref, nature,
                    accounts.where((a) => a.nature == nature).toList(),
                    canManage),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _section(BuildContext context, WidgetRef ref,
      AccountNature nature, List<Account> items, bool canManage) {
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(nature.label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium),
      ),
      for (final a in items)
        ListTile(
          dense: true,
          leading: Text(a.code,
              style: Theme.of(context).textTheme.bodySmall),
          title: Text(a.name),
          trailing: canManage
              ? PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      final saved = await showDialog<bool>(
                        context: context,
                        builder: (_) => AccountEditorDialog(account: a),
                      );
                      if (saved == true) ref.invalidate(accountsListProvider);
                    } else if (v == 'delete') {
                      await _delete(context, ref, a);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifica')),
                    PopupMenuItem(value: 'delete', child: Text('Elimina')),
                  ],
                )
              : null,
        ),
    ];
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Account a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Eliminare il conto ${a.code}?'),
        content: const Text(
            'Non sarà possibile se il conto è già usato in registrazioni.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(accountingRepositoryProvider).deleteAccount(a.id!);
      ref.invalidate(accountsListProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conto in uso: impossibile eliminarlo.')));
      }
    }
  }
}

// ============================================================
//  TAB — Bilancio di verifica
// ============================================================
class _TrialBalanceTab extends ConsumerWidget {
  const _TrialBalanceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trialBalanceProvider);
    final theme = Theme.of(context);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore: $e')),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(child: Text('Nessun movimento contabile.'));
        }
        final totDare = rows.fold<double>(0, (s, r) => s + r.debit);
        final totAvere = rows.fold<double>(0, (s, r) => s + r.credit);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(trialBalanceProvider),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(4),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(2),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest),
                    children: const [
                      Padding(
                          padding: EdgeInsets.all(6),
                          child: Text('Conto',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(
                          padding: EdgeInsets.all(6),
                          child: Text('Dare',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(
                          padding: EdgeInsets.all(6),
                          child: Text('Avere',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(
                          padding: EdgeInsets.all(6),
                          child: Text('Saldo',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  for (final r in rows)
                    TableRow(children: [
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: InkWell(
                          onTap: () => _openLedger(context, ref, r.accountCode,
                              r.accountName),
                          child: Text('${r.accountCode} ${r.accountName}',
                              style: const TextStyle(
                                  decoration: TextDecoration.underline)),
                        ),
                      ),
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(Fmt.amount(r.debit),
                              textAlign: TextAlign.right)),
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(Fmt.amount(r.credit),
                              textAlign: TextAlign.right)),
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(Fmt.amount(r.balance),
                              textAlign: TextAlign.right)),
                    ]),
                ],
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Totali', style: theme.textTheme.titleMedium),
                    Text('Dare ${Fmt.euro(totDare)}   ·   Avere ${Fmt.euro(totAvere)}',
                        style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
              if ((totDare - totAvere).abs() >= 0.01)
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                      '⚠ Sbilancio di ${Fmt.euro((totDare - totAvere).abs())}',
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openLedger(BuildContext context, WidgetRef ref, String code,
      String name) async {
    final accounts = ref.read(accountsListProvider).valueOrNull ?? const [];
    final acc = accounts.where((a) => a.code == code).toList();
    if (acc.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            AccountLedgerPage(accountId: acc.first.id!, title: '$code $name')));
  }
}

// ============================================================
//  Dialog editor conto del piano dei conti.
// ============================================================
class AccountEditorDialog extends ConsumerStatefulWidget {
  const AccountEditorDialog({super.key, this.account});
  final Account? account;

  @override
  ConsumerState<AccountEditorDialog> createState() =>
      _AccountEditorDialogState();
}

class _AccountEditorDialogState extends ConsumerState<AccountEditorDialog> {
  late final TextEditingController _code;
  late final TextEditingController _name;
  AccountNature _nature = AccountNature.costo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.account?.code ?? '');
    _name = TextEditingController(text: widget.account?.name ?? '');
    _nature = widget.account?.nature ?? AccountNature.costo;
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_code.text.trim().isEmpty || _name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(accountingRepositoryProvider);
      final existing = widget.account;
      if (existing == null) {
        final profile = await ref.read(currentProfileProvider.future);
        final companyId = profile?.companyId;
        if (companyId == null) throw 'Nessuna azienda associata';
        await repo.createAccount(Account(
          companyId: companyId,
          code: _code.text,
          name: _name.text,
          nature: _nature,
        ));
      } else {
        existing
          ..code = _code.text
          ..name = _name.text
          ..nature = _nature;
        await repo.updateAccount(existing);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.account == null ? 'Nuovo conto' : 'Modifica conto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Codice *')),
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Denominazione *')),
            const SizedBox(height: 8),
            DropdownButtonFormField<AccountNature>(
              initialValue: _nature,
              decoration: const InputDecoration(labelText: 'Natura'),
              items: [
                for (final n in AccountNature.values)
                  DropdownMenuItem(value: n, child: Text(n.label)),
              ],
              onChanged: (v) =>
                  setState(() => _nature = v ?? AccountNature.costo),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Annulla')),
        FilledButton(
            onPressed: _busy ? null : _save, child: const Text('Salva')),
      ],
    );
  }
}

