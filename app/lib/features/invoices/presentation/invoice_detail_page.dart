// ============================================================
//  SMARTERP · invoice_detail_page.dart — dettaglio/anteprima fattura.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../../studio/data/templates_repository.dart';
import '../application/invoices_providers.dart';
import '../data/invoice_docx.dart';
import '../data/invoices_repository.dart';
import '../domain/invoice.dart';
import 'invoice_form_page.dart';
import 'invoice_pdf_page.dart';
import 'invoice_xml_page.dart';

class InvoiceDetailPage extends ConsumerWidget {
  const InvoiceDetailPage({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(invoiceDetailProvider(invoiceId));
    final canEdit = ref.watch(canProvider(Perm.invoicesEdit));
    final canIssue = ref.watch(canProvider(Perm.invoicesIssue));
    final canDelete = ref.watch(canProvider(Perm.invoicesDelete));
    final canCreate = ref.watch(canProvider(Perm.invoicesCreate));
    final canExport = ref.watch(canProvider(Perm.invoicesExport));
    final canPrint = ref.watch(canProvider(Perm.invoicesPrint));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio fattura'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (inv) => _DetailBody(
          inv: inv,
          canEdit: canEdit,
          canIssue: canIssue,
          canDelete: canDelete,
          canCreate: canCreate,
          canExport: canExport,
          canPrint: canPrint,
          onChanged: () => ref.invalidate(invoiceDetailProvider(invoiceId)),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.inv,
    required this.canEdit,
    required this.canIssue,
    required this.canDelete,
    required this.canCreate,
    required this.canExport,
    required this.canPrint,
    required this.onChanged,
  });

