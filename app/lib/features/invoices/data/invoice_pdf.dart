// ============================================================
//  SMARTERP · invoice_pdf.dart — generazione PDF della fattura.
//  Layout: intestazione cedente, dati cliente, righe, riepilogo IVA,
//  totali, bollo ed eventuali interessi di mora.
// ============================================================
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/format.dart';
import '../../profile/domain/profile.dart';
import '../domain/invoice.dart';

class InvoicePdfGenerator {
  const InvoicePdfGenerator();

  /// Converte "#RRGGBB" in PdfColor (con fallback).
  PdfColor _hex(String? hex, PdfColor fallback) {
    if (hex == null) return fallback;
    final h = hex.replaceAll('#', '').trim();
    if (h.length != 6) return fallback;
    final v = int.tryParse(h, radix: 16);
    return v == null ? fallback : PdfColor.fromInt(0xff000000 | v);
  }

  Future<List<int>> build(Invoice inv, Company seller, {DateTime? now}) async {
    final today = now ?? DateTime.now();
    final doc = pw.Document();
    final interest = inv.interestAmount(today);
    final brand = _hex(seller.brandPrimaryHex, PdfColors.blue900);

    // Logo per-tenant (se impostato e raggiungibile).
    pw.ImageProvider? logo;
    if (seller.logoUrl != null) {
      try {
        logo = await networkImage(seller.logoUrl!);
      } catch (_) {
        logo = null;
      }
    }

    // Pre-carica le immagini dei prodotti in "stile catalogo" (dedup per URL).
    final images = <String, pw.ImageProvider>{};
    for (final it in inv.items.where((i) => i.isCatalog)) {
      final url = it.productImageUrl!.trim();
      if (images.containsKey(url)) continue;
      try {
        images[url] = await networkImage(url);
      } catch (_) {/* immagine non raggiungibile: si ignora */}
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _header(seller, inv, brand, logo),
          pw.SizedBox(height: 6),
          pw.Container(height: 3, color: brand),
          pw.SizedBox(height: 16),
          _parties(seller, inv),
          pw.SizedBox(height: 16),
          _items(inv, brand, images),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _vatSummary(inv),
              _totals(inv, interest, today, brand),
            ],
          ),
          if (interest > 0) ...[
            pw.SizedBox(height: 12),
            _interestBox(inv, interest, today),
          ],
          if (inv.notes != null && inv.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('Note', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(inv.notes!),
          ],
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Pag. ${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
        ),
      ),
    );

    return doc.save();
  }

  pw.Widget _header(
      Company seller, Invoice inv, PdfColor brand, pw.ImageProvider? logo) {
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
            pw.Text(inv.documentTypeLabel.toUpperCase(),
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold, color: brand)),
            pw.Text('N. ${inv.displayNumber}'),
            pw.Text('Data ${Fmt.date(inv.issueDate)}'),
            if (inv.dueDate != null)
              pw.Text('Scadenza ${Fmt.date(inv.dueDate)}'),
          ],
        ),
      ],
    );
  }

  pw.Widget _parties(Company seller, Invoice inv) {
    final c = inv.customer;
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
          if ((c?.sdiCode ?? '').isNotEmpty)
            pw.Text('Codice Destinatario: ${c!.sdiCode}'),
        ],
      ),
    );
  }

  /// Righe del documento: blocco "catalogo" (titolo + immagine + descrizione)
  /// per i prodotti con flag attivo, riga compatta per gli altri.
  pw.Widget _items(
      Invoice inv, PdfColor brand, Map<String, pw.ImageProvider> images) {
    final widgets = <pw.Widget>[];
    for (final it in inv.items) {
      if (it.isCatalog) {
        widgets.add(_catalogLine(it, brand, images[it.productImageUrl!.trim()]));
      } else {
        widgets.add(_compactLine(it));
      }
      widgets.add(pw.Divider(color: PdfColors.grey300, height: 8));
    }
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: widgets);
  }

  pw.Widget _compactLine(InvoiceItem it) {
    final iva = it.vatRate == 0
        ? (it.vatNature?.code ?? '0%')
        : Fmt.percent(it.vatRate);
    return pw.Padding(
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
    );
  }

  pw.Widget _catalogLine(
      InvoiceItem it, PdfColor brand, pw.ImageProvider? image) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(it.productName ?? it.description,
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, color: brand)),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (image != null)
                pw.Container(
                  width: 110,
                  height: 110,
                  margin: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(image, fit: pw.BoxFit.cover),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(it.description,
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 6),
                    pw.Text(
                        '${Fmt.qty(it.quantity)} × ${Fmt.euro(it.unitPrice)}'
                        '${it.discountPercent > 0 ? '  −${Fmt.percent(it.discountPercent)}' : ''}'
                        '   ·   IVA ${it.vatRate == 0 ? (it.vatNature?.code ?? '0%') : Fmt.percent(it.vatRate)}',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 2),
                    pw.Text('Totale riga: ${Fmt.euro(it.taxableBase)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _vatSummary(Invoice inv) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Riepilogo IVA',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: ['Aliquota', 'Imponibile', 'Imposta'],
          data: inv.vatSummary
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

  pw.Widget _totals(
      Invoice inv, double interest, DateTime now, PdfColor brand) {
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
          line('Imponibile', Fmt.euro(inv.subtotal)),
          line('IVA', Fmt.euro(inv.taxAmount)),
          if (inv.stampDuty > 0) line('Bollo', Fmt.euro(inv.stampDuty)),
          pw.Divider(),
          line('TOTALE', Fmt.euro(inv.total), bold: true),
          if (interest > 0)
            line('TOTALE + mora', Fmt.euro(inv.totalWithInterest(now)),
                bold: true),
        ],
      ),
    );
  }

  pw.Widget _interestBox(Invoice inv, double interest, DateTime now) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange50,
        border: pw.Border.all(color: PdfColors.orange200),
      ),
      child: pw.Text(
        'Fattura scaduta da ${inv.daysLate(now)} giorni. '
        'Interessi di mora (${Fmt.percent(inv.interestRate ?? 0)} annuo): '
        '${Fmt.euro(interest)}.',
        style: const pw.TextStyle(fontSize: 10),
      ),
    );
  }
}
