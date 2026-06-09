// ============================================================
//  SMARTERP · sales_detail_page.dart — dettaglio preventivo/ordine.
//  Azioni: modifica/elimina, conferma (numerazione), accetta/rifiuta,
//  conversione in fattura (modulo Fatture), duplica.
// ============================================================
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../invoices/data/invoices_repository.dart';
import '../../invoices/domain/invoice.dart';
import '../../invoices/presentation/invoice_form_page.dart';
import '../../profile/application/profile_providers.dart';
import '../../studio/data/templates_repository.dart';
import '../application/sales_providers.dart';
import '../data/sales_docx.dart';
import '../data/sales_repository.dart';
import '../domain/sales_document.dart';
import 'sales_form_page.dart';
import 'sales_pdf_page.dart';

class SalesDetailPage extends ConsumerWidget {
  const SalesDetailPage({super.key, required this.documentId});
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(salesDetailProvider(documentId));
    final canEdit = ref.watch(canProvider(Perm.salesEdit));
    final canIssue = ref.watch(canProvider(Perm.salesIssue));
    final canDelete = ref.watch(canProvider(Perm.salesDelete));
    final canCreate = ref.watch(canProvider(Perm.salesCreate));
    final canConvert = ref.watch(canProvider(Perm.salesConvert)) &&
        ref.watch(canProvider(Perm.invoicesCreate));

