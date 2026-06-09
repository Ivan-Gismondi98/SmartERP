// ============================================================
//  SMARTERP · purchase_document.dart — documento del ciclo passivo
//  (offerta / ordine di acquisto / contratto) + righe + calcolo IVA.
//  Struttura fiscale identica alle vendite, ma collegata al Fornitore.
// ============================================================
import '../../../core/format.dart';
import '../../invoices/domain/vat.dart';
import '../../suppliers/domain/supplier.dart';

enum PurchaseKind {
  offer('offer', 'Offerta'),
  order('order', 'Ordine'),
  contract('contract', 'Contratto');

  const PurchaseKind(this.db, this.label);
  final String db;
  final String label;

  static PurchaseKind fromDb(String? v) => PurchaseKind.values
      .firstWhere((k) => k.db == v, orElse: () => PurchaseKind.order);
}

enum PurchaseStatus {
  draft('draft', 'Bozza'),
  sent('sent', 'Inviato'),
  confirmed('confirmed', 'Confermato'),
  received('received', 'Ricevuto'),
  cancelled('cancelled', 'Annullato');

  const PurchaseStatus(this.db, this.label);
  final String db;
  final String label;

  static PurchaseStatus fromDb(String? v) => PurchaseStatus.values
      .firstWhere((s) => s.db == v, orElse: () => PurchaseStatus.draft);
}

class PurchaseItem {
  PurchaseItem({
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

  double get taxableBase =>
      round2(quantity * unitPrice * (1 - discountPercent / 100));

  factory PurchaseItem.fromJson(Map<String, dynamic> j) => PurchaseItem(
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

  PurchaseItem copy() => PurchaseItem(
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

class PurchaseVatLine {
  const PurchaseVatLine({
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

class PurchaseDocument {
  PurchaseDocument({
    this.id,
    required this.companyId,
    this.supplierId,
    this.supplier,
    this.kind = PurchaseKind.order,
    this.docNumber,
    this.status = PurchaseStatus.draft,
    DateTime? issueDate,
    this.validUntil,
    this.supplierRef,
    this.rounding = 0,
    this.paymentTerms,
    this.notes,
    this.numberingYear,
    this.numberingSeq,
    List<PurchaseItem>? items,
  })  : issueDate = issueDate ?? DateTime.now(),
        items = items ?? [];

  final String? id;
  final String companyId;
  String? supplierId;
  Supplier? supplier;
  PurchaseKind kind;
  String? docNumber;
  PurchaseStatus status;
  DateTime issueDate;
  DateTime? validUntil;
  String? supplierRef;
  double rounding;
  String? paymentTerms;
  String? notes;
  int? numberingYear;
  int? numberingSeq;
  List<PurchaseItem> items;

  bool get isDraft => status == PurchaseStatus.draft;
  String get displayNumber => docNumber ?? 'BOZZA';
  String get kindLabel => kind.label;

  List<PurchaseVatLine> get vatSummary {
    final groups = <String, List<PurchaseItem>>{};
    for (final it in items) {
      final key = '${it.vatRate}|${it.vatRate == 0 ? it.vatNature?.code : ''}';
      (groups[key] ??= []).add(it);
    }
    final lines = <PurchaseVatLine>[];
    for (final entry in groups.entries) {
      final rate = entry.value.first.vatRate;
      final nature = rate == 0 ? entry.value.first.vatNature : null;
      final taxable =
          round2(entry.value.fold<double>(0, (s, it) => s + it.taxableBase));
      final tax = round2(taxable * rate / 100);
      lines.add(PurchaseVatLine(
          vatRate: rate, nature: nature, taxable: taxable, tax: tax));
    }
    lines.sort((a, b) => b.vatRate.compareTo(a.vatRate));
    return lines;
  }

  double get subtotal =>
      round2(vatSummary.fold<double>(0, (s, l) => s + l.taxable));
  double get taxAmount =>
      round2(vatSummary.fold<double>(0, (s, l) => s + l.tax));
  double get total => round2(subtotal + taxAmount + rounding);

  factory PurchaseDocument.fromJson(Map<String, dynamic> j) {
    final itemsJson = (j['purchase_document_items'] as List?) ?? const [];
    final items = itemsJson
        .cast<Map<String, dynamic>>()
        .map(PurchaseItem.fromJson)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final sup = j['suppliers'];
    return PurchaseDocument(
      id: j['id'] as String,
      companyId: j['company_id'] as String,
      supplierId: j['supplier_id'] as String?,
      supplier: sup is Map<String, dynamic> ? Supplier.fromJson(sup) : null,
      kind: PurchaseKind.fromDb(j['doc_kind'] as String?),
      docNumber: j['doc_number'] as String?,
      status: PurchaseStatus.fromDb(j['status'] as String?),
      issueDate: DateTime.parse(j['issue_date'] as String),
      validUntil: j['valid_until'] == null
          ? null
          : DateTime.parse(j['valid_until'] as String),
      supplierRef: j['supplier_ref'] as String?,
      rounding: (j['rounding'] as num?)?.toDouble() ?? 0,
      paymentTerms: j['payment_terms'] as String?,
      notes: j['notes'] as String?,
      numberingYear: (j['numbering_year'] as num?)?.toInt(),
      numberingSeq: (j['numbering_seq'] as num?)?.toInt(),
      items: items,
    );
  }

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'supplier_id': supplierId,
        'doc_kind': kind.db,
        'status': status.db,
        'issue_date': _d(issueDate),
        'valid_until': validUntil == null ? null : _d(validUntil!),
        'supplier_ref':
            (supplierRef == null || supplierRef!.trim().isEmpty) ? null : supplierRef!.trim(),
        'subtotal': subtotal,
        'tax_amount': taxAmount,
        'total': total,
        'rounding': rounding,
        'payment_terms': paymentTerms,
        'notes': notes,
      };

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
