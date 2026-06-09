// ============================================================
//  SMARTERP · project_detail_page.dart — dettaglio progetto con attività
//  raggruppate per stato, avanzamento e gestione task.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../application/projects_providers.dart';
import '../data/projects_repository.dart';
import '../domain/project.dart';
import '../domain/project_task.dart';
import 'project_form_page.dart';

class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectDetailProvider(projectId));
    final canEdit = ref.watch(canProvider(Perm.projectsEdit));
    final canDelete = ref.watch(canProvider(Perm.projectsDelete));

    return Scaffold(
      appBar: AppBar(title: const Text('Progetto')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (p) => _Body(
          project: p,
          canEdit: canEdit,
          canDelete: canDelete,
          onChanged: () => ref.invalidate(projectDetailProvider(projectId)),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.project,
    required this.canEdit,
    required this.canDelete,
    required this.onChanged,
  });
  final Project project;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(project.name,
                        style: theme.textTheme.headlineSmall),
                  ),
                  Chip(label: Text(project.status.label)),
                ],
              ),
              const SizedBox(height: 8),
              if (project.customer != null)
                Text('Cliente: ${project.customer!.name}'),
              if (project.manager != null && project.manager!.isNotEmpty)
                Text('Responsabile: ${project.manager}'),
              Text('Periodo: ${Fmt.date(project.startDate)} → ${Fmt.date(project.dueDate)}'),
              if (project.budget > 0) Text('Budget: ${Fmt.euro(project.budget)}'),
              const SizedBox(height: 12),
              if (project.totalTasks > 0) ...[
                LinearProgressIndicator(value: project.progress, minHeight: 8),
                const SizedBox(height: 4),
                Text(
                    'Avanzamento ${(project.progress * 100).round()}% '
                    '(${project.doneTasks}/${project.totalTasks})',
                    style: theme.textTheme.bodySmall),
              ],
              if (project.description != null &&
                  project.description!.isNotEmpty) ...[
                const Divider(height: 32),
                Text('Descrizione', style: theme.textTheme.titleMedium),
                Text(project.description!),
              ],
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Attività', style: theme.textTheme.titleMedium),
                  if (canEdit)
                    TextButton.icon(
                      onPressed: () => _editTask(context, ref, null),
                      icon: const Icon(Icons.add),
                      label: const Text('Aggiungi'),
                    ),
                ],
              ),
              if (project.tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Nessuna attività.'),
                ),
              for (final status in TaskStatus.values)
                ..._taskSection(context, ref, status,
                    project.tasks.where((t) => t.status == status).toList()),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                if (canDelete)
                  OutlinedButton.icon(
                    onPressed: () => _deleteProject(context, ref),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Elimina'),
                  ),
                if (canEdit)
                  FilledButton.icon(
                    onPressed: () => _editProject(context),
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifica progetto'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _taskSection(BuildContext context, WidgetRef ref,
      TaskStatus status, List<ProjectTask> tasks) {
    if (tasks.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
        child: Text('${status.label}  (${tasks.length})',
            style: Theme.of(context).textTheme.labelMedium),
      ),
      for (final t in tasks)
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: _TaskCheck(task: t, ref: ref, onChanged: onChanged),
            title: Text(t.title),
            subtitle: Text([
              t.priority.label,
              if (t.assignedTo != null && t.assignedTo!.isNotEmpty) t.assignedTo!,
              if (t.dueDate != null) Fmt.date(t.dueDate),
            ].join(' · ')),
            trailing: canEdit
                ? PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _editTask(context, ref, t);
                      if (v == 'delete') _deleteTask(ref, t);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifica')),
                      PopupMenuItem(value: 'delete', child: Text('Elimina')),
                    ],
                  )
                : null,
          ),
        ),
    ];
  }

  Future<void> _editProject(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProjectFormPage(projectId: project.id)),
    );
    if (changed == true) onChanged();
  }

  Future<void> _deleteProject(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare il progetto?'),
        content: const Text('Verranno eliminate anche tutte le attività.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(projectsRepositoryProvider).delete(project.id!);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _editTask(
      BuildContext context, WidgetRef ref, ProjectTask? task) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _TaskDialog(projectId: project.id!, task: task),
    );
    if (saved == true) onChanged();
  }

  Future<void> _deleteTask(WidgetRef ref, ProjectTask task) async {
    await ref.read(projectsRepositoryProvider).deleteTask(task.id!);
    onChanged();
  }
}

class _TaskCheck extends StatelessWidget {
  const _TaskCheck(
      {required this.task, required this.ref, required this.onChanged});
  final ProjectTask task;
  final WidgetRef ref;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: task.status == TaskStatus.done,
      onChanged: (v) async {
        await ref.read(projectsRepositoryProvider).setTaskStatus(
            task.id!, v == true ? TaskStatus.done : TaskStatus.todo);
        onChanged();
      },
    );
  }
}

class _TaskDialog extends ConsumerStatefulWidget {
  const _TaskDialog({required this.projectId, this.task});
  final String projectId;
  final ProjectTask? task;

  @override
  ConsumerState<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends ConsumerState<_TaskDialog> {
  late final TextEditingController _title;
  late final TextEditingController _assigned;
  TaskStatus _status = TaskStatus.todo;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _due;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _assigned = TextEditingController(text: t?.assignedTo ?? '');
    _status = t?.status ?? TaskStatus.todo;
    _priority = t?.priority ?? TaskPriority.medium;
    _due = t?.dueDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _assigned.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final t = widget.task ?? ProjectTask(projectId: widget.projectId);
      t
        ..title = _title.text
        ..assignedTo = _assigned.text
        ..status = _status
        ..priority = _priority
        ..dueDate = _due;
      await ref.read(projectsRepositoryProvider).saveTask(t);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.task == null ? 'Nuova attività' : 'Modifica attività'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Titolo *')),
            TextField(
                controller: _assigned,
                decoration: const InputDecoration(labelText: 'Assegnata a')),
            const SizedBox(height: 8),
            DropdownButtonFormField<TaskStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Stato'),
              items: [
                for (final s in TaskStatus.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) => setState(() => _status = v ?? TaskStatus.todo),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<TaskPriority>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priorità'),
              items: [
                for (final p in TaskPriority.values)
                  DropdownMenuItem(value: p, child: Text(p.label)),
              ],
              onChanged: (v) =>
                  setState(() => _priority = v ?? TaskPriority.medium),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _due ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _due = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Scadenza'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_due == null ? '—' : Fmt.date(_due)),
                    if (_due != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _due = null),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Annulla')),
        FilledButton(
            onPressed: _busy ? null : _save, child: const Text('Salva')),
      ],
    );
  }
}
