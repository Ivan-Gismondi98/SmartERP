// ============================================================
//  SMARTERP · crm_form_page.dart — editor lead/opportunità.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../customers/application/customers_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../data/crm_repository.dart';
import '../domain/opportunity.dart';

class CrmFormPage extends ConsumerStatefulWidget {
  const CrmFormPage({super.key, this.opportunityId});
  final String? opportunityId;

  @override
  ConsumerState<CrmFormPage> createState() => _CrmFormPageState();
}

class _CrmFormPageState extends ConsumerState<CrmFormPage> {
  Opportunity? _draft;
  bool _saving = false;
  String? _loadError;

  late final TextEditingController _title;
  late final TextEditingController _contactName;
  late final TextEditingController _contactCompany;
  late final TextEditingController _contactEmail;
  late final TextEditingController _contactPhone;
  late final TextEditingController _value;
  late final TextEditingController _source;
  late final TextEditingController _notes;

  bool get _isNew => widget.opportunityId == null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _contactName = TextEditingController();
    _contactCompany = TextEditingController();
    _contactEmail = TextEditingController();
    _contactPhone = TextEditingController();
    _value = TextEditingController();
    _source = TextEditingController();
    _notes = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _contactName,
      _contactCompany,
      _contactEmail,
      _contactPhone,
      _value,
      _source,
      _notes
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await ref.read(currentProfileProvider.future);
      final companyId = profile?.companyId;
      if (companyId == null) {
        setState(() => _loadError = 'Nessuna azienda associata al profilo.');
        return;
      }
      Opportunity o;
      if (widget.opportunityId != null) {
        o = await ref.read(crmRepositoryProvider).getById(widget.opportunityId!);
      } else {
        o = Opportunity(companyId: companyId, ownerId: profile?.id);
      }
      _title.text = o.title;
      _contactName.text = o.contactName ?? '';
      _contactCompany.text = o.contactCompany ?? '';
      _contactEmail.text = o.contactEmail ?? '';
      _contactPhone.text = o.contactPhone ?? '';
      _value.text = o.expectedValue == 0 ? '' : Fmt.amount(o.expectedValue);
      _source.text = o.source ?? '';
      _notes.text = o.notes ?? '';
      setState(() => _draft = o);
    } catch (e) {
      setState(() => _loadError = '$e');
    }
  }

  Future<void> _save() async {
    final o = _draft!;
    if (_title.text.trim().isEmpty) {
      _snack('Indica un titolo per l\'opportunità.');
      return;
    }
    o.title = _title.text;
    o.contactName = _contactName.text;
    o.contactCompany = _contactCompany.text;
    o.contactEmail = _contactEmail.text;
    o.contactPhone = _contactPhone.text;
    o.expectedValue = Fmt.parseAmount(_value.text) ?? 0;
    o.source = _source.text;
    o.notes = _notes.text;

    setState(() => _saving = true);
    try {
      final repo = ref.read(crmRepositoryProvider);
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
        appBar: AppBar(title: const Text('Opportunità')),
        body: Center(child: Text('Errore: $_loadError')),
      );
    }
    if (_draft == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final o = _draft!;
    final customersAsync = ref.watch(customersListProvider);

    return Scaffold(
      appBar: AppBar(
          title: Text(_isNew ? 'Nuova opportunità' : 'Modifica opportunità')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Titolo *'),
          ),
          const SizedBox(height: 12),
          // Stadio pipeline
          DropdownButtonFormField<CrmStage>(
            initialValue: o.stage,
            decoration: const InputDecoration(labelText: 'Stadio'),
            items: [
              for (final s in CrmStage.values)
                DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (s) => setState(() => o.stage = s ?? CrmStage.newLead),
          ),
          const SizedBox(height: 12),
          // Cliente collegato (facoltativo)
          customersAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Errore clienti: $e'),
            data: (customers) => DropdownButtonFormField<String?>(
              initialValue: o.customerId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Cliente collegato (se già anagrafato)'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('— Lead non ancora cliente —')),
                for (final c in customers)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (id) => setState(() {
                o.customerId = id;
                o.customer = id == null
                    ? null
                    : customers.firstWhere((c) => c.id == id);
              }),
            ),
          ),
          const Divider(height: 32),
          Text('Contatto (lead)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _contactCompany,
            decoration: const InputDecoration(labelText: 'Azienda'),
          ),
          TextField(
            controller: _contactName,
            decoration: const InputDecoration(labelText: 'Referente'),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _contactEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _contactPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefono'),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _value,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Valore atteso (€)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Chiusura prevista',
                  value: o.expectedClose,
                  onChanged: (d) => setState(() => o.expectedClose = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 4),
              Text('Probabilità: ${o.probability}%'),
              Expanded(
                child: Slider(
                  value: o.probability.toDouble().clamp(0, 100),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${o.probability}%',
                  onChanged: (v) => setState(() => o.probability = v.round()),
                ),
              ),
            ],
          ),
          TextField(
            controller: _source,
            decoration: const InputDecoration(
                labelText: 'Origine (sito, passaparola, fiera…)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
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
