// ============================================================
//  SMARTERP · project_task.dart — attività di un progetto.
// ============================================================
enum TaskStatus {
  todo('todo', 'Da fare'),
  inProgress('in_progress', 'In corso'),
  done('done', 'Completata');

  const TaskStatus(this.db, this.label);
  final String db;
  final String label;

  static TaskStatus fromDb(String? v) =>
      TaskStatus.values.firstWhere((s) => s.db == v, orElse: () => TaskStatus.todo);
}

enum TaskPriority {
  low('low', 'Bassa'),
  medium('medium', 'Media'),
  high('high', 'Alta');

  const TaskPriority(this.db, this.label);
  final String db;
  final String label;

  static TaskPriority fromDb(String? v) => TaskPriority.values
      .firstWhere((p) => p.db == v, orElse: () => TaskPriority.medium);
}

class ProjectTask {
  ProjectTask({
    this.id,
    required this.projectId,
    this.position = 0,
    this.title = '',
    this.description,
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.medium,
    this.assignedTo,
    this.dueDate,
  });

  final String? id;
  final String projectId;
  int position;
  String title;
  String? description;
  TaskStatus status;
  TaskPriority priority;
  String? assignedTo;
  DateTime? dueDate;

  factory ProjectTask.fromJson(Map<String, dynamic> j) => ProjectTask(
        id: j['id'] as String,
        projectId: j['project_id'] as String,
        position: (j['position'] as num?)?.toInt() ?? 0,
        title: (j['title'] as String?) ?? '',
        description: j['description'] as String?,
        status: TaskStatus.fromDb(j['status'] as String?),
        priority: TaskPriority.fromDb(j['priority'] as String?),
        assignedTo: j['assigned_to'] as String?,
        dueDate: j['due_date'] == null
            ? null
            : DateTime.tryParse(j['due_date'] as String),
      );

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'position': position,
        'title': title.trim(),
        'description':
            (description == null || description!.trim().isEmpty) ? null : description!.trim(),
        'status': status.db,
        'priority': priority.db,
        'assigned_to':
            (assignedTo == null || assignedTo!.trim().isEmpty) ? null : assignedTo!.trim(),
        'due_date': dueDate == null ? null : _d(dueDate!),
      };

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
