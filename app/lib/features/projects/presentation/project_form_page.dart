// ============================================================
//  SMARTERP · project_form_page.dart — editor progetto.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../customers/application/customers_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../data/projects_repository.dart';
import '../domain/project.dart';

class ProjectFormPage extends ConsumerStatefulWidget {
  const ProjectFormPage({super.key, this.projectId});
  final String? projectId;

  @override
  ConsumerState<ProjectFormPage> createState() => _ProjectFormPageState();
}

class _ProjectFormPageState extends ConsumerState<ProjectFormPage> {
  Project? _draft;
  bool _saving = false;
  String? _loadError;

  late final TextEditingController _name;
  late final TextEditingController _manager;
  late final TextEditingController _budget;
  late final TextEditingController _description;

  bool get _isNew => widget.projectId == null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _manager = TextEditingController();
    _budget = TextEditingController();
    _description = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _manager.dispose();
    _budget.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (widget.projectId != null) {
        final p =
            await ref.read(projectsRepositoryProvider).getById(widget.projectId!);
        _name.text = p.name;
        _manager.text = p.manager ?? '';
        _budget.text = p.budget == 0 ? '' : Fmt.amount(p.budget);
        _description.text = p.description ?? '';
        setState(() => _draft = p);
      } else {
        final profile = await ref.read(currentProfileProvider.future);
        final companyId = profile?.companyId;
        if (companyId == null) {
          setState(() => _loadError = 'Nessuna azienda associata al profilo.');
          return;
        }
        setState(() => _draft = Project(
              companyId: companyId,
              startDate: DateTime.now(),
            ));
      }
    } catch (e) {
      setState(() => _loadError = '$e');
    }
  }

  Future<void> _save() async {
    final p = _draft!;
    if (_name.text.trim().isEmpty) {
      _snack('Indica il nome del progetto.');
      return;
    }
    p.name = _name.text;
    p.manager = _manager.text;
    p.budget = Fmt.parseAmount(_budget.text) ?? 0;
    p.description = _description.text;

    setState(() => _saving = true);
    try {
      final repo = ref.read(projectsRepositoryProvider);
      if (_isNew) {
        await repo.create(p);
      } else {
        await repo.update(p);
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
        appBar: AppBar(title: const Text('Progetto')),
        body: Center(child: Text('Errore: $_loadError')),
      );
    }
    if (_draft == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = _draft!;
    final customersAsync = ref.watch(customersListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'Nuovo progetto' : 'Modifica progetto')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nome progetto *'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ProjectStatus>(
            initialValue: p.status,
            decoration: const InputDecoration(labelText: 'Stato'),
            items: [
              for (final s in ProjectStatus.values)
                DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (v) => setState(() => p.status = v ?? ProjectStatus.planning),
          ),
          const SizedBox(height: 12),
          customersAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Errore clienti: $e'),
            data: (customers) => DropdownButtonFormField<String?>(
              initialValue: p.customerId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Cliente (facoltativo)'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('— Interno / nessuno —')),
                for (final c in customers)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (id) => setState(() {
                p.customerId = id;
                p.customer =
                    id == null ? null : customers.firstWhere((c) => c.id == id);
              }),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Inizio',
                  value: p.startDate,
                  onChanged: (d) => setState(() => p.startDate = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Scadenza',
                  value: p.dueDate,
                  onChanged: (d) => setState(() => p.dueDate = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _budget,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Budget (€)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _manager,
                  decoration:
                      const InputDecoration(labelText: 'Responsabile'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 3,
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
