// ============================================================
//  SMARTERP · journal_entry.dart — registrazione di prima nota (partita
//  doppia) + righe dare/avere. Vincolo: totale dare = totale avere.
// ============================================================
import '../../../core/format.dart';

class JournalLine {
  JournalLine({
    this.id,
    this.position = 0,
    this.accountId,
    this.accountCode,
    this.accountName,
    this.description,
    this.debit = 0,
    this.credit = 0,
    this.costCenterId,
    this.costCenterCode,
  });

  final String? id;
  int position;
  String? accountId;
  String? accountCode; // sola lettura (join)
  String? accountName; // sola lettura (join)
  String? description;
  double debit; // dare
  double credit; // avere
  String? costCenterId;
  String? costCenterCode; // sola lettura (join)

  factory JournalLine.fromJson(Map<String, dynamic> j) {
    final acc = j['accounting_accounts'] as Map?;
    final cc = j['accounting_cost_centers'] as Map?;
    return JournalLine(
      id: j['id'] as String?,
      position: (j['position'] as num?)?.toInt() ?? 0,
      accountId: j['account_id'] as String?,
      accountCode: acc?['code'] as String?,
      accountName: acc?['name'] as String?,
      description: j['description'] as String?,
      debit: (j['debit'] as num?)?.toDouble() ?? 0,
      credit: (j['credit'] as num?)?.toDouble() ?? 0,
      costCenterId: j['cost_center_id'] as String?,
      costCenterCode: cc?['code'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'position': position,
        'account_id': accountId,
        'description':
            (description == null || description!.trim().isEmpty) ? null : description!.trim(),
        'debit': round2(debit),
        'credit': round2(credit),
        'cost_center_id': costCenterId,
      };

  JournalLine copy() => JournalLine(
        position: position,
        accountId: accountId,
        accountCode: accountCode,
        accountName: accountName,
        description: description,
        debit: debit,
        credit: credit,
        costCenterId: costCenterId,
        costCenterCode: costCenterCode,
      );
}

class JournalEntry {
  JournalEntry({
    this.id,
    required this.companyId,
    DateTime? entryDate,
    this.description = '',
    this.docRef,
    this.entryNumber,
    this.numberingYear,
    this.numberingSeq,
    List<JournalLine>? lines,
  })  : entryDate = entryDate ?? DateTime.now(),
        lines = lines ?? [];

  final String? id;
  final String companyId;
  DateTime entryDate;
  String description;
  String? docRef;
  String? entryNumber;
  int? numberingYear;
  int? numberingSeq;
  List<JournalLine> lines;

  String get displayNumber => entryNumber ?? 'BOZZA';

  double get totalDebit => round2(lines.fold<double>(0, (s, l) => s + l.debit));
  double get totalCredit =>
      round2(lines.fold<double>(0, (s, l) => s + l.credit));

  /// Differenza dare-avere (0 = quadrata).
  double get balanceDiff => round2(totalDebit - totalCredit);

  /// Partita doppia rispettata: dare = avere e almeno un movimento.
  bool get isBalanced => balanceDiff == 0 && totalDebit > 0;

  factory JournalEntry.fromJson(Map<String, dynamic> j) {
    final linesJson = (j['accounting_lines'] as List?) ?? const [];
    final lines = linesJson
        .cast<Map<String, dynamic>>()
        .map(JournalLine.fromJson)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return JournalEntry(
      id: j['id'] as String,
      companyId: j['company_id'] as String,
      entryDate: DateTime.parse(j['entry_date'] as String),
      description: (j['description'] as String?) ?? '',
      docRef: j['doc_ref'] as String?,
      entryNumber: j['entry_number'] as String?,
      numberingYear: (j['numbering_year'] as num?)?.toInt(),
      numberingSeq: (j['numbering_seq'] as num?)?.toInt(),
      lines: lines,
    );
  }

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'entry_date': _d(entryDate),
        'description': description.trim(),
        'doc_ref': (docRef == null || docRef!.trim().isEmpty) ? null : docRef!.trim(),
      };

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
