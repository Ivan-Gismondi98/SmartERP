// ============================================================
//  SMARTERP · production_order_form_page.dart — editor ordine di produzione.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../profile/application/profile_providers.dart';
import '../application/production_providers.dart';
import '../data/production_repository.dart';
import '../domain/production_order.dart';

class ProductionOrderFormPage extends ConsumerStatefulWidget {
  const ProductionOrderFormPage({super.key, this.orderId});
  final String? orderId;

  @override
  ConsumerState<ProductionOrderFormPage> createState() =>
      _ProductionOrderFormPageState();
}

class _ProductionOrderFormPageState
    extends ConsumerState<ProductionOrderFormPage> {
  ProductionOrder? _draft;
  bool _saving = false;
  String? _loadError;

  late final TextEditingController _qty;
  late final TextEditingController _notes;

  bool get _isNew => widget.orderId == null;

  @override
  void initState() {
    super.initState();
    _qty = TextEditingController();
    _notes = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _qty.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (widget.orderId != null) {
        final o = await ref
            .read(productionRepositoryProvider)
            .getById(widget.orderId!);
        _qty.text = Fmt.qty(o.quantity);
        _notes.text = o.notes ?? '';
        setState(() => _draft = o);
      } else {
        final profile = await ref.read(currentProfileProvider.future);
        final companyId = profile?.companyId;
        if (companyId == null) {
          setState(() => _loadError = 'Nessuna azienda associata al profilo.');
          return;
        }
        _qty.text = '1';
        setState(() => _draft = ProductionOrder(
              companyId: companyId,
              plannedDate: DateTime.now(),
            ));
      }
    } catch (e) {
      setState(() => _loadError = '$e');
    }
  }

  Future<void> _save() async {
    final o = _draft!;
    if (o.productId == null) {
      _snack('Seleziona il prodotto da produrre.');
      return;
    }
    final qty = Fmt.parseAmount(_qty.text) ?? 0;
    if (qty <= 0) {
      _snack('Indica una quantità maggiore di zero.');
      return;
    }
    o.quantity = qty;
    o.notes = _notes.text;

    setState(() => _saving = true);
    try {
      final repo = ref.read(productionRepositoryProvider);
      if (_isNew) {
        await repo.create(o);
      } else {
        await repo.update(o);
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
        appBar: AppBar(title: const Text('Ordine di produzione')),
        body: Center(child: Text('Errore: $_loadError')),
      );
    }
    if (_draft == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final o = _draft!;
    final composable = ref.watch(composableProductsProvider);

    return Scaffold(
      appBar: AppBar(
          title: Text(_isNew ? 'Nuovo ordine' : 'Modifica ordine')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          composable.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Errore prodotti: $e'),
            data: (products) {
              if (products.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Nessun prodotto componibile'),
                    subtitle: Text(
                        'Imposta un prodotto come "componibile" e definisci la '
                        'distinta base nel Magazzino.'),
                  ),
                );
              }
              return DropdownButtonFormField<String>(
                initialValue: o.productId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Prodotto finito *'),
                items: [
                  for (final p in products)
                    DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.name} (giac. ${p.quantity})',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (id) => setState(() {
                  o.productId = id;
                  o.productName =
                      products.firstWhere((p) => p.id == id).name;
                }),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantità da produrre *'),
          ),
          const SizedBox(height: 12),
          _DateField(
            label: 'Data prevista',
            value: o.plannedDate,
            onChanged: (d) => setState(() => o.plannedDate = d),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
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
