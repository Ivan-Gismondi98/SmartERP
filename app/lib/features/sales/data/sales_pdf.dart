// ============================================================
//  SMARTERP · sales_pdf.dart — generazione PDF di preventivi/ordini.
//  Riusa lo stile dei modelli Studio (colore primario, header/footer,
//  riepilogo IVA) come per le fatture.
// ============================================================
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/format.dart';
import '../../profile/domain/profile.dart';
import '../../studio/domain/document_template.dart';
import '../domain/sales_document.dart';

class SalesPdfGenerator {
  const SalesPdfGenerator();

  PdfColor _hex(String? hex, PdfColor fallback) {
    if (hex == null) return fallback;
    final h = hex.replaceAll('#', '').trim();
    if (h.length != 6) return fallback;
    final v = int.tryParse(h, radix: 16);
    return v == null ? fallback : PdfColor.fromInt(0xff000000 | v);
  }

  Future<List<int>> build(SalesDocument doc, Company seller,
      {DocumentTemplate? template}) async {
    final pdf = pw.Document();
    final brand =
        _hex(template?.primaryHex ?? seller.brandPrimaryHex, PdfColors.blue900);
    final showVat = template?.showVatSummary ?? true;
    final showLogo = template?.showLogo ?? true;

    pw.ImageProvider? logo;
    if (showLogo && seller.logoUrl != null) {
      try {
        logo = await networkImage(seller.logoUrl!);
      } catch (_) {
        logo = null;
      }
    }

    final headerText = template?.headerText ?? '';
    final footerText = template?.footerText ?? '';
    final validLabel =
        doc.kind == SalesKind.quote ? 'Valido fino al' : 'Consegna';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _header(seller, doc, brand, logo, validLabel),
          if (headerText.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(headerText,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey700)),
          ],
          pw.SizedBox(height: 6),
          pw.Container(height: 3, color: brand),
          pw.SizedBox(height: 16),
          _customer(doc),
          pw.SizedBox(height: 16),
          _items(doc),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (showVat) _vatSummary(doc) else pw.SizedBox(),
              _totals(doc, brand),
            ],
          ),
          if (doc.paymentTerms != null && doc.paymentTerms!.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('Condizioni di pagamento',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(doc.paymentTerms!),
          ],
          if (doc.notes != null && doc.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Note', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(doc.notes!),
          ],
        ],
        footer: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            if (footerText.isNotEmpty)
              pw.Text(footerText,
                  style:
                      const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Pag. ${context.pageNumber}/${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _header(Company seller, SalesDocument doc, PdfColor brand,
      pw.ImageProvider? logo, String validLabel) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Image(logo, height: 48),
              ),
            pw.Text(seller.name,
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: brand)),
            if (seller.vatNumber != null) pw.Text('P.IVA ${seller.vatNumber}'),
            if (seller.address != null)
              pw.Text(
                  '${seller.address}, ${seller.zip ?? ''} ${seller.city ?? ''} ${seller.province != null ? '(${seller.province})' : ''}'),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(doc.kindLabel.toUpperCase(),
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold, color: brand)),
            pw.Text('N. ${doc.displayNumber}'),
            pw.Text('Data ${Fmt.date(doc.issueDate)}'),
            if (doc.validUntil != null)
              pw.Text('$validLabel ${Fmt.date(doc.validUntil)}'),
          ],
        ),
      ],
    );
  }

  pw.Widget _customer(SalesDocument doc) {
    final c = doc.customer;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Cliente',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(c?.name ?? '—',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          if (c?.vatNumber != null) pw.Text('P.IVA ${c!.vatNumber}'),
          if (c?.taxCode != null) pw.Text('C.F. ${c!.taxCode}'),
          if ((c?.fullAddress ?? '').isNotEmpty) pw.Text(c!.fullAddress),
        ],
      ),
    );
  }

  pw.Widget _items(SalesDocument doc) {
    final widgets = <pw.Widget>[];
    for (final it in doc.items) {
      final iva = it.vatRate == 0
          ? (it.vatNature?.code ?? '0%')
          : Fmt.percent(it.vatRate);
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          children: [
            pw.Expanded(flex: 6, child: pw.Text(it.description)),
            pw.Expanded(
                flex: 3,
                child: pw.Text(
                    '${Fmt.qty(it.quantity)} × ${Fmt.euro(it.unitPrice)}'
                    '${it.discountPercent > 0 ? ' −${Fmt.percent(it.discountPercent)}' : ''}  · IVA $iva',
                    style: const pw.TextStyle(fontSize: 9))),
            pw.Expanded(
                flex: 2,
                child: pw.Text(Fmt.euro(it.taxableBase),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          ],
        ),
      ));
      widgets.add(pw.Divider(color: PdfColors.grey300, height: 8));
    }
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start, children: widgets);
  }

  pw.Widget _vatSummary(SalesDocument doc) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Riepilogo IVA',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: ['Aliquota', 'Imponibile', 'Imposta'],
          data: doc.vatSummary
              .map((l) => [
                    l.vatRate == 0
                        ? (l.nature?.code ?? 'Esente')
                        : Fmt.percent(l.vatRate),
                    Fmt.euro(l.taxable),
                    Fmt.euro(l.tax),
                  ])
              .toList(),
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
          },
        ),
      ],
    );
  }

  pw.Widget _totals(SalesDocument doc, PdfColor brand) {
    pw.Widget line(String l, String v, {bool bold = false}) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(l,
                style: pw.TextStyle(
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    fontSize: bold ? 12 : 10,
                    color: bold ? brand : null)),
            pw.SizedBox(width: 24),
            pw.Text(v,
                style: pw.TextStyle(
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    fontSize: bold ? 12 : 10,
                    color: bold ? brand : null)),
          ],
        );

    return pw.Container(
      width: 220,
      child: pw.Column(
        children: [
          line('Imponibile', Fmt.euro(doc.subtotal)),
          line('IVA', Fmt.euro(doc.taxAmount)),
          if (doc.stampDuty > 0) line('Bollo', Fmt.euro(doc.stampDuty)),
          pw.Divider(),
          line('TOTALE', Fmt.euro(doc.total), bold: true),
        ],
      ),
    );
  }
}
