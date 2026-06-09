// ============================================================
//  SMARTERP · equipment_form_dialog.dart — editor attrezzatura.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../profile/application/profile_providers.dart';
import '../data/maintenance_repository.dart';
import '../domain/equipment.dart';

class EquipmentFormDialog extends ConsumerStatefulWidget {
  const EquipmentFormDialog({super.key, this.equipment});
  final Equipment? equipment;

  @override
  ConsumerState<EquipmentFormDialog> createState() =>
      _EquipmentFormDialogState();
}

class _EquipmentFormDialogState extends ConsumerState<EquipmentFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _category;
  late final TextEditingController _location;
  EquipmentStatus _status = EquipmentStatus.operational;
  DateTime? _nextService;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.equipment;
    _name = TextEditingController(text: e?.name ?? '');
    _code = TextEditingController(text: e?.code ?? '');
    _category = TextEditingController(text: e?.category ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _status = e?.status ?? EquipmentStatus.operational;
    _nextService = e?.nextService;
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _category, _location]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      final existing = widget.equipment;
      if (existing == null) {
        final profile = await ref.read(currentProfileProvider.future);
        final companyId = profile?.companyId;
        if (companyId == null) throw 'Nessuna azienda associata';
        await repo.createEquipment(Equipment(
          companyId: companyId,
          name: _name.text,
          code: _code.text,
          category: _category.text,
          location: _location.text,
          status: _status,
          nextService: _nextService,
        ));
      } else {
        existing
          ..name = _name.text
          ..code = _code.text
          ..category = _category.text
          ..location = _location.text
          ..status = _status
          ..nextService = _nextService;
        await repo.updateEquipment(existing);
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

  Future<void> _delete() async {
    final existing = widget.equipment;
    if (existing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Eliminare ${existing.name}?'),
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
      await ref
          .read(maintenanceRepositoryProvider)
          .deleteEquipment(existing.id!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.equipment == null
          ? 'Nuova attrezzatura'
          : 'Modifica attrezzatura'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Denominazione *')),
            TextField(
                controller: _code,
                decoration:
                    const InputDecoration(labelText: 'Matricola / inventario')),
            TextField(
                controller: _category,
                decoration: const InputDecoration(labelText: 'Categoria')),
            TextField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Ubicazione')),
            const SizedBox(height: 8),
            DropdownButtonFormField<EquipmentStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Stato'),
              items: [
                for (final s in EquipmentStatus.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) =>
                  setState(() => _status = v ?? EquipmentStatus.operational),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _nextService ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _nextService = picked);
              },
              child: InputDecorator(
                decoration:
                    const InputDecoration(labelText: 'Prossima manutenzione'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_nextService == null ? '—' : Fmt.date(_nextService)),
                    if (_nextService != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _nextService = null),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.equipment != null)
          TextButton(
            onPressed: _busy ? null : _delete,
            child: Text('Elimina',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Annulla')),
        FilledButton(
            onPressed: _busy ? null : _save, child: const Text('Salva')),
      ],
    );
  }
}
