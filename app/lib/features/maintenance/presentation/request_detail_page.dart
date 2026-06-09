// ============================================================
//  SMARTERP · request_detail_page.dart — dettaglio richiesta di
//  manutenzione: avanzamento stato e registrazione del costo.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../application/maintenance_providers.dart';
import '../data/maintenance_repository.dart';
import '../domain/maintenance_request.dart';
import 'request_form_page.dart';

class RequestDetailPage extends ConsumerWidget {
  const RequestDetailPage({super.key, required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(maintenanceRequestDetailProvider(requestId));
    final canEdit = ref.watch(canProvider(Perm.maintenanceEdit));
    final canDelete = ref.watch(canProvider(Perm.maintenanceDelete));

    return Scaffold(
      appBar: AppBar(title: const Text('Richiesta di manutenzione')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (r) => _Body(
          req: r,
          canEdit: canEdit,
          canDelete: canDelete,
          onChanged: () =>
              ref.invalidate(maintenanceRequestDetailProvider(requestId)),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.req,
    required this.canEdit,
    required this.canDelete,
    required this.onChanged,
  });
  final MaintenanceRequest req;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(maintenanceRepositoryProvider);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(req.title, style: theme.textTheme.headlineSmall),
                  ),
                  Chip(label: Text(req.status.label)),
                ],
              ),
              const SizedBox(height: 12),
              _kv(theme, 'Attrezzatura', req.equipmentName ?? 'Generale'),
              _kv(theme, 'Tipo', req.type.label),
              _kv(theme, 'Priorità', req.priority.label),
              if (req.assignedTo != null && req.assignedTo!.isNotEmpty)
                _kv(theme, 'Assegnata a', req.assignedTo!),
              if (req.scheduledDate != null)
                _kv(theme, 'Programmata', Fmt.date(req.scheduledDate)),
              if (req.completedAt != null)
                _kv(theme, 'Completata', Fmt.date(req.completedAt)),
              if (req.cost > 0) _kv(theme, 'Costo', Fmt.euro(req.cost)),
              if (req.description != null && req.description!.isNotEmpty) ...[
                const Divider(height: 32),
                Text('Descrizione', style: theme.textTheme.titleMedium),
                Text(req.description!),
              ],
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canDelete)
                  OutlinedButton.icon(
                    onPressed: () => _delete(context, repo),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Elimina'),
                  ),
                if (canEdit)
                  OutlinedButton.icon(
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifica'),
                  ),
                if (canEdit && req.status == MaintenanceStatus.open)
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _mark(context, repo, MaintenanceStatus.inProgress),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Avvia'),
                  ),
                if (canEdit && !req.status.isClosed)
                  FilledButton.icon(
                    onPressed: () => _complete(context, ref, repo),
                    icon: const Icon(Icons.task_alt),
                    label: const Text('Completa'),
                  ),
                if (canEdit && !req.status.isClosed)
                  OutlinedButton.icon(
                    onPressed: () =>
                        _mark(context, repo, MaintenanceStatus.cancelled),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Annulla'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(ThemeData theme, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 130, child: Text(k, style: theme.textTheme.bodyMedium)),
            Expanded(child: Text(v, style: theme.textTheme.titleSmall)),
          ],
        ),
      );

  Future<void> _edit(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RequestFormPage(requestId: req.id)),
    );
    if (changed == true) onChanged();
  }

  Future<void> _mark(BuildContext context, MaintenanceRepository repo,
      MaintenanceStatus s) async {
    try {
      await repo.setStatus(req.id!, s);
      onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  /// Completa la richiesta chiedendo il costo dell'intervento.
  Future<void> _complete(
      BuildContext context, WidgetRef ref, MaintenanceRepository repo) async {
    final ctrl = TextEditingController(
        text: req.cost == 0 ? '' : Fmt.amount(req.cost));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Completare l\'intervento?'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Costo intervento (€)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Completa')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      req.cost = Fmt.parseAmount(ctrl.text) ?? 0;
      req.status = MaintenanceStatus.done;
      await repo.updateRequest(req);
      await repo.setStatus(req.id!, MaintenanceStatus.done);
      onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  Future<void> _delete(BuildContext context, MaintenanceRepository repo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare la richiesta?'),
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
      await repo.deleteRequest(req.id!);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
