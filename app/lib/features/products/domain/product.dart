// ============================================================
//  SMARTERP · product.dart — prodotto a catalogo + giacenza (inventory).
// ============================================================
class Product {
  const Product({
    required this.id,
    required this.companyId,
    required this.name,
    this.sku,
    this.description,
    this.unitPrice = 0,
    this.vatRate = 22,
    this.unit = 'pz',
    this.isComposable = false,
    this.imageUrl,
    this.showInDocuments = false,
    this.quantity = 0,
    this.reorderLevel = 0,
    this.warehouseLocation,
  });

  final String id;
  final String companyId;
  final String name;
  final String? sku;
  final String? description;
  final double unitPrice;
  final double vatRate;
  final String unit;
  final bool isComposable;
  final String? imageUrl;
  final bool showInDocuments;

  // Giacenza (tabella inventory).
  final int quantity;
  final int reorderLevel;
  final String? warehouseLocation;

  /// Sotto scorta: la giacenza ha raggiunto o sforato il livello di riordino.
  bool get belowReorder => quantity <= reorderLevel;

  factory Product.fromJson(Map<String, dynamic> j) {
    // inventory puo' arrivare come oggetto singolo o lista (join PostgREST).
    final invRaw = j['inventory'];
    Map<String, dynamic>? inv;
    if (invRaw is Map<String, dynamic>) {
      inv = invRaw;
    } else if (invRaw is List && invRaw.isNotEmpty) {
      inv = (invRaw.first as Map).cast<String, dynamic>();
    }
    return Product(
      id: j['id'] as String,
      companyId: j['company_id'] as String,
      name: j['name'] as String,
      sku: j['sku'] as String?,
      description: j['description'] as String?,
      unitPrice: (j['unit_price'] as num?)?.toDouble() ?? 0,
      vatRate: (j['vat_rate'] as num?)?.toDouble() ?? 22,
      unit: (j['unit'] as String?) ?? 'pz',
      isComposable: (j['is_composable'] as bool?) ?? false,
      imageUrl: j['image_url'] as String?,
      showInDocuments: (j['show_in_documents'] as bool?) ?? false,
      quantity: (inv?['quantity'] as num?)?.toInt() ?? 0,
      reorderLevel: (inv?['reorder_level'] as num?)?.toInt() ?? 0,
      warehouseLocation: inv?['warehouse_location'] as String?,
    );
  }

  /// Campi della tabella products (la giacenza si salva a parte).
  Map<String, dynamic> productJson() => {
        'name': name,
        'sku': (sku == null || sku!.trim().isEmpty) ? null : sku!.trim(),
        'description':
            (description == null || description!.trim().isEmpty) ? null : description!.trim(),
        'unit_price': unitPrice,
        'vat_rate': vatRate,
        'unit': unit,
        'is_composable': isComposable,
        'image_url':
            (imageUrl == null || imageUrl!.trim().isEmpty) ? null : imageUrl!.trim(),
        'show_in_documents': showInDocuments,
      };

  Map<String, dynamic> inventoryJson() => {
        'quantity': quantity,
        'reorder_level': reorderLevel,
        'warehouse_location':
            (warehouseLocation == null || warehouseLocation!.trim().isEmpty)
                ? null
                : warehouseLocation!.trim(),
      };
}
