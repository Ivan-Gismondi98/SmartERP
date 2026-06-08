// ============================================================
//  SMARTERP · invoice_form_page.dart — editor bozza fattura.
//  Righe modificabili con calcolo IVA/totali live (standard italiani).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../customers/application/customers_providers.dart';
import '../../customers/domain/customer.dart';
import '../../profile/application/profile_providers.dart';
import '../data/invoices_repository.dart';
import '../domain/invoice.dart';
import '../domain/vat.dart';

class InvoiceFormPage extends ConsumerStatefulWidget {
  const InvoiceFormPage({super.key, this.invoiceId});
  final String? invoiceId;

  @override
  ConsumerState<InvoiceFormPage> createState() => _InvoiceFormPageState();
}

class _InvoiceFormPageState extends ConsumerState<InvoiceFormPage> {
  Invoice? _draft;
  bool _saving = false;
  String? _loadError;

  bool get _isNew => widget.invoiceId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.invoiceId != null) {
        final inv =
            await ref.read(invoicesRepositoryProvider).getById(widget.invoiceId!);
        setState(() => _draft = inv);
      } else {
        final profile = await ref.read(currentProfileProvider.future);
        final companyId = profile?.companyId;
        if (companyId == null) {
          setState(() => _loadError = 'Nessuna azienda associata al profilo.');
          return;
        }
        setState(() {
          _draft = Invoice(
            companyId: companyId,
            items: [InvoiceItem()],
          );
        });
      }
    } catch (e) {
      setState(() => _loadError = '$e');
    }
  }

  void _recompute() => setState(() {});

  void _addItem() {
    setState(() => _draft!.items.add(InvoiceItem(vatRate: 22)));
  }

  void _removeItem(int i) {
    setState(() => _draft!.items.removeAt(i));
  }

  Future<void> _save() async {
    final inv = _draft!;
    if (inv.customerId == null) {
      _snack('Seleziona un cliente.');
      return;
    }
    if (inv.items.isEmpty || inv.items.every((it) => it.description.isEmpty)) {
      _snack('Aggiungi almeno una riga con descrizione.');
      return;
    }
    // Natura obbligatoria sulle righe a 0%.
    for (final it in inv.items) {
      if (it.vatRate == 0 && it.vatNature == null) {
        _snack('Indica la Natura IVA sulle righe con aliquota 0%.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(invoicesRepositoryProvider);
      if (_isNew) {
        await repo.createDraft(inv);
      } else {
        await repo.updateDraft(inv);
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
        appBar: AppBar(title: const Text('Fattura')),
        body: Center(child: Text('Errore: $_loadError')),
      );
    }
    if (_draft == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final inv = _draft!;
    final customersAsync = ref.watch(customersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nuova fattura' : 'Modifica fattura'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Cliente ---
          customersAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Errore clienti: $e'),
            data: (customers) => DropdownButtonFormField<String>(
              initialValue: inv.customerId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Cliente *'),
              items: [
                for (final c in customers)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (id) => setState(() {
                inv.customerId = id;
                inv.customer = customers.firstWhere((c) => c.id == id,
                    orElse: () => customers.first) as Customer?;
              }),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Data documento',
                  value: inv.issueDate,
                  onChanged: (d) => setState(() => inv.issueDate = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Scadenza',
                  value: inv.dueDate,
                  onChanged: (d) => setState(() => inv.dueDate = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NumField(
            label: 'Giorni alla scadenza (calcola la data)',
            value: (inv.paymentTermsDays ?? 0).toDouble(),
            onChanged: (v) => setState(() {
              final days = v?.round();
              inv.paymentTermsDays = days;
              if (days != null && days > 0) {
                inv.dueDate = inv.issueDate.add(Duration(days: days));
              }
            }),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Interessi di mora se scaduta'),
            subtitle: const Text(
                'Applica un tasso annuo sul ritardo di pagamento'),
            value: inv.interestEnabled,
            onChanged: (v) => setState(() => inv.interestEnabled = v),
          ),
          if (inv.interestEnabled)
            _NumField(
              label: 'Tasso annuo % di mora',
              value: inv.interestRate ?? 0,
              onChanged: (v) => setState(() => inv.interestRate = v),
            ),
          const Divider(height: 32),

          // --- Righe ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Righe', style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi riga'),
              ),
            ],
          ),
          for (var i = 0; i < inv.items.length; i++)
            _ItemEditor(
              key: ValueKey('item_${inv.items[i].hashCode}'),
              item: inv.items[i],
              onChanged: _recompute,
              onRemove: inv.items.length > 1 ? () => _removeItem(i) : null,
            ),

          const Divider(height: 32),

          // --- Bollo / arrotondamento ---
          if (inv.stampDutyDue && inv.stampDuty == 0)
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Imponibile esente > € 77,47'),
                subtitle: const Text('E\' dovuta l\'imposta di bollo di € 2,00.'),
                trailing: TextButton(
                  onPressed: () => setState(() => inv.stampDuty = 2.0),
                  child: const Text('Applica bollo'),
                ),
              ),
            ),
          _MoneyField(
            label: 'Bollo (€)',
            value: inv.stampDuty,
            onChanged: (v) => setState(() => inv.stampDuty = v ?? 0),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: inv.notes ?? '',
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Note'),
            onChanged: (v) => inv.notes = v,
          ),

          const Divider(height: 32),
          _LiveTotals(inv: inv),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('Salva bozza'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  Editor di una singola riga.
// ============================================================
class _ItemEditor extends StatelessWidget {
  const _ItemEditor({
    super.key,
    required this.item,
    required this.onChanged,
    this.onRemove,
  });

  final InvoiceItem item;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

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
                  child: TextFormField(
                    initialValue: item.description,
                    decoration:
                        const InputDecoration(labelText: 'Descrizione'),
                    onChanged: (v) {
                      item.description = v;
                      onChanged();
                    },
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Rimuovi riga',
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _NumField(
                    label: 'Qtà',
                    value: item.quantity,
                    onChanged: (v) {
                      item.quantity = v ?? 0;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _MoneyField(
                    label: 'Prezzo unit.',
                    value: item.unitPrice,
                    onChanged: (v) {
                      item.unitPrice = v ?? 0;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumField(
                    label: 'Sconto %',
                    value: item.discountPercent,
                    onChanged: (v) {
                      item.discountPercent = v ?? 0;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<double>(
                    initialValue: item.vatRate,
                    decoration: const InputDecoration(labelText: 'Aliquota IVA'),
                    items: [
                      for (final r in kVatRates)
                        DropdownMenuItem(
                            value: r, child: Text(Fmt.percent(r))),
                    ],
                    onChanged: (v) {
                      item.vatRate = v ?? 22;
                      if (item.vatRate != 0) item.vatNature = null;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (item.vatRate == 0)
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<VatNature>(
                      initialValue: item.vatNature,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Natura'),
                      items: [
                        for (final n in VatNature.values)
                          DropdownMenuItem(
                              value: n,
                              child: Text('${n.code} – ${n.label}',
                                  overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) {
                        item.vatNature = v;
                        onChanged();
                      },
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(Fmt.euro(item.taxableBase),
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveTotals extends StatelessWidget {
  const _LiveTotals({required this.inv});
  final Invoice inv;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final l in inv.vatSummary)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'Imponibile ${l.vatRate == 0 ? (l.nature?.code ?? '0%') : Fmt.percent(l.vatRate)}'),
                Text('${Fmt.euro(l.taxable)}   IVA ${Fmt.euro(l.tax)}'),
              ],
            ),
          ),
        const Divider(),
        _row(theme, 'Imponibile', Fmt.euro(inv.subtotal)),
        _row(theme, 'IVA', Fmt.euro(inv.taxAmount)),
        if (inv.stampDuty > 0) _row(theme, 'Bollo', Fmt.euro(inv.stampDuty)),
        _row(theme, 'TOTALE', Fmt.euro(inv.total), bold: true),
      ],
    );
  }

  Widget _row(ThemeData theme, String l, String v, {bool bold = false}) {
    final style =
        bold ? theme.textTheme.titleLarge : theme.textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(l, style: style), Text(v, style: style)],
      ),
    );
  }
}

// ============================================================
//  Campi riutilizzabili.
// ============================================================
class _MoneyField extends StatelessWidget {
  const _MoneyField(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final double value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value == 0 ? '' : Fmt.amount(value),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (v) => onChanged(Fmt.parseAmount(v)),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final double value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value == 0 ? '' : Fmt.qty(value),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (v) => onChanged(Fmt.parseAmount(v)),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value == null ? '—' : Fmt.date(value)),
      ),
    );
  }
}
