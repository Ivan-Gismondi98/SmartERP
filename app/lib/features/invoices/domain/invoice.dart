// ============================================================
//  SMARTERP · invoice.dart — modelli fattura + righe + calcolo fiscale.
//
//  Regole italiane applicate:
//   - imponibile riga = qta * prezzo * (1 - sconto%), arrotondato a 2 dec.
//   - l'IVA si calcola sul TOTALE imponibile per aliquota (riepilogo SdI),
//     non riga per riga, per evitare derive di arrotondamento.
//   - totale documento = somma imponibili + somma imposte + bollo + arrot.
// ============================================================
import '../../../core/format.dart';
import '../../customers/domain/customer.dart';
import 'vat.dart';

enum InvoiceStatus {
  draft('draft', 'Bozza'),
  sent('sent', 'Emessa'),
  paid('paid', 'Pagata'),
  overdue('overdue', 'Scaduta'),
  cancelled('cancelled', 'Annullata');

  const InvoiceStatus(this.db, this.label);
  final String db;
  final String label;

  static InvoiceStatus fromDb(String? v) =>
      InvoiceStatus.values.firstWhere((s) => s.db == v,
          orElse: () => InvoiceStatus.draft);
}

class InvoiceItem {
  InvoiceItem({
    this.id,
    this.position = 0,
    this.description = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.vatRate = 22,
    this.vatNature,
    this.discountPercent = 0,
  });

  final String? id;
  int position;
  String description;
  double quantity;
  double unitPrice;
  double vatRate;
  VatNature? vatNature;
  double discountPercent;

  /// Imponibile della riga (netto), arrotondato a 2 decimali.
  double get taxableBase =>
      round2(quantity * unitPrice * (1 - discountPercent / 100));

