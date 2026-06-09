// ============================================================
//  SMARTERP · maintenance_request.dart — richiesta/intervento di
//  manutenzione su un'attrezzatura.
// ============================================================
enum MaintenanceType {
  corrective('corrective', 'Correttiva'),
  preventive('preventive', 'Preventiva');

  const MaintenanceType(this.db, this.label);
  final String db;
  final String label;

  static MaintenanceType fromDb(String? v) => MaintenanceType.values
      .firstWhere((t) => t.db == v, orElse: () => MaintenanceType.corrective);
}

enum MaintenancePriority {
  low('low', 'Bassa'),
  medium('medium', 'Media'),
  high('high', 'Alta'),
  urgent('urgent', 'Urgente');

  const MaintenancePriority(this.db, this.label);
  final String db;
  final String label;

  static MaintenancePriority fromDb(String? v) => MaintenancePriority.values
      .firstWhere((p) => p.db == v, orElse: () => MaintenancePriority.medium);
}

enum MaintenanceStatus {
  open('open', 'Aperta'),
  inProgress('in_progress', 'In lavorazione'),
  done('done', 'Completata'),
  cancelled('cancelled', 'Annullata');

  const MaintenanceStatus(this.db, this.label);
  final String db;
  final String label;

  static MaintenanceStatus fromDb(String? v) => MaintenanceStatus.values
      .firstWhere((s) => s.db == v, orElse: () => MaintenanceStatus.open);

  bool get isClosed => this == done || this == cancelled;
}

class MaintenanceRequest {
  MaintenanceRequest({
    this.id,
    required this.companyId,
    this.equipmentId,
    this.equipmentName,
    this.title = '',
    this.description,
    this.type = MaintenanceType.corrective,
    this.priority = MaintenancePriority.medium,
    this.status = MaintenanceStatus.open,
    this.requestedBy,
    this.assignedTo,
    this.scheduledDate,
    this.completedAt,
    this.cost = 0,
    this.notes,
  });

  final String? id;
  final String companyId;
  String? equipmentId;
  String? equipmentName; // sola lettura (join)
  String title;
  String? description;
  MaintenanceType type;
  MaintenancePriority priority;
  MaintenanceStatus status;
  String? requestedBy;
  String? assignedTo;
  DateTime? scheduledDate;
  DateTime? completedAt;
  double cost;
  String? notes;

  factory MaintenanceRequest.fromJson(Map<String, dynamic> j) {
    final eq = j['maintenance_equipment'] as Map?;
    return MaintenanceRequest(
      id: j['id'] as String,
      companyId: j['company_id'] as String,
      equipmentId: j['equipment_id'] as String?,
      equipmentName: eq?['name'] as String?,
      title: (j['title'] as String?) ?? '',
      description: j['description'] as String?,
      type: MaintenanceType.fromDb(j['request_type'] as String?),
      priority: MaintenancePriority.fromDb(j['priority'] as String?),
      status: MaintenanceStatus.fromDb(j['status'] as String?),
      requestedBy: j['requested_by'] as String?,
      assignedTo: j['assigned_to'] as String?,
      scheduledDate: j['scheduled_date'] == null
          ? null
          : DateTime.tryParse(j['scheduled_date'] as String),
      completedAt: j['completed_at'] == null
          ? null
          : DateTime.tryParse(j['completed_at'] as String),
      cost: (j['cost'] as num?)?.toDouble() ?? 0,
      notes: j['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'equipment_id': equipmentId,
        'title': title.trim(),
        'description':
            (description == null || description!.trim().isEmpty) ? null : description!.trim(),
        'request_type': type.db,
        'priority': priority.db,
        'status': status.db,
        'requested_by': requestedBy,
        'assigned_to':
            (assignedTo == null || assignedTo!.trim().isEmpty) ? null : assignedTo!.trim(),
        'scheduled_date': scheduledDate == null ? null : _d(scheduledDate!),
        'cost': cost,
        'notes': (notes == null || notes!.trim().isEmpty) ? null : notes!.trim(),
      };

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
