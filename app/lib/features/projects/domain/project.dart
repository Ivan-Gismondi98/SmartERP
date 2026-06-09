// ============================================================
//  SMARTERP · project.dart — progetto. L'avanzamento è calcolato dai task.
// ============================================================
import '../../customers/domain/customer.dart';
import 'project_task.dart';

enum ProjectStatus {
  planning('planning', 'Pianificazione'),
  active('active', 'In corso'),
  onHold('on_hold', 'In pausa'),
  done('done', 'Completato'),
  cancelled('cancelled', 'Annullato');

  const ProjectStatus(this.db, this.label);
  final String db;
  final String label;

  static ProjectStatus fromDb(String? v) => ProjectStatus.values
      .firstWhere((s) => s.db == v, orElse: () => ProjectStatus.planning);
}

class Project {
  Project({
    this.id,
    required this.companyId,
    this.customerId,
    this.customer,
    this.name = '',
    this.status = ProjectStatus.planning,
    this.startDate,
    this.dueDate,
    this.budget = 0,
    this.manager,
    this.description,
    List<ProjectTask>? tasks,
  }) : tasks = tasks ?? [];

  final String? id;
  final String companyId;
  String? customerId;
  Customer? customer;
  String name;
  ProjectStatus status;
  DateTime? startDate;
  DateTime? dueDate;
  double budget;
  String? manager;
  String? description;
  List<ProjectTask> tasks;

  int get totalTasks => tasks.length;
  int get doneTasks => tasks.where((t) => t.status == TaskStatus.done).length;

  /// Avanzamento 0..1 (task completati / totali).
  double get progress => totalTasks == 0 ? 0 : doneTasks / totalTasks;

  bool overdue(DateTime now) =>
      status != ProjectStatus.done &&
      status != ProjectStatus.cancelled &&
      dueDate != null &&
      dueDate!.isBefore(DateTime(now.year, now.month, now.day));

  factory Project.fromJson(Map<String, dynamic> j) {
    final cust = j['customers'];
    final tasksJson = (j['project_tasks'] as List?) ?? const [];
    final tasks = tasksJson
        .cast<Map<String, dynamic>>()
        .map(ProjectTask.fromJson)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return Project(
      id: j['id'] as String,
      companyId: j['company_id'] as String,
      customerId: j['customer_id'] as String?,
      customer: cust is Map<String, dynamic> ? Customer.fromJson(cust) : null,
      name: (j['name'] as String?) ?? '',
      status: ProjectStatus.fromDb(j['status'] as String?),
      startDate: _date(j['start_date']),
      dueDate: _date(j['due_date']),
      budget: (j['budget'] as num?)?.toDouble() ?? 0,
      manager: j['manager'] as String?,
      description: j['description'] as String?,
      tasks: tasks,
    );
  }

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'customer_id': customerId,
        'name': name.trim(),
        'status': status.db,
        'start_date': startDate == null ? null : _d(startDate!),
        'due_date': dueDate == null ? null : _d(dueDate!),
        'budget': budget,
        'manager': (manager == null || manager!.trim().isEmpty) ? null : manager!.trim(),
        'description':
            (description == null || description!.trim().isEmpty) ? null : description!.trim(),
      };

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);
  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
