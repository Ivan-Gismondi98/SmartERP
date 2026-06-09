// ============================================================
//  SMARTERP · equipment.dart — attrezzatura/impianto monitorato.
// ============================================================
enum EquipmentStatus {
  operational('operational', 'Operativa'),
  maintenance('maintenance', 'In manutenzione'),
  outOfService('out_of_service', 'Fuori servizio');

  const EquipmentStatus(this.db, this.label);
  final String db;
  final String label;

  static EquipmentStatus fromDb(String? v) => EquipmentStatus.values
      .firstWhere((s) => s.db == v, orElse: () => EquipmentStatus.operational);
}

class Equipment {
  Equipment({
    this.id,
    required this.companyId,
    this.name = '',
    this.code,
    this.category,
    this.location,
    this.status = EquipmentStatus.operational,
    this.purchaseDate,
    this.lastService,
    this.nextService,
    this.notes,
  });

  final String? id;
  final String companyId;
  String name;
  String? code;
  String? category;
  String? location;
  EquipmentStatus status;
  DateTime? purchaseDate;
  DateTime? lastService;
  DateTime? nextService;
  String? notes;

  /// Manutenzione programmata scaduta (next_service nel passato).
  bool overdue(DateTime now) =>
      nextService != null &&
      nextService!.isBefore(DateTime(now.year, now.month, now.day));

  factory Equipment.fromJson(Map<String, dynamic> j) => Equipment(
        id: j['id'] as String,
        companyId: j['company_id'] as String,
        name: (j['name'] as String?) ?? '',
        code: j['code'] as String?,
        category: j['category'] as String?,
        location: j['location'] as String?,
        status: EquipmentStatus.fromDb(j['status'] as String?),
        purchaseDate: _date(j['purchase_date']),
        lastService: _date(j['last_service']),
        nextService: _date(j['next_service']),
        notes: j['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'name': name.trim(),
        'code': _n(code),
        'category': _n(category),
        'location': _n(location),
        'status': status.db,
        'purchase_date': purchaseDate == null ? null : _d(purchaseDate!),
        'last_service': lastService == null ? null : _d(lastService!),
        'next_service': nextService == null ? null : _d(nextService!),
        'notes': _n(notes),
      };

  static String? _n(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);
  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