  factory InvoiceItem.fromJson(Map<String, dynamic> j) => InvoiceItem(
        id: j['id'] as String?,
        position: (j['position'] as num?)?.toInt() ?? 0,
        description: (j['description'] as String?) ?? '',
        quantity: (j['quantity'] as num?)?.toDouble() ?? 1,
        unitPrice: (j['unit_price'] as num?)?.toDouble() ?? 0,
        vatRate: (j['vat_rate'] as num?)?.toDouble() ?? 22,
        vatNature: VatNature.fromCode(j['vat_nature'] as String?),
        discountPercent: (j['discount_percent'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'position': position,
        'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
        'vat_rate': vatRate,
        'vat_nature': vatRate == 0 ? vatNature?.code : null,
        'discount_percent': discountPercent,
        'line_total': taxableBase,
      };

  InvoiceItem copy() => InvoiceItem(
        id: id,
        position: position,
        description: description,
        quantity: quantity,
        unitPrice: unitPrice,
        vatRate: vatRate,
        vatNature: vatNature,
        discountPercent: discountPercent,
      );
}

/// Riga del riepilogo IVA (per aliquota + natura).
class VatSummaryLine {
  const VatSummaryLine({
    required this.vatRate,
    required this.nature,
    required this.taxable,
    required this.tax,
  });
  final double vatRate;
  final VatNature? nature;
  final double taxable; // imponibile
  final double tax; // imposta
}

class Invoice {
  Invoice({
    this.id,
    required this.companyId,
    this.customerId,
    this.customer,
    this.invoiceNumber,
    this.status = InvoiceStatus.draft,
    this.documentType = 'TD01',
    DateTime? issueDate,
    this.dueDate,
    this.stampDuty = 0,
    this.rounding = 0,
    this.paymentMethod,
    this.paymentTerms,
    this.notes,
    this.numberingYear,
    this.numberingSeq,
    this.referenceInvoiceId,
    List<InvoiceItem>? items,
  })  : issueDate = issueDate ?? DateTime.now(),
        items = items ?? [];

  final String? id;
  final String companyId;
  String? customerId;
  Customer? customer;
  String? invoiceNumber;
  InvoiceStatus status;
  String documentType;
  DateTime issueDate;
  DateTime? dueDate;
  double stampDuty;
  double rounding;
  String? paymentMethod;
  String? paymentTerms;
  String? notes;
  int? numberingYear;
  int? numberingSeq;
  String? referenceInvoiceId;
  List<InvoiceItem> items;

  bool get isDraft => status == InvoiceStatus.draft;
  bool get isIssued => !isDraft;

  bool get isCreditNote => documentType == 'TD04';
  String get documentTypeLabel =>
      isCreditNote ? 'Nota di credito' : 'Fattura';

  String get displayNumber => invoiceNumber ?? 'BOZZA';

  /// Scaduta: emessa, non pagata/annullata e con scadenza passata.
  bool overdueAt(DateTime now) =>
      status == InvoiceStatus.sent &&
      dueDate != null &&
      dueDate!.isBefore(DateTime(now.year, now.month, now.day));

  // ---------- Calcolo fiscale ----------

  /// Riepilogo IVA raggruppato per (aliquota, natura), come da fattura.
  List<VatSummaryLine> get vatSummary {
    final groups = <String, List<InvoiceItem>>{};
    for (final it in items) {
      final key = '${it.vatRate}|${it.vatRate == 0 ? it.vatNature?.code : ''}';
      (groups[key] ??= []).add(it);
    }
    final lines = <VatSummaryLine>[];
    for (final entry in groups.entries) {
      final rate = entry.value.first.vatRate;
      final nature = rate == 0 ? entry.value.first.vatNature : null;
      final taxable = round2(
          entry.value.fold<double>(0, (s, it) => s + it.taxableBase));
      final tax = round2(taxable * rate / 100);
      lines.add(VatSummaryLine(
          vatRate: rate, nature: nature, taxable: taxable, tax: tax));
    }
    lines.sort((a, b) => b.vatRate.compareTo(a.vatRate));
    return lines;
  }

  /// Imponibile totale.
  double get subtotal =>
      round2(vatSummary.fold<double>(0, (s, l) => s + l.taxable));

  /// IVA totale.
  double get taxAmount =>
      round2(vatSummary.fold<double>(0, (s, l) => s + l.tax));

  /// Totale documento (imponibile + IVA + bollo + arrotondamento).
  double get total => round2(subtotal + taxAmount + stampDuty + rounding);

  /// Bollo dovuto: € 2,00 se l'imponibile non soggetto a IVA supera € 77,47.
  bool get stampDutyDue {
    final exempt = vatSummary
        .where((l) => l.vatRate == 0)
        .fold<double>(0, (s, l) => s + l.taxable);
    return exempt > 77.47;
  }

  factory Invoice.fromJson(Map<String, dynamic> j) {
    final itemsJson = (j['invoice_items'] as List?) ?? const [];
    final items = itemsJson
        .cast<Map<String, dynamic>>()
        .map(InvoiceItem.fromJson)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final cust = j['customers'];
    return Invoice(
      id: j['id'] as String,
      companyId: j['company_id'] as String,
      customerId: j['customer_id'] as String?,
      customer: cust is Map<String, dynamic> ? Customer.fromJson(cust) : null,
      invoiceNumber: j['invoice_number'] as String?,
      status: InvoiceStatus.fromDb(j['status'] as String?),
      documentType: (j['document_type'] as String?) ?? 'TD01',
      issueDate: DateTime.parse(j['issue_date'] as String),
      dueDate: j['due_date'] == null
          ? null
          : DateTime.parse(j['due_date'] as String),
      stampDuty: (j['stamp_duty'] as num?)?.toDouble() ?? 0,
      rounding: (j['rounding'] as num?)?.toDouble() ?? 0,
      paymentMethod: j['payment_method'] as String?,
      paymentTerms: j['payment_terms'] as String?,
      notes: j['notes'] as String?,
      numberingYear: (j['numbering_year'] as num?)?.toInt(),
      numberingSeq: (j['numbering_seq'] as num?)?.toInt(),
      referenceInvoiceId: j['reference_invoice_id'] as String?,
      items: items,
    );
  }

  /// Campi della tabella invoices (le righe sono salvate a parte).
  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'customer_id': customerId,
        'document_type': documentType,
        'status': status.db,
        'issue_date': _d(issueDate),
        'due_date': dueDate == null ? null : _d(dueDate!),
        'subtotal': subtotal,
        'tax_amount': taxAmount,
        'total': total,
        'stamp_duty': stampDuty,
        'rounding': rounding,
        'payment_method': paymentMethod,
        'payment_terms': paymentTerms,
        'notes': notes,
        'reference_invoice_id': referenceInvoiceId,
      };

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
