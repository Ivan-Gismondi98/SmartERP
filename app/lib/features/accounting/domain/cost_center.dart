// ============================================================
//  SMARTERP · cost_center.dart — centro di costo (contabilità analitica).
// ============================================================
class CostCenter {
  CostCenter({
    this.id,
    required this.companyId,
    this.code = '',
    this.name = '',
    this.isActive = true,
  });

  final String? id;
  final String companyId;
  String code;
  String name;
  bool isActive;

  String get display => '$code · $name';

  factory CostCenter.fromJson(Map<String, dynamic> j) => CostCenter(
        id: j['id'] as String,
        companyId: j['company_id'] as String,
        code: (j['code'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        isActive: (j['is_active'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'code': code.trim(),
        'name': name.trim(),
        'is_active': isActive,
      };
}
