// ============================================================
//  SMARTERP · crm_detail_page.dart — dettaglio opportunità.
//  Avanzamento stadio (qualifica/proposta/vinta/persa), modifica, elimina
//  e creazione di un preventivo (modulo Vendite) dall'opportunità.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../sales/data/sales_repository.dart';
import '../../sales/domain/sales_document.dart';
import '../../sales/presentation/sales_form_page.dart';
import '../application/crm_providers.dart';
import '../data/crm_repository.dart';
import '../domain/opportunity.dart';
import 'crm_form_page.dart';

class CrmDetailPage extends ConsumerWidget {
  const CrmDetailPage({super.key, required this.opportunityId});
  final String opportunityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(opportunityDetailProvider(opportunityId));
    final canEdit = ref.watch(canProvider(Perm.crmEdit));
    final canDelete = ref.watch(canProvider(Perm.crmDelete));
    final canQuote = ref.watch(canProvider(Perm.salesCreate));

    return Scaffold(
      appBar: AppBar(title: const Text('Opportunità')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (opp) => _DetailBody(
          opp: opp,
          canEdit: canEdit,
          canDelete: canDelete,
          canQuote: canQuote,
          onChanged: () =>
              ref.invalidate(opportunityDetailProvider(opportunityId)),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.opp,
    required this.canEdit,
    required this.canDelete,
    required this.canQuote,
    required this.onChanged,
  });

  final Opportunity opp;
  final bool canEdit;
  final bool canDelete;
  final bool canQuote;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(crmRepositoryProvider);

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
                    child: Text(opp.title, style: theme.textTheme.headlineSmall),
                  ),
                  Chip(label: Text(opp.stage.label)),
                ],
              ),
              const SizedBox(height: 12),
              _kv(theme, 'Contatto', opp.displayContact),
              if (opp.contactName != null && opp.contactName!.isNotEmpty)
                _kv(theme, 'Referente', opp.contactName!),
              if (opp.contactEmail != null && opp.contactEmail!.isNotEmpty)
                _kv(theme, 'Email', opp.contactEmail!),
              if (opp.contactPhone != null && opp.contactPhone!.isNotEmpty)
                _kv(theme, 'Telefono', opp.contactPhone!),
              const Divider(height: 32),
              _kv(theme, 'Valore atteso', Fmt.euro(opp.expectedValue)),
              _kv(theme, 'Probabilità', '${opp.probability}%'),
              _kv(theme, 'Previsione ponderata', Fmt.euro(opp.weightedValue)),
              if (opp.expectedClose != null)
                _kv(theme, 'Chiusura prevista', Fmt.date(opp.expectedClose)),
              if (opp.source != null && opp.source!.isNotEmpty)
                _kv(theme, 'Origine', opp.source!),
              if (opp.notes != null && opp.notes!.isNotEmpty) ...[
                const Divider(height: 32),
                Text('Note', style: theme.textTheme.titleMedium),
                Text(opp.notes!),
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
                // Avanzamento stadio
                if (canEdit && !opp.stage.closed) ...[
                  if (opp.stage == CrmStage.newLead)
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          _setStage(context, repo, CrmStage.qualified),
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Qualifica'),
                    ),
                  if (opp.stage == CrmStage.qualified)
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          _setStage(context, repo, CrmStage.proposal),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('A proposta'),
                    ),
                  FilledButton.icon(
                    onPressed: () => _setStage(context, repo, CrmStage.won),
                    icon: const Icon(Icons.emoji_events_outlined),
                    label: const Text('Vinta'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _setStage(context, repo, CrmStage.lost),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Persa'),
                  ),
                ],
                if (canQuote && !opp.stage.closed)
                  FilledButton.tonalIcon(
                    onPressed: () => _createQuote(context, ref),
                    icon: const Icon(Icons.request_quote_outlined),
                    label: const Text('Crea preventivo'),
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
                width: 150,
                child: Text(k, style: theme.textTheme.bodyMedium)),
            Expanded(child: Text(v, style: theme.textTheme.titleSmall)),
          ],
        ),
      );

  Future<void> _edit(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CrmFormPage(opportunityId: opp.id)),
    );
    if (changed == true) onChanged();
  }

  Future<void> _setStage(
      BuildContext context, CrmRepository repo, CrmStage s) async {
    try {
      await repo.setStage(opp.id!, s);
      onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  /// Crea una bozza di PREVENTIVO (modulo Vendite) dall'opportunità.
  Future<void> _createQuote(BuildContext context, WidgetRef ref) async {
    try {
      final quote = SalesDocument(
        companyId: opp.companyId,
        customerId: opp.customerId,
        customer: opp.customer,
        kind: SalesKind.quote,
        validUntil: DateTime.now().add(const Duration(days: 30)),
        notes: 'Da opportunità: ${opp.title}',
        items: [SalesItem(description: opp.title, unitPrice: opp.expectedValue)],
      );
      final id = await ref.read(salesRepositoryProvider).createDraft(quote);
      if (!context.mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => SalesFormPage(documentId: id)),
      );
      onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore creazione preventivo: $e');
    }
  }

  Future<void> _delete(BuildContext context, CrmRepository repo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare l\'opportunità?'),
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
      await repo.delete(opp.id!);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
