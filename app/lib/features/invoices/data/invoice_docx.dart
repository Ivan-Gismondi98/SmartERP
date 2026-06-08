// ============================================================
//  SMARTERP · invoice_docx.dart — generazione documento Word (.docx).
//  Costruisce un pacchetto OOXML minimale (document.xml + rels +
//  content types) e lo comprime in zip. Rispetta il modello Studio
//  (header/footer, stile righe, riepilogo IVA). Le immagini prodotto
//  in Word sono una rifinitura successiva (nel PDF sono già incluse).
// ============================================================
import 'dart:convert';

import 'package:archive/archive.dart';

import '../../../core/format.dart';
import '../../profile/domain/profile.dart';
import '../../studio/domain/document_template.dart';
import '../domain/invoice.dart';

class InvoiceDocxGenerator {
  const InvoiceDocxGenerator();

  List<int> build(Invoice inv, Company seller,
      {DocumentTemplate? template, DateTime? now}) {
    final today = now ?? DateTime.now();
    final lineStyle = template?.lineStyle ?? 'auto';
    final showVat = template?.showVatSummary ?? true;
    final primary = (template?.primaryHex ?? seller.brandPrimaryHex)
        .replaceAll('#', '')
        .padLeft(6, '0');
    final interest = inv.interestAmount(today);

    final body = StringBuffer();

    // Intestazione azienda + tipo documento
    body.write(_p(seller.name, bold: true, size: 32, color: primary));
    if (seller.vatNumber != null) body.write(_p('P.IVA ${seller.vatNumber}'));
    if (seller.address != null) {
      body.write(_p(
          '${seller.address}, ${seller.zip ?? ''} ${seller.city ?? ''} ${seller.province != null ? '(${seller.province})' : ''}'));
    }
    if ((template?.headerText ?? '').isNotEmpty) {
      body.write(_p(template!.headerText, italic: true, color: '666666'));
    }
    body.write(_p(''));
    body.write(_p(
        '${inv.documentTypeLabel.toUpperCase()} n. ${inv.displayNumber} del ${Fmt.date(inv.issueDate)}',
        bold: true, size: 28, color: primary));
    if (inv.dueDate != null) {
      body.write(_p('Scadenza: ${Fmt.date(inv.dueDate)}'));
    }
    body.write(_p(''));

    // Cliente
    final c = inv.customer;
    body.write(_p('Cliente', bold: true, color: '666666'));
    body.write(_p(c?.name ?? '—', bold: true));
    if (c?.vatNumber != null) body.write(_p('P.IVA ${c!.vatNumber}'));
    if (c?.taxCode != null) body.write(_p('C.F. ${c!.taxCode}'));
    if ((c?.fullAddress ?? '').isNotEmpty) body.write(_p(c!.fullAddress));
    body.write(_p(''));

    // Righe
    body.write(_p('Dettaglio', bold: true, size: 24, color: primary));
    for (final it in inv.items) {
      final asCatalog = switch (lineStyle) {
        'catalog' => true,
        'compact' => false,
        _ => it.isCatalog,
      };
      if (asCatalog) {
        body.write(_p(it.productName ?? it.description,
            bold: true, color: primary));
        body.write(_p(it.description));
        body.write(_p(
            '${Fmt.qty(it.quantity)} × ${Fmt.euro(it.unitPrice)}'
            '${it.discountPercent > 0 ? '  −${Fmt.percent(it.discountPercent)}' : ''}'
            '   ·   IVA ${it.vatRate == 0 ? (it.vatNature?.code ?? '0%') : Fmt.percent(it.vatRate)}'
            '   ·   Totale: ${Fmt.euro(it.taxableBase)}',
            italic: true));
        body.write(_p(''));
      } else {
        body.write(_p(
            '${it.description}  —  ${Fmt.qty(it.quantity)} × ${Fmt.euro(it.unitPrice)} = ${Fmt.euro(it.taxableBase)}'));
      }
    }
    body.write(_p(''));

    // Riepilogo IVA
    if (showVat) {
      body.write(_p('Riepilogo IVA', bold: true, color: '666666'));
      for (final l in inv.vatSummary) {
        final label = l.vatRate == 0
            ? (l.nature?.code ?? 'Esente')
            : Fmt.percent(l.vatRate);
        body.write(_p(
            'Aliquota $label  ·  Imponibile ${Fmt.euro(l.taxable)}  ·  Imposta ${Fmt.euro(l.tax)}'));
      }
      body.write(_p(''));
    }

    // Totali
    body.write(_p('Imponibile: ${Fmt.euro(inv.subtotal)}'));
    body.write(_p('IVA: ${Fmt.euro(inv.taxAmount)}'));
    if (inv.stampDuty > 0) body.write(_p('Bollo: ${Fmt.euro(inv.stampDuty)}'));
    body.write(_p('TOTALE: ${Fmt.euro(inv.total)}',
        bold: true, size: 26, color: primary));
    if (interest > 0) {
      body.write(_p(
          'Interessi di mora (${Fmt.percent(inv.interestRate ?? 0)}): ${Fmt.euro(interest)}'));
      body.write(_p('TOTALE + mora: ${Fmt.euro(inv.totalWithInterest(today))}',
          bold: true));
    }

    if ((template?.footerText ?? '').isNotEmpty) {
      body.write(_p(''));
      body.write(_p(template!.footerText, italic: true, color: '666666'));
    }

    return _zipDocx(_documentXml(body.toString()));
  }

  // ---------- helper OOXML ----------

  String _esc(String s) => const HtmlEscape().convert(s);

  /// Paragrafo con run formattato.
  String _p(String text,
      {bool bold = false, bool italic = false, int? size, String? color}) {
    final rPr = StringBuffer('<w:rPr>');
    if (bold) rPr.write('<w:b/>');
    if (italic) rPr.write('<w:i/>');
    if (color != null) rPr.write('<w:color w:val="$color"/>');
    if (size != null) rPr.write('<w:sz w:val="$size"/>');
    rPr.write('</w:rPr>');
    return '<w:p><w:r>$rPr<w:t xml:space="preserve">${_esc(text)}</w:t></w:r></w:p>';
  }

  String _documentXml(String body) => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body>$body'
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/></w:sectPr>'
      '</w:body></w:document>';

  List<int> _zipDocx(String documentXml) {
    const contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>';
    const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';

    final archive = Archive();
    void add(String path, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    add('[Content_Types].xml', contentTypes);
    add('_rels/.rels', rels);
    add('word/document.xml', documentXml);

    return ZipEncoder().encode(archive)!;
  }
}
