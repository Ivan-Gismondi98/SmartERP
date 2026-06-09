// ============================================================
//  SMARTERP · sales_document.dart — documento di vendita (preventivo/ordine)
//  + righe + calcolo fiscale. Documento NON fiscale: la struttura IVA è
//  identica alla fattura (così la conversione è 1:1), ma niente SdI.
//
//  Regole italiane applicate (come in fattura):
//   - imponibile riga = qta * prezzo * (1 - sconto%), arrotondato a 2 dec.
//   - l'IVA si calcola sul TOTALE imponibile per aliquota, non riga per riga.
//   - totale documento = somma imponibili + somma imposte + bollo + arrot.
// ============================================================
import '../../../core/format.dart';
import '../../customers/domain/customer.dart';
import '../../invoices/domain/vat.dart';

/// Tipo di documento di vendita.
enum SalesKind {
  quote('quote', 'Preventivo'),
  order('order', 'Ordine');

  const SalesKind(this.db, this.label);
  final String db;
  final String label;

  static SalesKind fromDb(String? v) =>
      SalesKind.values.firstWhere((k) => k.db == v, orElse: () => SalesKind.quote);
}

/// Stato del documento di vendita.
enum SalesStatus {
  draft('draft', 'Bozza'),
  sent('sent', 'Inviato'),
  accepted('accepted', 'Accettato'),
  rejected('rejected', 'Rifiutato'),
  converted('converted', 'Convertito');

  const SalesStatus(this.db, this.label);
  final String db;
  final String label;

  static SalesStatus fromDb(String? v) =>
      SalesStatus.values.firstWhere((s) => s.db == v,
          orElse: () => SalesStatus.draft);
}

class SalesItem {
  SalesItem({
    this.id,
    this.position = 0,
    this.productId,
    this.description = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.vatRate = 22,
    this.vatNature,
    this.discountPercent = 0,
  });

  final String? id;
  int position;
  String? productId;
  String description;
  double quantity;
  double unitPrice;
  double vatRate;
  VatNature? vatNature;
  double discountPercent;

  /// Imponibile della riga (netto), arrotondato a 2 decimali.
  double get taxableBase =>
      round2(quantity * unitPrice * (1 - discountPercent / 100));

