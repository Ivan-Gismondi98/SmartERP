// ============================================================
//  SMARTERP · request_form_page.dart — editor richiesta di manutenzione.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../profile/application/profile_providers.dart';
import '../application/maintenance_providers.dart';
import '../data/maintenance_repository.dart';
import '../domain/maintenance_request.dart';

class RequestFormPage extends ConsumerStatefulWidget {
  const RequestFormPage({super.key, this.requestId});
  final String? requestId;

  @override
  ConsumerState<RequestFormPage> createState() => _RequestFormPageState();
}

class _RequestFormPageState extends ConsumerState<RequestFormPage> {
  MaintenanceRequest? _draft;
  bool _saving = false;
  String? _loadError;

  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _assignedTo;

  bool get _isNew => widget.requestId == null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _description = TextEditingController();
    _assignedTo = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _assignedTo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (widget.requestId != null) {
        final r = await ref
            .read(maintenanceRepositoryProvider)
            .getRequest(widget.requestId!);
        _title.text = r.title;
        _description.text = r.description ?? '';
        _assignedTo.text = r.assignedTo ?? '';
        setState(() => _draft = r);
      } else {
        final profile = await ref.read(currentProfileProvider.future);
        final companyId = profile?.companyId;
        if (companyId == null) {
          setState(() => _loadError = 'Nessuna azienda associata al profilo.');
          return;
        }
        setState(() => _draft = MaintenanceRequest(
              companyId: companyId,
              requestedBy: profile?.id,
            ));
      }
    } catch (e) {
      setState(() => _loadError = '$e');
    }
  }

  Future<void> _save() async {
    final r = _draft!;
    if (_title.text.trim().isEmpty) {
      _snack('Indica un titolo per la richiesta.');
      return;
    }
    r.title = _title.text;
    r.description = _description.text;
    r.assignedTo = _assignedTo.text;

    setState(() => _saving = true);
    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      if (_isNew) {
        await repo.createRequest(r);
      } else {
        await repo.updateRequest(r);
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
        appBar: AppBar(title: const Text('Richiesta')),
        body: Center(child: Text('Errore: $_loadError')),
      );
    }
    if (_draft == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final r = _draft!;
    final equipment = ref.watch(equipmentListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'Nuova richiesta' : 'Modifica richiesta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Titolo *'),
          ),
          const SizedBox(height: 12),
          equipment.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Errore attrezzature: $e'),
            data: (list) => DropdownButtonFormField<String?>(
              initialValue: r.equipmentId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Attrezzatura'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('— Nessuna / generale —')),
                for (final e in list)
                  DropdownMenuItem(value: e.id, child: Text(e.name)),
              ],
              onChanged: (id) => setState(() => r.equipmentId = id),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<MaintenanceType>(
                  initialValue: r.type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: [
                    for (final t in MaintenanceType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (v) => setState(
                      () => r.type = v ?? MaintenanceType.corrective),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<MaintenancePriority>(
                  initialValue: r.priority,
                  decoration: const InputDecoration(labelText: 'Priorità'),
                  items: [
                    for (final p in MaintenancePriority.values)
                      DropdownMenuItem(value: p, child: Text(p.label)),
                  ],
                  onChanged: (v) => setState(
                      () => r.priority = v ?? MaintenancePriority.medium),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Data programmata',
                  value: r.scheduledDate,
                  onChanged: (d) => setState(() => r.scheduledDate = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _assignedTo,
                  decoration: const InputDecoration(labelText: 'Assegnata a'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Descrizione'),
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