  final Invoice inv;
  final bool canEdit;
  final bool canIssue;
  final bool canDelete;
  final bool canCreate;
  final bool canExport;
  final bool canPrint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(invoicesRepositoryProvider);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${inv.documentTypeLabel} ${inv.displayNumber}',
                      style: theme.textTheme.headlineSmall),
                  Chip(label: Text(inv.status.label)),
                ],
              ),
              Text('Data: ${Fmt.date(inv.issueDate)}'
                  '${inv.dueDate != null ? '  ·  Scadenza: ${Fmt.date(inv.dueDate)}' : ''}'),
              const Divider(height: 32),
              Text('Cliente', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(inv.customer?.name ?? '—',
                  style: theme.textTheme.titleSmall),
              if (inv.customer?.vatNumber != null)
                Text('P.IVA ${inv.customer!.vatNumber}'),
              if ((inv.customer?.fullAddress ?? '').isNotEmpty)
                Text(inv.customer!.fullAddress),
              const Divider(height: 32),
              Text('Righe', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _ItemsTable(inv: inv),
              const Divider(height: 32),
              Text('Riepilogo IVA', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _VatSummaryTable(inv: inv),
              const SizedBox(height: 16),
              _TotalsBox(inv: inv),
              if (inv.notes != null && inv.notes!.isNotEmpty) ...[
                const Divider(height: 32),
                Text('Note', style: theme.textTheme.titleMedium),
                Text(inv.notes!),
              ],
              if (inv.isIssued &&
                  (ref.watch(sdiEnabledProvider).valueOrNull ?? false) &&
                  ref.watch(canProvider(Perm.invoicesSdiSend))) ...[
                const Divider(height: 32),
                _SdiBlock(inv: inv, onChanged: onChanged),
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
                if (inv.isDraft && canDelete)
                  OutlinedButton.icon(
                    onPressed: () => _delete(context, repo),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Elimina'),
                  ),
                if (inv.isDraft && canEdit)
                  OutlinedButton.icon(
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifica'),
                  ),
                if (inv.isDraft && canIssue)
                  FilledButton.icon(
                    onPressed: () => _issue(context, repo),
                    icon: const Icon(Icons.send),
                    label: const Text('Emetti'),
                  ),
                if (inv.status == InvoiceStatus.sent && canEdit)
                  FilledButton.icon(
                    onPressed: () => _mark(context, repo, InvoiceStatus.paid),
                    icon: const Icon(Icons.check),
                    label: const Text('Segna pagata'),
                  ),
                if (inv.isIssued &&
                    inv.status != InvoiceStatus.cancelled &&
                    canEdit)
                  OutlinedButton.icon(
                    onPressed: () =>
                        _mark(context, repo, InvoiceStatus.cancelled),
                    icon: const Icon(Icons.block),
                    label: const Text('Annulla'),
                  ),
                if (inv.isIssued && canPrint)
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InvoicePdfPage(invoice: inv),
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Stampa PDF'),
                  ),
                if (inv.isIssued && canPrint)
                  OutlinedButton.icon(
                    onPressed: () => _downloadWord(context, ref),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Word'),
                  ),
                if (inv.isIssued && canExport)
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InvoiceXmlPage(invoice: inv),
                      ),
                    ),
                    icon: const Icon(Icons.code),
                    label: const Text('Esporta XML'),
                  ),
                if (canCreate)
                  OutlinedButton.icon(
                    onPressed: () => _duplicate(context, ref, false),
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Duplica'),
                  ),
                if (inv.isIssued && !inv.isCreditNote && canCreate)
                  OutlinedButton.icon(
                    onPressed: () => _duplicate(context, ref, true),
                    icon: const Icon(Icons.undo),
                    label: const Text('Nota di credito'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => InvoiceFormPage(invoiceId: inv.id)),
    );
    if (changed == true) onChanged();
  }

  Future<void> _issue(BuildContext context, InvoicesRepository repo) async {
    if (inv.items.isEmpty) {
      _snack(context, 'Aggiungi almeno una riga prima di emettere.');
      return;
    }
    if (inv.customerId == null) {
      _snack(context, 'Seleziona un cliente prima di emettere.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Emettere la fattura?'),
        content: const Text(
            'Verra\' assegnato il numero progressivo definitivo e la '
            'fattura non sara\' piu\' modificabile.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Emetti')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final number = await repo.issue(inv);
      if (context.mounted) {
        _snack(context, 'Fattura emessa: n. $number');
      }
      onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  Future<void> _downloadWord(BuildContext context, WidgetRef ref) async {
    try {
      final profile = await ref.read(currentProfileProvider.future);
      final company = profile?.company;
      if (company == null) {
        if (context.mounted) _snack(context, 'Dati azienda mancanti.');
        return;
      }
      final template = inv.templateId == null
          ? null
          : await ref.read(templatesRepositoryProvider).getById(inv.templateId!);
      final bytes = const InvoiceDocxGenerator()
          .build(inv, company, template: template);
      await FileSaver.instance.saveFile(
        name: 'Fattura_${inv.displayNumber.replaceAll('/', '-')}',
        bytes: Uint8List.fromList(bytes),
        ext: 'docx',
        mimeType: MimeType.microsoftWord,
      );
      if (context.mounted) _snack(context, 'Word generato.');
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore Word: $e');
    }
  }

  Future<void> _duplicate(
      BuildContext context, WidgetRef ref, bool asCreditNote) async {
    final repo = ref.read(invoicesRepositoryProvider);
    try {
      final newId = await repo.duplicateFrom(inv, asCreditNote: asCreditNote);
      if (!context.mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => InvoiceFormPage(invoiceId: newId)),
      );
      onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  Future<void> _mark(
      BuildContext context, InvoicesRepository repo, InvoiceStatus s) async {
    try {
      await repo.setStatus(inv.id!, s);
      onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  Future<void> _delete(BuildContext context, InvoicesRepository repo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare la bozza?'),
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
      await repo.delete(inv.id!);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// Blocco firma/invio SdI — mostrato solo se la feature è abilitata dalle
/// impostazioni e l'utente ha il permesso `invoices.sdi_send`.
class _SdiBlock extends ConsumerWidget {
  const _SdiBlock({required this.inv, required this.onChanged});
  final Invoice inv;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(invoicesRepositoryProvider);

    Future<void> set(String status) async {
      try {
        await repo.setSdiStatus(inv.id!, status);
        onChanged();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Errore: $e')));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.verified_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('Firma / Invio SdI', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 4),
        Text('Stato: ${inv.sdiStatusLabel}'
            '${inv.sdiSentAt != null ? ' · ${Fmt.date(inv.sdiSentAt)}' : ''}'),
        Text(
          'Trasmissione registrata localmente. La firma qualificata e l\'invio '
          'effettivo allo SdI richiedono accreditamento e sono esterni all\'app.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            if (inv.sdiStatus == 'not_sent')
              FilledButton.icon(
                onPressed: () => set('sent'),
                icon: const Icon(Icons.send),
                label: const Text('Invia allo SdI'),
              ),
            if (inv.sdiStatus == 'sent') ...[
              FilledButton.tonalIcon(
                onPressed: () => set('delivered'),
                icon: const Icon(Icons.check),
                label: const Text('Segna consegnata'),
              ),
              OutlinedButton.icon(
                onPressed: () => set('rejected'),
                icon: const Icon(Icons.error_outline),
                label: const Text('Segna scartata'),
              ),
            ],
            if (inv.sdiStatus != 'not_sent')
              TextButton(
                onPressed: () => set('not_sent'),
                child: const Text('Reimposta'),
              ),
          ],
        ),
      ],
    );
  }
}

class _ItemsTable extends StatelessWidget {
  const _ItemsTable({required this.inv});
  final Invoice inv;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final it in inv.items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(it.description),
            subtitle: Text(
                '${Fmt.qty(it.quantity)} × ${Fmt.euro(it.unitPrice)}'
                '${it.discountPercent > 0 ? '  −${Fmt.percent(it.discountPercent)}' : ''}'
                '   ·   IVA ${it.vatRate == 0 ? (it.vatNature?.code ?? '0%') : Fmt.percent(it.vatRate)}'),
            trailing: Text(Fmt.euro(it.taxableBase)),
          ),
      ],
    );
  }
}

