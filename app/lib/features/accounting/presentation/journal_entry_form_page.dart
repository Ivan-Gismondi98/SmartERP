// ============================================================
//  SMARTERP · journal_entry_form_page.dart — editor registrazione di
//  prima nota in partita doppia. Salvataggio consentito solo se quadrata
//  (totale dare = totale avere). Alla creazione assegna il n. progressivo.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../profile/application/profile_providers.dart';
import '../application/accounting_providers.dart';
import '../data/accounting_repository.dart';
import '../domain/account.dart';
import '../domain/cost_center.dart';
import '../domain/journal_entry.dart';

class JournalEntryFormPage extends ConsumerStatefulWidget {
  const JournalEntryFormPage({super.key, this.entryId});
  final String? entryId;

  @override
  ConsumerState<JournalEntryFormPage> createState() =>
      _JournalEntryFormPageState();
}

class _JournalEntryFormPageState extends ConsumerState<JournalEntryFormPage> {
  JournalEntry? _draft;
  bool _saving = false;
  String? _loadError;

  late final TextEditingController _description;
  late final TextEditingController _docRef;

  bool get _isNew => widget.entryId == null;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController();
    _docRef = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    _docRef.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (widget.entryId != null) {
        final e = await ref.read(accountingRepositoryProvider).getEntry(widget.entryId!);
        _description.text = e.description;
        _docRef.text = e.docRef ?? '';
        setState(() => _draft = e);
      } else {
        final profile = await ref.read(currentProfileProvider.future);
        final companyId = profile?.companyId;
        if (companyId == null) {
          setState(() => _loadError = 'Nessuna azienda associata al profilo.');
          return;
        }
        setState(() {
          _draft = JournalEntry(
            companyId: companyId,
            lines: [JournalLine(), JournalLine()],
          );
        });
      }
    } catch (e) {
      setState(() => _loadError = '$e');
    }
  }

  void _recompute() => setState(() {});

  void _addLine() => setState(() => _draft!.lines.add(JournalLine()));
  void _removeLine(int i) => setState(() => _draft!.lines.removeAt(i));

  Future<void> _save() async {
    final e = _draft!;
    e.description = _description.text;
    e.docRef = _docRef.text;
    if (e.description.trim().isEmpty) {
      _snack('Inserisci una descrizione (causale).');
      return;
    }
    if (e.lines.any((l) => l.accountId == null)) {
      _snack('Seleziona il conto su ogni riga.');
      return;
    }
    if (!e.isBalanced) {
      _snack('La registrazione non quadra: dare ≠ avere.');
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(accountingRepositoryProvider);
      if (_isNew) {
        final id = await repo.createEntry(e);
        await repo.assignNumber(id);
      } else {
        await repo.updateEntry(e);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      _snack('Errore nel salvataggio: $e');
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registrazione')),
        body: Center(child: Text('Errore: $_loadError')),
      );
    }
    if (_draft == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final e = _draft!;
    final accounts = ref.watch(accountsListProvider).valueOrNull ?? const [];
    final costCenters =
        ref.watch(costCentersListProvider).valueOrNull ?? const [];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew
            ? 'Nuova registrazione'
            : 'Registrazione ${e.displayNumber}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Data registrazione',
                  value: e.entryDate,
                  onChanged: (d) => setState(() => e.entryDate = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _docRef,
                  decoration: const InputDecoration(
                      labelText: 'Documento (es. Ft. 12/2026)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Causale *'),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Movimenti', style: theme.textTheme.titleMedium),
              TextButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi riga'),
              ),
            ],
          ),
          for (var i = 0; i < e.lines.length; i++)
            _LineEditor(
              key: ValueKey('line_${e.lines[i].hashCode}'),
              line: e.lines[i],
              accounts: accounts,
              costCenters: costCenters,
              onChanged: _recompute,
              onRemove: e.lines.length > 2 ? () => _removeLine(i) : null,
            ),
          const Divider(height: 32),
          _BalanceBox(entry: e),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_isNew ? 'Registra' : 'Salva'),
          ),
        ],
      ),
    );
  }
}

class _LineEditor extends StatefulWidget {
  const _LineEditor({
    super.key,
    required this.line,
    required this.accounts,
    required this.costCenters,
    required this.onChanged,
    this.onRemove,
  });

  final JournalLine line;
  final List<Account> accounts;
  final List<CostCenter> costCenters;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  State<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<_LineEditor> {
  late final TextEditingController _desc;
  late final TextEditingController _debit;
  late final TextEditingController _credit;

  JournalLine get line => widget.line;

  @override
  void initState() {
    super.initState();
    _desc = TextEditingController(text: line.description ?? '');
    _debit =
        TextEditingController(text: line.debit == 0 ? '' : Fmt.amount(line.debit));
    _credit = TextEditingController(
        text: line.credit == 0 ? '' : Fmt.amount(line.credit));
  }

  @override
  void dispose() {
    _desc.dispose();
    _debit.dispose();
    _credit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: line.accountId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Conto *', isDense: true),
                    items: [
                      for (final a in widget.accounts)
                        DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.code} ${a.name}',
                                overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (id) {
                      setState(() => line.accountId = id);
                      widget.onChanged();
                    },
                  ),
                ),
                if (widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Rimuovi riga',
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _desc,
              decoration:
                  const InputDecoration(labelText: 'Descrizione', isDense: true),
              onChanged: (v) => line.description = v,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _debit,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Dare', isDense: true),
                    onChanged: (v) {
                      line.debit = Fmt.parseAmount(v) ?? 0;
                      if (line.debit > 0 && line.credit > 0) {
                        line.credit = 0;
                        _credit.text = '';
                      }
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _credit,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Avere', isDense: true),
                    onChanged: (v) {
                      line.credit = Fmt.parseAmount(v) ?? 0;
                      if (line.credit > 0 && line.debit > 0) {
                        line.debit = 0;
                        _debit.text = '';
                      }
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            ),
            if (widget.costCenters.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: line.costCenterId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Centro di costo (analitica)', isDense: true),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('—')),
                  for (final c in widget.costCenters)
                    DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.code} ${c.name}',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (id) {
                  setState(() => line.costCenterId = id);
                  widget.onChanged();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BalanceBox extends StatelessWidget {
  const _BalanceBox({required this.entry});
  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balanced = entry.isBalanced;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Totale Dare', style: theme.textTheme.bodyLarge),
            Text(Fmt.euro(entry.totalDebit), style: theme.textTheme.bodyLarge),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Totale Avere', style: theme.textTheme.bodyLarge),
            Text(Fmt.euro(entry.totalCredit), style: theme.textTheme.bodyLarge),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: balanced
                ? Colors.green.withValues(alpha: 0.12)
                : theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(balanced ? Icons.check_circle : Icons.error_outline,
                  color: balanced ? Colors.green : theme.colorScheme.error),
              const SizedBox(width: 8),
              Text(
                balanced
                    ? 'Registrazione quadrata'
                    : 'Sbilancio: ${Fmt.euro(entry.balanceDiff.abs())}',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(Fmt.date(value)),
      ),
    );
  }
}
