// ============================================================
//  SMARTERP · purchase_form_page.dart — editor bozza documento di acquisto.
//  Righe con calcolo IVA/totali live (standard italiani), lato fornitore.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../invoices/domain/vat.dart';
import '../../products/application/products_providers.dart';
import '../../products/domain/product.dart';
import '../../profile/application/profile_providers.dart';
import '../../suppliers/data/suppliers_repository.dart';
import '../data/purchases_repository.dart';
import '../domain/purchase_document.dart';

class PurchaseFormPage extends ConsumerStatefulWidget {
  const PurchaseFormPage({super.key, this.documentId});
  final String? documentId;

  @override
  ConsumerState<PurchaseFormPage> createState() => _PurchaseFormPageState();
}

class _PurchaseFormPageState extends ConsumerState<PurchaseFormPage> {
  PurchaseDocument? _draft;
  bool _saving = false;
  String? _loadError;

  late final TextEditingController _supplierRef;
  late final TextEditingController _paymentTerms;
  late final TextEditingController _notes;

  bool get _isNew => widget.documentId == null;

  @override
  void initState() {
    super.initState();
    _supplierRef = TextEditingController();
    _paymentTerms = TextEditingController();
    _notes = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _supplierRef.dispose();
    _paymentTerms.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (widget.documentId != null) {
        final doc = await ref
            .read(purchasesRepositoryProvider)
            .getById(widget.documentId!);
        _supplierRef.text = doc.supplierRef ?? '';
        _paymentTerms.text = doc.paymentTerms ?? '';
        _notes.text = doc.notes ?? '';
        setState(() => _draft = doc);
      } else {
        final profile = await ref.read(currentProfileProvider.future);
        final companyId = profile?.companyId;
        if (companyId == null) {
          setState(() => _loadError = 'Nessuna azienda associata al profilo.');
          return;
        }
        setState(() {
          _draft = PurchaseDocument(
            companyId: companyId,
            items: [PurchaseItem()],
          );
        });
      }
    } catch (e) {
      setState(() => _loadError = '$e');
    }
  }

  void _recompute() => setState(() {});
  void _addItem() => setState(() => _draft!.items.add(PurchaseItem(vatRate: 22)));
  void _removeItem(int i) => setState(() => _draft!.items.removeAt(i));

  Future<void> _save() async {
    final doc = _draft!;
    if (doc.supplierId == null) {
      _snack('Seleziona un fornitore.');
      return;
    }
    if (doc.items.isEmpty || doc.items.every((it) => it.description.isEmpty)) {
      _snack('Aggiungi almeno una riga con descrizione.');
      return;
    }
    for (final it in doc.items) {
      if (it.vatRate == 0 && it.vatNature == null) {
        _snack('Indica la Natura IVA sulle righe con aliquota 0%.');
        return;
      }
    }
    doc.supplierRef = _supplierRef.text;
    doc.paymentTerms = _paymentTerms.text;
    doc.notes = _notes.text;

    setState(() => _saving = true);
    try {
      final repo = ref.read(purchasesRepositoryProvider);
      if (_isNew) {
        await repo.createDraft(doc);
      } else {
        await repo.updateDraft(doc);
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
        appBar: AppBar(title: const Text('Documento di acquisto')),
        body: Center(child: Text('Errore: $_loadError')),
      );
    }
    if (_draft == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final doc = _draft!;
    final suppliersAsync = ref.watch(suppliersListProvider);
    final products = ref.watch(productsListProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew
            ? 'Nuovo ${doc.kind.label.toLowerCase()}'
            : 'Modifica ${doc.kind.label.toLowerCase()}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<PurchaseKind>(
            segments: const [
              ButtonSegment(
                  value: PurchaseKind.offer,
                  label: Text('Offerta'),
                  icon: Icon(Icons.request_quote_outlined)),
              ButtonSegment(
                  value: PurchaseKind.order,
                  label: Text('Ordine'),
                  icon: Icon(Icons.shopping_bag_outlined)),
              ButtonSegment(
                  value: PurchaseKind.contract,
                  label: Text('Contratto'),
                  icon: Icon(Icons.gavel_outlined)),
            ],
            selected: {doc.kind},
            onSelectionChanged: (s) => setState(() => doc.kind = s.first),
          ),
          const SizedBox(height: 12),
          suppliersAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Errore fornitori: $e'),
            data: (suppliers) => DropdownButtonFormField<String>(
              initialValue: doc.supplierId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Fornitore *'),
              items: [
                for (final s in suppliers)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (id) => setState(() {
                doc.supplierId = id;
                doc.supplier = suppliers.firstWhere((s) => s.id == id);
              }),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Data documento',
                  value: doc.issueDate,
                  onChanged: (d) => setState(() => doc.issueDate = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: doc.kind == PurchaseKind.contract
                      ? 'Scadenza contratto'
                      : 'Validità / consegna',
                  value: doc.validUntil,
                  onChanged: (d) => setState(() => doc.validUntil = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _supplierRef,
            decoration: const InputDecoration(
                labelText: 'Riferimento fornitore (n. offerta/contratto)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _paymentTerms,
            decoration: const InputDecoration(
                labelText: 'Condizioni di pagamento'),
          ),
          const Divider(height: 32),
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
          for (var i = 0; i < doc.items.length; i++)
            _ItemEditor(
              key: ValueKey('item_${doc.items[i].hashCode}'),
              item: doc.items[i],
              products: products,
              onChanged: _recompute,
              onRemove: doc.items.length > 1 ? () => _removeItem(i) : null,
            ),
          const Divider(height: 32),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          const Divider(height: 32),
          _LiveTotals(doc: doc),
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

class _ItemEditor extends StatefulWidget {
  const _ItemEditor({
    super.key,
    required this.item,
    required this.products,
    required this.onChanged,
    this.onRemove,
  });

  final PurchaseItem item;
  final List<Product> products;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final TextEditingController _desc;
  late final TextEditingController _qty;
  late final TextEditingController _price;
  late final TextEditingController _disc;

  PurchaseItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    _desc = TextEditingController(text: item.description);
    _qty = TextEditingController(
        text: item.quantity == 0 ? '' : Fmt.qty(item.quantity));
    _price = TextEditingController(
        text: item.unitPrice == 0 ? '' : Fmt.amount(item.unitPrice));
    _disc = TextEditingController(
        text: item.discountPercent == 0 ? '' : Fmt.qty(item.discountPercent));
  }

  @override
  void dispose() {
    for (final c in [_desc, _qty, _price, _disc]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pickProduct(String? id) {
    setState(() {
      if (id == null) {
        item.productId = null;
        return;
      }
      final p = widget.products.firstWhere((e) => e.id == id);
      final desc = (p.description != null && p.description!.trim().isNotEmpty)
          ? p.description!.trim()
          : p.name;
      item.productId = p.id;
      item.description = desc;
      item.unitPrice = p.unitPrice;
      item.vatRate = p.vatRate;
      if (p.vatRate != 0) item.vatNature = null;
      _desc.text = desc;
      _price.text = p.unitPrice == 0 ? '' : Fmt.amount(p.unitPrice);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (widget.products.isNotEmpty)
              DropdownButtonFormField<String?>(
                initialValue: item.productId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Prodotto a catalogo',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('— Riga libera —')),
                  for (final p in widget.products)
                    DropdownMenuItem<String?>(
                      value: p.id,
                      child: Text('${p.name} (giac. ${p.quantity})',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _pickProduct,
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _desc,
                    decoration:
                        const InputDecoration(labelText: 'Descrizione'),
                    onChanged: (v) {
                      item.description = v;
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qty,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Qtà'),
                    onChanged: (v) {
                      item.quantity = Fmt.parseAmount(v) ?? 0;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Prezzo unit.'),
                    onChanged: (v) {
                      item.unitPrice = Fmt.parseAmount(v) ?? 0;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _disc,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Sconto %'),
                    onChanged: (v) {
                      item.discountPercent = Fmt.parseAmount(v) ?? 0;
                      widget.onChanged();
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
                        DropdownMenuItem(value: r, child: Text(Fmt.percent(r))),
                    ],
                    onChanged: (v) {
                      setState(() {
                        item.vatRate = v ?? 22;
                        if (item.vatRate != 0) item.vatNature = null;
                      });
                      widget.onChanged();
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
                        setState(() => item.vatNature = v);
                        widget.onChanged();
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
  const _LiveTotals({required this.doc});
  final PurchaseDocument doc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final l in doc.vatSummary)
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
        _row(theme, 'Imponibile', Fmt.euro(doc.subtotal)),
        _row(theme, 'IVA', Fmt.euro(doc.taxAmount)),
        _row(theme, 'TOTALE', Fmt.euro(doc.total), bold: true),
      ],
    );
  }

  Widget _row(ThemeData theme, String l, String v, {bool bold = false}) {
    final style = bold ? theme.textTheme.titleLarge : theme.textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(l, style: style), Text(v, style: style)],
      ),
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
