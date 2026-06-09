// ============================================================
//  SMARTERP · bom_editor_page.dart — editor distinta base di un prodotto
//  componibile (riusa products_repository: getBom / replaceBom).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../products/application/products_providers.dart';
import '../../products/data/products_repository.dart';
import '../../products/domain/bom_component.dart';
import '../../products/domain/product.dart';
import '../../profile/application/profile_providers.dart';

class BomEditorPage extends ConsumerStatefulWidget {
  const BomEditorPage({
    super.key,
    required this.productId,
    required this.productName,
    this.readOnly = false,
  });
  final String productId;
  final String productName;
  final bool readOnly;

  @override
  ConsumerState<BomEditorPage> createState() => _BomEditorPageState();
}

class _BomEditorPageState extends ConsumerState<BomEditorPage> {
  List<BomComponent>? _rows;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows =
          await ref.read(productsRepositoryProvider).getBom(widget.productId);
      setState(() => _rows = rows);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  void _add() => setState(() => _rows!.add(BomComponent(componentId: '')));
  void _remove(int i) => setState(() => _rows!.removeAt(i));

  Future<void> _save() async {
    final rows = _rows!;
    if (rows.any((r) => r.componentId.isEmpty)) {
      _snack('Seleziona il componente su ogni riga (o rimuovila).');
      return;
    }
    setState(() => _saving = true);
    try {
      final profile = await ref.read(currentProfileProvider.future);
      final companyId = profile?.companyId;
      if (companyId == null) throw 'Nessuna azienda associata';
      await ref
          .read(productsRepositoryProvider)
          .replaceBom(companyId, widget.productId, rows);
      ref.invalidate(bomProvider(widget.productId));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      _snack('Errore: $e');
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Distinta base')),
        body: Center(child: Text('Errore: $_error')),
      );
    }
    if (_rows == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final products = (ref.watch(productsListProvider).valueOrNull ?? const [])
        .where((p) => p.id != widget.productId)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text('Distinta base · ${widget.productName}')),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Salva'),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_rows!.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Nessun componente. Aggiungi le righe della distinta.',
                  textAlign: TextAlign.center),
            ),
          for (var i = 0; i < _rows!.length; i++)
            _RowEditor(
              key: ValueKey('bom_${_rows![i].hashCode}'),
              row: _rows![i],
              products: products,
              readOnly: widget.readOnly,
              onChanged: () => setState(() {}),
              onRemove: widget.readOnly ? null : () => _remove(i),
            ),
          if (!widget.readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi componente'),
              ),
            ),
        ],
      ),
    );
  }
}

class _RowEditor extends StatefulWidget {
  const _RowEditor({
    super.key,
    required this.row,
    required this.products,
    required this.readOnly,
    required this.onChanged,
    this.onRemove,
  });
  final BomComponent row;
  final List<Product> products;
  final bool readOnly;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  State<_RowEditor> createState() => _RowEditorState();
}

class _RowEditorState extends State<_RowEditor> {
  late final TextEditingController _qty;

  BomComponent get row => widget.row;

  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(
        text: row.quantity == 0 ? '' : Fmt.qty(row.quantity));
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                initialValue: row.componentId.isEmpty ? null : row.componentId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Componente', isDense: true),
                items: [
                  for (final p in widget.products)
                    DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.name} (giac. ${p.quantity})',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: widget.readOnly
                    ? null
                    : (id) {
                        if (id == null) return;
                        final p = widget.products.firstWhere((e) => e.id == id);
                        setState(() {
                          row.componentId = id;
                          row.componentName = p.name;
                          row.componentUnit = p.unit;
                          row.componentStock = p.quantity;
                        });
                        widget.onChanged();
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _qty,
                enabled: !widget.readOnly,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Qtà', isDense: true),
                onChanged: (v) => row.quantity = Fmt.parseAmount(v) ?? 0,
              ),
            ),
            if (widget.onRemove != null)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onRemove,
              ),
          ],
        ),
      ),
    );
  }
}