    return Scaffold(
      appBar: AppBar(title: const Text('Dettaglio documento')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (doc) => _DetailBody(
          doc: doc,
          canEdit: canEdit,
          canIssue: canIssue,
          canDelete: canDelete,
          canCreate: canCreate,
          canConvert: canConvert,
          onChanged: () => ref.invalidate(salesDetailProvider(documentId)),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.doc,
    required this.canEdit,
    required this.canIssue,
    required this.canDelete,
    required this.canCreate,
    required this.canConvert,
    required this.onChanged,
  });

  final SalesDocument doc;
  final bool canEdit;
  final bool canIssue;
  final bool canDelete;
  final bool canCreate;
  final bool canConvert;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(salesRepositoryProvider);
    final now = DateTime.now();
    final expired = doc.expiredAt(now);

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
                    child: Text('${doc.kindLabel} ${doc.displayNumber}',
                        style: theme.textTheme.headlineSmall),
                  ),
                  Chip(label: Text(doc.status.label)),
                ],
              ),
              Text('Data: ${Fmt.date(doc.issueDate)}'
                  '${doc.validUntil != null ? '  ·  ${doc.kind == SalesKind.quote ? 'Valido fino al' : 'Consegna'}: ${Fmt.date(doc.validUntil)}' : ''}'),
              if (expired)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Offerta scaduta',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.orange.shade800)),
                ),
              if (doc.isConverted && doc.convertedInvoiceId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Convertito in fattura',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.teal.shade700)),
                ),
              const Divider(height: 32),
              Text('Cliente', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(doc.customer?.name ?? '—', style: theme.textTheme.titleSmall),
              if (doc.customer?.vatNumber != null)
                Text('P.IVA ${doc.customer!.vatNumber}'),
              if ((doc.customer?.fullAddress ?? '').isNotEmpty)
                Text(doc.customer!.fullAddress),
              const Divider(height: 32),
              Text('Righe', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _ItemsTable(doc: doc),
              const Divider(height: 32),
              Text('Riepilogo IVA', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _VatSummaryTable(doc: doc),
              const SizedBox(height: 16),
              _TotalsBox(doc: doc),
              if (doc.paymentTerms != null && doc.paymentTerms!.isNotEmpty) ...[
                const Divider(height: 32),
                Text('Pagamento', style: theme.textTheme.titleMedium),
                Text(doc.paymentTerms!),
              ],
              if (doc.notes != null && doc.notes!.isNotEmpty) ...[
                const Divider(height: 32),
                Text('Note', style: theme.textTheme.titleMedium),
                Text(doc.notes!),
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
                if (doc.isDraft && canDelete)
                  OutlinedButton.icon(
                    onPressed: () => _delete(context, repo),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Elimina'),
                  ),
                if (doc.isDraft && canEdit)
                  OutlinedButton.icon(
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifica'),
                  ),
                if (doc.isDraft && canIssue)
                  FilledButton.icon(
                    onPressed: () => _confirm(context, repo),
                    icon: const Icon(Icons.send),
                    label: const Text('Conferma'),
                  ),
                if (doc.status == SalesStatus.sent && canEdit) ...[
                  FilledButton.icon(
                    onPressed: () => _mark(context, repo, SalesStatus.accepted),
                    icon: const Icon(Icons.thumb_up_alt_outlined),
                    label: const Text('Accetta'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _mark(context, repo, SalesStatus.rejected),
                    icon: const Icon(Icons.thumb_down_alt_outlined),
                    label: const Text('Rifiuta'),
                  ),
                ],
                if ((doc.status == SalesStatus.accepted ||
                        doc.status == SalesStatus.sent) &&
                    canConvert)
                  FilledButton.tonalIcon(
                    onPressed: () => _convert(context, ref),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Converti in fattura'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SalesPdfPage(doc: doc))),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Stampa PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _downloadWord(context, ref),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Word'),
                ),
                if (canCreate)
                  OutlinedButton.icon(
                    onPressed: () => _duplicate(context, ref),
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Duplica'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadWord(BuildContext context, WidgetRef ref) async {
    try {
      final profile = await ref.read(currentProfileProvider.future);
      final company = profile?.company;
      if (company == null) {
        if (context.mounted) _snack(context, 'Dati azienda mancanti.');
        return;
      }
      final template = doc.templateId == null
          ? null
          : await ref
              .read(templatesRepositoryProvider)
              .getById(doc.templateId!);
      final bytes =
          const SalesDocxGenerator().build(doc, company, template: template);
      await FileSaver.instance.saveFile(
        name: '${doc.kindLabel}_${doc.displayNumber.replaceAll('/', '-')}',
        bytes: Uint8List.fromList(bytes),
        ext: 'docx',
        mimeType: MimeType.microsoftWord,
      );
      if (context.mounted) _snack(context, 'Word generato.');
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore Word: $e');
    }
  }

  Future<void> _edit(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SalesFormPage(documentId: doc.id)),
    );
    if (changed == true) onChanged();
  }

  Future<void> _confirm(BuildContext context, SalesRepository repo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confermare il ${doc.kind.label.toLowerCase()}?'),
        content: const Text(
            'Verrà assegnato un numero progressivo e il documento passerà '
            'in stato "Inviato".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Conferma')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final number = await repo.confirm(doc);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Documento n. $number')));
      }
      onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  /// Crea una bozza di FATTURA (TD01) dalle righe del documento, collega la
  /// fattura al documento e lo segna "convertito", quindi apre l'editor fattura.
  Future<void> _convert(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Convertire in fattura?'),
        content: const Text(
            'Verrà creata una bozza di fattura con le stesse righe. '
            'Potrai rivederla ed emetterla dal modulo Fatture.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Converti')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final invoicesRepo = ref.read(invoicesRepositoryProvider);
      final invoice = Invoice(
        companyId: doc.companyId,
        customerId: doc.customerId,
        customer: doc.customer,
        documentType: 'TD01',
        stampDuty: doc.stampDuty,
        paymentTerms: doc.paymentTerms,
        paymentTermsDays: doc.paymentTermsDays,
        notes: doc.notes,
        items: [
          for (final it in doc.items)
            InvoiceItem(
              productId: it.productId,
              description: it.description,
              quantity: it.quantity,
              unitPrice: it.unitPrice,
              vatRate: it.vatRate,
              vatNature: it.vatNature,
              discountPercent: it.discountPercent,
            ),
        ],
      );
      final invoiceId = await invoicesRepo.createDraft(invoice);
      await ref.read(salesRepositoryProvider).markConverted(doc.id!, invoiceId);
      onChanged();
      if (!context.mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => InvoiceFormPage(invoiceId: invoiceId)),
      );
      onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore conversione: $e');
    }
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref) async {
    try {
      final newId = await ref.read(salesRepositoryProvider).duplicateFrom(doc);
      if (!context.mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => SalesFormPage(documentId: newId)),
      );
      onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  Future<void> _mark(
      BuildContext context, SalesRepository repo, SalesStatus s) async {
    try {
      await repo.setStatus(doc.id!, s);
      onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  Future<void> _delete(BuildContext context, SalesRepository repo) async {
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
      await repo.delete(doc.id!);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) _snack(context, 'Errore: $e');
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ItemsTable extends StatelessWidget {
  const _ItemsTable({required this.doc});
  final SalesDocument doc;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final it in doc.items)
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
  const _VatSummaryTable({required this.doc});
  final SalesDocument doc;

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
        for (final l in doc.vatSummary)
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
  const _TotalsBox({required this.doc});
  final SalesDocument doc;

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

    return Column(
      children: [
        row('Imponibile', Fmt.euro(doc.subtotal)),
        row('IVA', Fmt.euro(doc.taxAmount)),
        if (doc.stampDuty > 0) row('Bollo', Fmt.euro(doc.stampDuty)),
        const Divider(),
        row('TOTALE', Fmt.euro(doc.total), bold: true),
      ],
    );
  }
}
