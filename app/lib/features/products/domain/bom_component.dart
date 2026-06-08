// ============================================================
//  SMARTERP · bom_component.dart — riga di distinta base (DiBa/BOM).
//  Lega un prodotto componente a una quantita' necessaria.
// ============================================================
class BomComponent {
  BomComponent({
    this.id,
    required this.componentId,
    this.componentName = '',
    this.componentUnit = 'pz',
    this.componentStock = 0,
    this.quantity = 1,
    this.note,
  });

  final String? id;
  String componentId;
  String componentName;
  String componentUnit;
  int componentStock;
  double quantity;
  String? note;

  factory BomComponent.fromJson(Map<String, dynamic> j) {
    final prod = j['products'];
    Map<String, dynamic>? p;
    if (prod is Map<String, dynamic>) p = prod;
    final invRaw = p?['inventory'];
    Map<String, dynamic>? inv;
    if (invRaw is Map<String, dynamic>) {
      inv = invRaw;
    } else if (invRaw is List && invRaw.isNotEmpty) {
      inv = (invRaw.first as Map).cast<String, dynamic>();
    }
    return BomComponent(
      id: j['id'] as String?,
      componentId: j['component_id'] as String,
      componentName: (p?['name'] as String?) ?? '',
      componentUnit: (p?['unit'] as String?) ?? 'pz',
      componentStock: (inv?['quantity'] as num?)?.toInt() ?? 0,
      quantity: (j['quantity'] as num?)?.toDouble() ?? 1,
      note: j['note'] as String?,
    );
  }

  Map<String, dynamic> toJson(String companyId, String productId) => {
        'company_id': companyId,
        'product_id': productId,
        'component_id': componentId,
        'quantity': quantity,
        'note': (note == null || note!.trim().isEmpty) ? null : note!.trim(),
      };
}
