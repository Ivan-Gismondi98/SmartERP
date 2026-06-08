// ============================================================
//  SMARTERP · xlsx.dart — generatore .xlsx minimale (OOXML SpreadsheetML).
//  Una sola foglio, celle come inlineStr. Valido e apribile in Excel.
// ============================================================
import 'dart:convert';

import 'package:archive/archive.dart';

class XlsxBuilder {
  const XlsxBuilder._();

  /// Costruisce un .xlsx da intestazioni + righe (tutte celle testo).
  static List<int> build({
    required List<String> headers,
    required List<List<String>> rows,
    String sheetName = 'Segnalazioni',
  }) {
    final all = <List<String>>[headers, ...rows];
    final sb = StringBuffer();
    sb.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>');
    for (var r = 0; r < all.length; r++) {
      sb.write('<row r="${r + 1}">');
      for (var c = 0; c < all[r].length; c++) {
        final ref = '${_col(c)}${r + 1}';
        sb.write('<c r="$ref" t="inlineStr"><is><t xml:space="preserve">'
            '${_esc(all[r][c])}</t></is></c>');
      }
      sb.write('</row>');
    }
    sb.write('</sheetData></worksheet>');

    const contentTypes =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '</Types>';
    const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>';
    final workbook = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="${_esc(sheetName)}" sheetId="1" r:id="rId1"/></sheets></workbook>';
    const workbookRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '</Relationships>';

    final archive = Archive();
    void add(String path, String content) {
      final b = utf8.encode(content);
      archive.addFile(ArchiveFile(path, b.length, b));
    }

    add('[Content_Types].xml', contentTypes);
    add('_rels/.rels', rels);
    add('xl/workbook.xml', workbook);
    add('xl/_rels/workbook.xml.rels', workbookRels);
    add('xl/worksheets/sheet1.xml', sb.toString());

    return ZipEncoder().encode(archive)!;
  }

  static String _col(int index) {
    var i = index;
    var s = '';
    while (true) {
      s = String.fromCharCode(65 + (i % 26)) + s;
      i = i ~/ 26 - 1;
      if (i < 0) break;
    }
    return s;
  }

  static String _esc(String s) => const HtmlEscape().convert(s);
}