class _VatSummaryTable extends StatelessWidget {
  const _VatSummaryTable({required this.inv});
  final Invoice inv;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      children: [
        const TableRow(children: [
          Text('Aliquota', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Imponibile',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Imposta',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        for (final l in inv.vatSummary)
          TableRow(children: [
            Text(l.vatRate == 0
                ? (l.nature?.code ?? 'Esente')
                : Fmt.percent(l.vatRate)),
            Text(Fmt.euro(l.taxable), textAlign: TextAlign.right),
            Text(Fmt.euro(l.tax), textAlign: TextAlign.right),
          ]),
      ],
    );
  }
}

class _TotalsBox extends StatelessWidget {
  const _TotalsBox({required this.inv});
  final Invoice inv;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: bold
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.bodyMedium),
              Text(value,
                  style: bold
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.bodyMedium),
            ],
          ),
        );

    final now = DateTime.now();
    final interest = inv.interestAmount(now);

    return Column(
      children: [
        row('Imponibile', Fmt.euro(inv.subtotal)),
        row('IVA', Fmt.euro(inv.taxAmount)),
        if (inv.stampDuty > 0) row('Bollo', Fmt.euro(inv.stampDuty)),
        if (inv.rounding != 0) row('Arrotondamento', Fmt.euro(inv.rounding)),
        const Divider(),
        row('TOTALE', Fmt.euro(inv.total), bold: true),
        if (interest > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Scaduta da ${inv.daysLate(now)} giorni · interessi di mora '
            '(${Fmt.percent(inv.interestRate ?? 0)} annuo)',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.orange.shade800),
          ),
          row('Interessi di mora', Fmt.euro(interest)),
          row('TOTALE + mora', Fmt.euro(inv.totalWithInterest(now)),
              bold: true),
        ],
      ],
    );
  }
}
