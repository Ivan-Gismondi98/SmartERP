// ============================================================
//  SMARTERP · report_io.dart — export multi-formato (Excel/CSV/XML/PDF/Word)
//  e import (Excel/CSV) per gli elenchi applicativi. Le intestazioni di
//  import ed export coincidono.
// ============================================================
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

import '../xlsx.dart';

enum ReportFormat { xlsx, csv, xml, pdf, docx }

extension ReportFormatX on ReportFormat {
  String get label => switch (this) {
        ReportFormat.xlsx => 'Excel (.xlsx)',
        ReportFormat.csv => 'CSV',
        ReportFormat.xml => 'XML',
        ReportFormat.pdf => 'PDF',
        ReportFormat.docx => 'Word (.docx)',
      };
  String get ext => switch (this) {
        ReportFormat.xlsx => 'xlsx',
        ReportFormat.csv => 'csv',
        ReportFormat.xml => 'xml',
        ReportFormat.pdf => 'pdf',
        ReportFormat.docx => 'docx',
      };
}

class ReportIO {
  const ReportIO._();

  // ---------------- EXPORT ----------------
  static Future<void> export({
    required ReportFormat format,
    required String fileBase,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final bytes = switch (format) {
      ReportFormat.xlsx =>
        XlsxBuilder.build(headers: headers, rows: rows, sheetName: fileBase),
      ReportFormat.csv => _csv(headers, rows),
      ReportFormat.xml => _xml(fileBase, headers, rows),
      ReportFormat.pdf => await _pdf(fileBase, headers, rows),
      ReportFormat.docx => _docx(headers, rows),
    };
    final mime = switch (format) {
      ReportFormat.xlsx => MimeType.microsoftExcel,
      ReportFormat.csv => MimeType.csv,
      ReportFormat.xml => MimeType.other,
      ReportFormat.pdf => MimeType.pdf,
      ReportFormat.docx => MimeType.microsoftWord,
    };
    await FileSaver.instance.saveFile(
      name: fileBase,
      bytes: Uint8List.fromList(bytes),
      ext: format.ext,
      mimeType: mime,
    );
  }

  static List<int> _csv(List<String> headers, List<List<String>> rows) {
    String cell(String v) {
      final needsQuote =
          v.contains(';') || v.contains('"') || v.contains('\n') || v.contains('\r');
      final s = v.replaceAll('"', '""');
      return needsQuote ? '"$s"' : s;
    }

    final sb = StringBuffer();
    sb.writeln(headers.map(cell).join(';'));
    for (final r in rows) {
      sb.writeln(r.map(cell).join(';'));
    }
    // BOM UTF-8 per corretta apertura in Excel.
    return [0xEF, 0xBB, 0xBF, ...utf8.encode(sb.toString())];
  }

  static List<int> _xml(
      String root, List<String> headers, List<List<String>> rows) {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8"');
    b.element('rows', nest: () {
      for (final r in rows) {
        b.element('row', nest: () {
          for (var i = 0; i < headers.length; i++) {
            b.element('field', nest: () {
              b.attribute('name', headers[i]);
              b.text(i < r.length ? r[i] : '');
            });
          }
        });
      }
    });
    return utf8.encode(b.buildDocument().toXmlString(pretty: true));
  }

  static Future<List<int>> _pdf(
      String title, List<String> headers, List<List<String>> rows) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(title,
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static List<int> _docx(List<String> headers, List<List<String>> rows) {
    String esc(String s) => const HtmlEscape().convert(s);
    String cell(String v, {bool bold = false}) =>
        '<w:tc><w:p><w:r><w:rPr>${bold ? '<w:b/>' : ''}</w:rPr>'
        '<w:t xml:space="preserve">${esc(v)}</w:t></w:r></w:p></w:tc>';
    final sb = StringBuffer('<w:tbl><w:tblPr><w:tblBorders>'
        '<w:top w:val="single" w:sz="4"/><w:left w:val="single" w:sz="4"/>'
        '<w:bottom w:val="single" w:sz="4"/><w:right w:val="single" w:sz="4"/>'
        '<w:insideH w:val="single" w:sz="4"/><w:insideV w:val="single" w:sz="4"/>'
        '</w:tblBorders></w:tblPr>');
    sb.write('<w:tr>${headers.map((h) => cell(h, bold: true)).join()}</w:tr>');
    for (final r in rows) {
      sb.write('<w:tr>${[
        for (var i = 0; i < headers.length; i++) cell(i < r.length ? r[i] : '')
      ].join()}</w:tr>');
    }
    sb.write('</w:tbl>');

    final document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>$sb<w:sectPr><w:pgSz w:w="16838" w:h="11906" w:orient="landscape"/>'
        '<w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720"/></w:sectPr>'
        '</w:body></w:document>';
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
    void add(String p, String c) {
      final b = utf8.encode(c);
      archive.addFile(ArchiveFile(p, b.length, b));
    }

    add('[Content_Types].xml', contentTypes);
    add('_rels/.rels', rels);
    add('word/document.xml', document);
    return ZipEncoder().encode(archive)!;
  }

  // ---------------- IMPORT ----------------
  /// Parsa un file (.csv o .xlsx) in righe come mappe intestazione→valore.
  static List<Map<String, String>> parse(List<int> bytes, String ext) {
    final table =
        ext.toLowerCase() == 'csv' ? _readCsv(bytes) : _readXlsx(bytes);
    if (table.isEmpty) return const [];
    final headers = table.first.map((h) => h.trim()).toList();
    final out = <Map<String, String>>[];
    for (var r = 1; r < table.length; r++) {
      final row = table[r];
      if (row.every((c) => c.trim().isEmpty)) continue;
      final m = <String, String>{};
      for (var c = 0; c < headers.length; c++) {
        m[headers[c]] = c < row.length ? row[c].trim() : '';
      }
      out.add(m);
    }
    return out;
  }

  static List<List<String>> _readCsv(List<int> bytes) {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1); // togli BOM
    }
    // Rileva separatore: ';' (Excel IT) o ','.
    final firstLine = text.split(RegExp(r'\r?\n')).first;
    final sep = firstLine.contains(';') ? ';' : ',';
    final rows = <List<String>>[];
    final field = StringBuffer();
    var row = <String>[];
    var inQuotes = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == sep) {
        row.add(field.toString());
        field.clear();
      } else if (ch == '\n') {
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
      } else if (ch == '\r') {
        // ignora
      } else {
        field.write(ch);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }

  static List<List<String>> _readXlsx(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? find(String name) {
      for (final f in archive.files) {
        if (f.name == name) return f;
      }
      return null;
    }

    // Shared strings (se presenti).
    final shared = <String>[];
    final ss = find('xl/sharedStrings.xml');
    if (ss != null) {
      final doc = XmlDocument.parse(utf8.decode(ss.content as List<int>));
      for (final si in doc.findAllElements('si')) {
        // Concatena i nodi <t> (gestisce rich text con più run).
        final t = si.findAllElements('t').map((e) => e.innerText).join();
        shared.add(t);
      }
    }

    // Primo foglio.
    final sheet = find('xl/worksheets/sheet1.xml') ??
        archive.files
            .where((f) => f.name.startsWith('xl/worksheets/'))
            .cast<ArchiveFile?>()
            .firstWhere((_) => true, orElse: () => null);
    if (sheet == null) return const [];
    final doc = XmlDocument.parse(utf8.decode(sheet.content as List<int>));

    final result = <List<String>>[];
    for (final rowEl in doc.findAllElements('row')) {
      final cells = <int, String>{};
      var maxCol = -1;
      for (final cEl in rowEl.findAllElements('c')) {
        final ref = cEl.getAttribute('r') ?? '';
        final col = _colIndex(ref);
        final type = cEl.getAttribute('t');
        String value;
        if (type == 'inlineStr') {
          value = cEl.findAllElements('t').map((e) => e.innerText).join();
        } else {
          final v = cEl.findElements('v').isEmpty
              ? ''
              : cEl.findElements('v').first.innerText;
          if (type == 's') {
            final idx = int.tryParse(v) ?? -1;
            value = (idx >= 0 && idx < shared.length) ? shared[idx] : '';
          } else {
            value = v;
          }
        }
        cells[col] = value;
        if (col > maxCol) maxCol = col;
      }
      final list = <String>[];
      for (var i = 0; i <= maxCol; i++) {
        list.add(cells[i] ?? '');
      }
      result.add(list);
    }
    return result;
  }

  /// Indice colonna 0-based dal riferimento cella (es. "C5" -> 2).
  static int _colIndex(String ref) {
    var i = 0;
    var col = 0;
    while (i < ref.length && ref.codeUnitAt(i) >= 65 && ref.codeUnitAt(i) <= 90) {
      col = col * 26 + (ref.codeUnitAt(i) - 64);
      i++;
    }
    return col - 1;
  }
}
