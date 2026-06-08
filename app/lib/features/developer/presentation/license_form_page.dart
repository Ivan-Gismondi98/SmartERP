// ============================================================
//  SMARTERP · license_form_page.dart — crea/modifica licenza.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../application/developer_providers.dart';
import '../data/developer_repository.dart';
import '../domain/license.dart';

class LicenseFormPage extends ConsumerStatefulWidget {
  const LicenseFormPage({super.key, this.license});
  final License? license;

  @override
  ConsumerState<LicenseFormPage> createState() => _LicenseFormPageState();
}

class _LicenseFormPageState extends ConsumerState<LicenseFormPage> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _notes = TextEditingController();
  String? _companyId;
  String _status = 'active';
  String _period = 'monthly';
  DateTime _start = DateTime.now();
  DateTime? _renewal;
  bool _saving = false;

  License? get _existing => widget.license;

  @override
  void initState() {
    super.initState();
    final l = _existing;
    if (l != null) {
      _companyId = l.companyId;
      _name.text = l.name;
      _price.text = l.price == 0 ? '' : Fmt.amount(l.price);
      _notes.text = l.notes ?? '';
      _status = l.status;
      _period = l.period;
      _start = l.startDate ?? DateTime.now();
      _renewal = l.renewalDate;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _price, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_companyId == null || _name.text.trim().isEmpty) {
      _snack('Seleziona organizzazione e nome.');
      return;
    }
    setState(() => _saving = true);
    final l = License(
      id: _existing?.id ?? '',
      companyId: _companyId!,
      name: _name.text.trim(),
      status: _status,
      price: Fmt.parseAmount(_price.text) ?? 0,
      period: _period,
      startDate: _start,
      renewalDate: _renewal,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    try {
      final repo = ref.read(developerRepositoryProvider);
      if (_existing == null) {
        await repo.create(l);
      } else {
        await repo.update(l);
      }
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
    final orgs = ref.watch(organizationsProvider);
    return Scaffold(
      appBar: AppBar(
          title: Text(_existing == null ? 'Nuova licenza' : 'Modifica licenza')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          orgs.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Errore org: $e'),
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _companyId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Organizzazione *'),
              items: [
                for (final o in list)
                  DropdownMenuItem(value: o.id, child: Text(o.name)),
              ],
              onChanged: (v) => setState(() => _companyId = v),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration:
                const InputDecoration(labelText: 'Nome licenza / app *'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Prezzo €'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _period,
                  decoration: const InputDecoration(labelText: 'Periodo'),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Mensile')),
                    DropdownMenuItem(value: 'yearly', child: Text('Annuale')),
                    DropdownMenuItem(value: 'once', child: Text('Una tantum')),
                  ],
                  onChanged: (v) => setState(() => _period = v ?? 'monthly'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Stato'),
            items: const [
              DropdownMenuItem(value: 'active', child: Text('Attiva')),
              DropdownMenuItem(value: 'suspended', child: Text('Sospesa')),
              DropdownMenuItem(value: 'expired', child: Text('Scaduta')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'active'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                    label: 'Inizio',
                    value: _start,
                    onChanged: (d) => setState(() => _start = d)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                    label: 'Prossimo rinnovo',
                    value: _renewal,
                    onChanged: (d) => setState(() => _renewal = d)),
              ),
            ],
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
            label: const Text('Salva licenza'),
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
