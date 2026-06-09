// ============================================================
//  SMARTERP · sales_docx.dart — generazione documento Word (.docx) di
//  preventivi/ordini. Pacchetto OOXML minimale, stile dei modelli Studio.
// ============================================================
import 'dart:convert';

import 'package:archive/archive.dart';

import '../../../core/format.dart';
import '../../profile/domain/profile.dart';
import '../../studio/domain/document_template.dart';
import '../domain/sales_document.dart';

class SalesDocxGenerator {
  const SalesDocxGenerator();

  List<int> build(SalesDocument doc, Company seller,
      {DocumentTemplate? template}) {
    final showVat = template?.showVatSummary ?? true;
    final primary = (template?.primaryHex ?? seller.brandPrimaryHex)
        .replaceAll('#', '')
        .padLeft(6, '0');
    final validLabel =
        doc.kind == SalesKind.quote ? 'Valido fino al' : 'Consegna';

    final body = StringBuffer();

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
        '${doc.kindLabel.toUpperCase()} n. ${doc.displayNumber} del ${Fmt.date(doc.issueDate)}',
        bold: true, size: 28, color: primary));
    if (doc.validUntil != null) {
      body.write(_p('$validLabel: ${Fmt.date(doc.validUntil)}'));
    }
    body.write(_p(''));

    final c = doc.customer;
    body.write(_p('Cliente', bold: true, color: '666666'));
    body.write(_p(c?.name ?? '—', bold: true));
    if (c?.vatNumber != null) body.write(_p('P.IVA ${c!.vatNumber}'));
    if (c?.taxCode != null) body.write(_p('C.F. ${c!.taxCode}'));
    if ((c?.fullAddress ?? '').isNotEmpty) body.write(_p(c!.fullAddress));
    body.write(_p(''));

    body.write(_p('Dettaglio', bold: true, size: 24, color: primary));
    for (final it in doc.items) {
      body.write(_p(
          '${it.description}  —  ${Fmt.qty(it.quantity)} × ${Fmt.euro(it.unitPrice)}'
          '${it.discountPercent > 0 ? '  −${Fmt.percent(it.discountPercent)}' : ''}'
          '  ·  IVA ${it.vatRate == 0 ? (it.vatNature?.code ?? '0%') : Fmt.percent(it.vatRate)}'
          '  =  ${Fmt.euro(it.taxableBase)}'));
    }
    body.write(_p(''));

    if (showVat) {
      body.write(_p('Riepilogo IVA', bold: true, color: '666666'));
      for (final l in doc.vatSummary) {
        final label = l.vatRate == 0
            ? (l.nature?.code ?? 'Esente')
            : Fmt.percent(l.vatRate);
        body.write(_p(
            'Aliquota $label  ·  Imponibile ${Fmt.euro(l.taxable)}  ·  Imposta ${Fmt.euro(l.tax)}'));
      }
      body.write(_p(''));
    }

    body.write(_p('Imponibile: ${Fmt.euro(doc.subtotal)}'));
    body.write(_p('IVA: ${Fmt.euro(doc.taxAmount)}'));
    if (doc.stampDuty > 0) body.write(_p('Bollo: ${Fmt.euro(doc.stampDuty)}'));
    body.write(_p('TOTALE: ${Fmt.euro(doc.total)}',
        bold: true, size: 26, color: primary));

    if (doc.paymentTerms != null && doc.paymentTerms!.isNotEmpty) {
      body.write(_p(''));
      body.write(_p('Condizioni di pagamento', bold: true, color: '666666'));
      body.write(_p(doc.paymentTerms!));
    }
    if (doc.notes != null && doc.notes!.isNotEmpty) {
      body.write(_p(''));
      body.write(_p('Note', bold: true, color: '666666'));
      body.write(_p(doc.notes!));
    }
    if ((template?.footerText ?? '').isNotEmpty) {
      body.write(_p(''));
      body.write(_p(template!.footerText, italic: true, color: '666666'));
    }

    return _zipDocx(_documentXml(body.toString()));
  }

  String _esc(String s) => const HtmlEscape().convert(s);

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

  String _documentXml(String body) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body>$body'
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/></w:sectPr>'
      '</w:body></w:document>';

  List<int> _zipDocx(String documentXml) {
    const contentTypes =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
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