  factory SalesItem.fromJson(Map<String, dynamic> j) => SalesItem(
        id: j['id'] as String?,
        position: (j['position'] as num?)?.toInt() ?? 0,
        productId: j['product_id'] as String?,
        description: (j['description'] as String?) ?? '',
        quantity: (j['quantity'] as num?)?.toDouble() ?? 1,
        unitPrice: (j['unit_price'] as num?)?.toDouble() ?? 0,
        vatRate: (j['vat_rate'] as num?)?.toDouble() ?? 22,
        vatNature: VatNature.fromCode(j['vat_nature'] as String?),
        discountPercent: (j['discount_percent'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'position': position,
        'product_id': productId,
        'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
        'vat_rate': vatRate,
        'vat_nature': vatRate == 0 ? vatNature?.code : null,
        'discount_percent': discountPercent,
        'line_total': taxableBase,
      };

  SalesItem copy() => SalesItem(
        id: id,
        position: position,
        productId: productId,
        description: description,
        quantity: quantity,
        unitPrice: unitPrice,
        vatRate: vatRate,
        vatNature: vatNature,
        discountPercent: discountPercent,
      );
}

/// Riga del riepilogo IVA (per aliquota + natura).
class SalesVatLine {
  const SalesVatLine({
    required this.vatRate,
    required this.nature,
    required this.taxable,
    required this.tax,
  });
  final double vatRate;
  final VatNature? nature;
  final double taxable;
  final double tax;
}

class SalesDocument {
  SalesDocument({
    this.id,
    required this.companyId,
    this.customerId,
    this.customer,
    this.kind = SalesKind.quote,
    this.docNumber,
    this.status = SalesStatus.draft,
    DateTime? issueDate,
    this.validUntil,
    this.stampDuty = 0,
    this.rounding = 0,
    this.paymentMethod,
    this.paymentTerms,
    this.paymentTermsDays,
    this.notes,
    this.numberingYear,
    this.numberingSeq,
    this.convertedInvoiceId,
    this.templateId,
    List<SalesItem>? items,
  })  : issueDate = issueDate ?? DateTime.now(),
        items = items ?? [];

  final String? id;
  final String companyId;
  String? customerId;
  Customer? customer;
  SalesKind kind;
  String? docNumber;
  SalesStatus status;
  DateTime issueDate;
  DateTime? validUntil;
  double stampDuty;
  double rounding;
  String? paymentMethod;
  String? paymentTerms;
  int? paymentTermsDays;
  String? notes;
  int? numberingYear;
  int? numberingSeq;
  String? convertedInvoiceId;
  String? templateId;
  List<SalesItem> items;

  bool get isDraft => status == SalesStatus.draft;
  bool get isConverted => status == SalesStatus.converted;

  String get displayNumber => docNumber ?? 'BOZZA';
  String get kindLabel => kind.label;

  /// Preventivo scaduto: inviato/accettato, con validità superata e non ancora
  /// convertito né rifiutato.
  bool expiredAt(DateTime now) =>
      (status == SalesStatus.sent || status == SalesStatus.accepted) &&
      validUntil != null &&
      validUntil!.isBefore(DateTime(now.year, now.month, now.day));

  // ---------- Calcolo fiscale (identico alla fattura) ----------

  List<SalesVatLine> get vatSummary {
    final groups = <String, List<SalesItem>>{};
    for (final it in items) {
      final key = '${it.vatRate}|${it.vatRate == 0 ? it.vatNature?.code : ''}';
      (groups[key] ??= []).add(it);
    }
    final lines = <SalesVatLine>[];
    for (final entry in groups.entries) {
      final rate = entry.value.first.vatRate;
      final nature = rate == 0 ? entry.value.first.vatNature : null;
      final taxable =
          round2(entry.value.fold<double>(0, (s, it) => s + it.taxableBase));
      final tax = round2(taxable * rate / 100);
      lines.add(SalesVatLine(
          vatRate: rate, nature: nature, taxable: taxable, tax: tax));
    }
    lines.sort((a, b) => b.vatRate.compareTo(a.vatRate));
    return lines;
  }

  double get subtotal =>
      round2(vatSummary.fold<double>(0, (s, l) => s + l.taxable));

  double get taxAmount =>
      round2(vatSummary.fold<double>(0, (s, l) => s + l.tax));

  double get total => round2(subtotal + taxAmount + stampDuty + rounding);

  factory SalesDocument.fromJson(Map<String, dynamic> j) {
    final itemsJson = (j['sales_document_items'] as List?) ?? const [];
    final items = itemsJson
        .cast<Map<String, dynamic>>()
        .map(SalesItem.fromJson)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final cust = j['customers'];
    return SalesDocument(
      id: j['id'] as String,
      companyId: j['company_id'] as String,
      customerId: j['customer_id'] as String?,
      customer: cust is Map<String, dynamic> ? Customer.fromJson(cust) : null,
      kind: SalesKind.fromDb(j['doc_kind'] as String?),
      docNumber: j['doc_number'] as String?,
      status: SalesStatus.fromDb(j['status'] as String?),
      issueDate: DateTime.parse(j['issue_date'] as String),
      validUntil: j['valid_until'] == null
          ? null
          : DateTime.parse(j['valid_until'] as String),
      stampDuty: (j['stamp_duty'] as num?)?.toDouble() ?? 0,
      rounding: (j['rounding'] as num?)?.toDouble() ?? 0,
      paymentMethod: j['payment_method'] as String?,
      paymentTerms: j['payment_terms'] as String?,
      paymentTermsDays: (j['payment_terms_days'] as num?)?.toInt(),
      notes: j['notes'] as String?,
      numberingYear: (j['numbering_year'] as num?)?.toInt(),
      numberingSeq: (j['numbering_seq'] as num?)?.toInt(),
      convertedInvoiceId: j['converted_invoice_id'] as String?,
      templateId: j['template_id'] as String?,
      items: items,
    );
  }

  /// Campi della tabella sales_documents (le righe sono salvate a parte).
  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'customer_id': customerId,
        'doc_kind': kind.db,
        'status': status.db,
        'issue_date': _d(issueDate),
        'valid_until': validUntil == null ? null : _d(validUntil!),
        'subtotal': subtotal,
        'tax_amount': taxAmount,
        'total': total,
        'stamp_duty': stampDuty,
        'rounding': rounding,
        'payment_method': paymentMethod,
        'payment_terms': paymentTerms,
        'payment_terms_days': paymentTermsDays,
        'notes': notes,
        'converted_invoice_id': convertedInvoiceId,
        'template_id': templateId,
      };

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
