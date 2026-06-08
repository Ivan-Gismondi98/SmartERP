// ============================================================
//  SMARTERP · product_form_page.dart — crea/modifica prodotto + giacenza.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../invoices/domain/vat.dart';
import '../../profile/application/profile_providers.dart';
import '../application/products_providers.dart';
import '../data/products_repository.dart';
import '../domain/bom_component.dart';
import '../domain/product.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key, this.product});
  final Product? product;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _description;
  late final TextEditingController _unit;
  late final TextEditingController _warehouse;

  late double _unitPrice;
  late double _vatRate;
  late int _quantity;
  late int _reorder;
  bool _saving = false;

  bool _isComposable = false;
  final List<BomComponent> _bom = [];
  bool _bomLoading = false;

  Product? get _existing => widget.product;

  @override
  void initState() {
    super.initState();
    final p = _existing;
    _name = TextEditingController(text: p?.name ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _unit = TextEditingController(text: p?.unit ?? 'pz');
    _warehouse = TextEditingController(text: p?.warehouseLocation ?? '');
    _unitPrice = p?.unitPrice ?? 0;
    _vatRate = p?.vatRate ?? 22;
    _quantity = p?.quantity ?? 0;
    _reorder = p?.reorderLevel ?? 0;
    _isComposable = p?.isComposable ?? false;
    if (_existing != null && _isComposable) _loadBom();
  }

  Future<void> _loadBom() async {
    setState(() => _bomLoading = true);
    try {
      final list = await ref.read(productsRepositoryProvider).getBom(_existing!.id);
      setState(() {
        _bom
          ..clear()
          ..addAll(list);
        _bomLoading = false;
      });
    } catch (_) {
      setState(() => _bomLoading = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _sku, _description, _unit, _warehouse]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = await ref.read(currentProfileProvider.future);
    final companyId = profile?.companyId;
    if (companyId == null) {
      _snack('Nessuna azienda associata.');
      return;
    }
    setState(() => _saving = true);
    final draft = Product(
      id: _existing?.id ?? '',
      companyId: companyId,
      name: _name.text.trim(),
      sku: _sku.text,
      description: _description.text,
      unitPrice: _unitPrice,
      vatRate: _vatRate,
      unit: _unit.text.trim().isEmpty ? 'pz' : _unit.text.trim(),
      isComposable: _isComposable,
      quantity: _quantity,
      reorderLevel: _reorder,
      warehouseLocation: _warehouse.text,
    );
    try {
      final repo = ref.read(productsRepositoryProvider);
      String productId;
      if (_existing == null) {
        productId = await repo.create(companyId, draft);
      } else {
        await repo.update(draft);
        productId = _existing!.id;
      }
      // Salva la distinta base (vuota se non componibile).
      await repo.replaceBom(
          companyId, productId, _isComposable ? _bom : <BomComponent>[]);
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

  void _addBomRow() {
    setState(() => _bom.add(BomComponent(componentId: '')));
  }

  Widget _buildBomSection() {
    final all = ref.watch(productsListProvider).valueOrNull ?? const <Product>[];
    final candidates = all.where((p) => p.id != _existing?.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Distinta base',
                style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: candidates.isEmpty ? null : _addBomRow,
              icon: const Icon(Icons.add),
              label: const Text('Componente'),
            ),
          ],
        ),
        if (_bomLoading) const LinearProgressIndicator(),
        if (candidates.isEmpty)
          const Text('Crea prima altri prodotti da usare come componenti.'),
        for (var i = 0; i < _bom.length; i++)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: _bom[i].componentId.isEmpty
                          ? null
                          : _bom[i].componentId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Componente', isDense: true),
                      items: [
                        for (final p in candidates)
                          DropdownMenuItem(
                            value: p.id,
                            child: Text('${p.name} (giac. ${p.quantity})',
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _bom[i].componentId = v ?? '';
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: Fmt.qty(_bom[i].quantity),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Qtà', isDense: true),
                      onChanged: (v) =>
                          _bom[i].quantity = Fmt.parseAmount(v) ?? 0,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _bom.removeAt(i)),
                  ),
                ],
              ),
            ),
          ),
        if (_existing != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _produceDialog,
            icon: const Icon(Icons.precision_manufacturing_outlined),
            label: const Text('Produci…'),
          ),
          Text(
            'La produzione usa la distinta base salvata: salva prima eventuali modifiche.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Future<void> _produceDialog() async {
    final ctrl = TextEditingController(text: '1');
    final qty = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Produci prodotto'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Quantità da produrre'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, Fmt.parseAmount(ctrl.text) ?? 0),
            child: const Text('Produci'),
          ),
        ],
      ),
    );
    if (qty == null || qty <= 0) return;
    try {
      await ref.read(productsRepositoryProvider).produce(_existing!.id, qty);
      ref.invalidate(productsListProvider);
      _snack('Prodotte $qty unità. Magazzino aggiornato.');
    } catch (e) {
      _snack('Produzione non riuscita: ${_cleanError(e)}');
    }
  }

  String _cleanError(Object e) {
    final m = e.toString();
    final idx = m.indexOf('insufficiente');
    return idx >= 0 ? m.substring(m.lastIndexOf('Componente')) : m;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_existing == null ? 'Nuovo prodotto' : 'Modifica prodotto')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sku,
                    decoration: const InputDecoration(labelText: 'SKU / Codice'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unit,
                    decoration:
                        const InputDecoration(labelText: 'Unità (pz, kg…)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Descrizione'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _unitPrice == 0 ? '' : Fmt.amount(_unitPrice),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Prezzo unitario €'),
                    onChanged: (v) => _unitPrice = Fmt.parseAmount(v) ?? 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<double>(
                    initialValue: _vatRate,
                    decoration: const InputDecoration(labelText: 'Aliquota IVA'),
                    items: [
                      for (final r in kVatRates)
                        DropdownMenuItem(value: r, child: Text(Fmt.percent(r))),
                    ],
                    onChanged: (v) => setState(() => _vatRate = v ?? 22),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text('Giacenza', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: '$_quantity',
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Quantità in giacenza'),
                    onChanged: (v) => _quantity = int.tryParse(v) ?? 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: '$_reorder',
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Scorta minima'),
                    onChanged: (v) => _reorder = int.tryParse(v) ?? 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _warehouse,
              decoration:
                  const InputDecoration(labelText: 'Ubicazione magazzino'),
            ),
            const Divider(height: 32),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Prodotto componibile (distinta base)'),
              subtitle: const Text(
                  'Si costruisce da altri prodotti/componenti del magazzino'),
              value: _isComposable,
              onChanged: (v) => setState(() => _isComposable = v),
            ),
            if (_isComposable) _buildBomSection(),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }
}
