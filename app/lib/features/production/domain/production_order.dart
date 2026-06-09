// ============================================================
//  SMARTERP · production_order.dart — ordine di produzione.
//  Pianifica la fabbricazione di un prodotto componibile; al
//  completamento consuma i componenti (distinta base) dal magazzino.
// ============================================================

enum ProductionStatus {
  draft('draft', 'Bozza'),
  confirmed('confirmed', 'Confermato'),
  inProgress('in_progress', 'In lavorazione'),
  done('done', 'Completato'),
  cancelled('cancelled', 'Annullato');

  const ProductionStatus(this.db, this.label);
  final String db;
  final String label;

  static ProductionStatus fromDb(String? v) => ProductionStatus.values
      .firstWhere((s) => s.db == v, orElse: () => ProductionStatus.draft);

  bool get isClosed => this == done || this == cancelled;
}

class ProductionOrder {
  ProductionOrder({
    this.id,
    required this.companyId,
    this.productId,
    this.productName,
    this.quantity = 1,
    this.status = ProductionStatus.draft,
    this.orderNumber,
    this.plannedDate,
    this.startedAt,
    this.completedAt,
    this.notes,
  });

  final String? id;
  final String companyId;
  String? productId;
  String? productName; // sola lettura (join)
  double quantity;
  ProductionStatus status;
  String? orderNumber;
  DateTime? plannedDate;
  DateTime? startedAt;
  DateTime? completedAt;
  String? notes;

  String get displayNumber => orderNumber ?? 'BOZZA';

  factory ProductionOrder.fromJson(Map<String, dynamic> j) {
    final prod = j['products'] as Map?;
    return ProductionOrder(
      id: j['id'] as String,
      companyId: j['company_id'] as String,
      productId: j['product_id'] as String?,
      productName: prod?['name'] as String?,
      quantity: (j['quantity'] as num?)?.toDouble() ?? 1,
      status: ProductionStatus.fromDb(j['status'] as String?),
      orderNumber: j['order_number'] as String?,
      plannedDate: j['planned_date'] == null
          ? null
          : DateTime.parse(j['planned_date'] as String),
      startedAt: j['started_at'] == null
          ? null
          : DateTime.tryParse(j['started_at'] as String),
      completedAt: j['completed_at'] == null
          ? null
          : DateTime.tryParse(j['completed_at'] as String),
      notes: j['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'product_id': productId,
        'quantity': quantity,
        'status': status.db,
        'planned_date': plannedDate == null ? null : _d(plannedDate!),
        'notes': (notes == null || notes!.trim().isEmpty) ? null : notes!.trim(),
      };

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
