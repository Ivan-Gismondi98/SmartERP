// ============================================================
//  SMARTERP · projects_page.dart — elenco progetti con avanzamento.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../../core/reporting/entity_report_page.dart';
import '../application/projects_providers.dart';
import '../application/projects_report.dart';
import '../domain/project.dart';
import 'project_detail_page.dart';
import 'project_form_page.dart';

class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  ProjectStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(canProvider(Perm.projectsCreate));
    final listAsync = ref.watch(projectsListProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progetti'),
        actions: [
          IconButton(
            tooltip: 'Report / Export',
            icon: const Icon(Icons.assessment_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    EntityReportPage<Project>(spec: projectsReportSpec))),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(null),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo progetto'),
            )
          : null,
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (all) {
          final filtered = _statusFilter == null
              ? all
              : all.where((p) => p.status == _statusFilter).toList();
          return Column(
            children: [
              _SummaryHeader(projects: all),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Tutti'),
                      selected: _statusFilter == null,
                      onSelected: (_) => setState(() => _statusFilter = null),
                    ),
                    const SizedBox(width: 8),
                    for (final s in ProjectStatus.values) ...[
                      ChoiceChip(
                        label: Text(s.label),
                        selected: _statusFilter == s,
                        onSelected: (_) => setState(
                            () => _statusFilter = _statusFilter == s ? null : s),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Nessun progetto.'))
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(projectsListProvider),
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) => _ProjectTile(
                            project: filtered[i],
                            now: now,
                            onTap: () => _openDetail(filtered[i].id!),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditor(String? id) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProjectFormPage(projectId: id)),
    );
    if (changed == true) ref.invalidate(projectsListProvider);
  }

  Future<void> _openDetail(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProjectDetailPage(projectId: id)),
    );
    ref.invalidate(projectsListProvider);
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.projects});
  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final active =
        projects.where((p) => p.status == ProjectStatus.active).length;
    final done = projects.where((p) => p.status == ProjectStatus.done).length;
    final budget = projects.fold<double>(0, (s, p) => s + p.budget);

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        children: [
          _kpi(context, 'Progetti', '${projects.length}'),
          _kpi(context, 'In corso', '$active'),
          _kpi(context, 'Completati', '$done'),
          _kpi(context, 'Budget totale', Fmt.euro(budget)),
        ],
      ),
    );
  }

  Widget _kpi(BuildContext context, String label, String value) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: t.bodySmall),
        Text(value, style: t.titleMedium),
      ],
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile(
      {required this.project, required this.now, required this.onTap});
  final Project project;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = project.overdue(now);
    return ListTile(
      leading: _StatusBadge(status: project.status),
      title: Row(
        children: [
          Flexible(child: Text(project.name, overflow: TextOverflow.ellipsis)),
          if (overdue)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.schedule, size: 16, color: Colors.orange),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${project.customer?.name ?? project.manager ?? '—'}'
              '${project.dueDate != null ? ' · scad. ${Fmt.date(project.dueDate)}' : ''}'),
          const SizedBox(height: 4),
          if (project.totalTasks > 0) ...[
            LinearProgressIndicator(value: project.progress, minHeight: 6),
            const SizedBox(height: 2),
            Text('${project.doneTasks}/${project.totalTasks} attività',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
      isThreeLine: project.totalTasks > 0,
      trailing: Text(project.status.label,
          style: Theme.of(context).textTheme.bodySmall),
      onTap: onTap,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (status) {
      ProjectStatus.planning => (scheme.outline, Icons.edit_calendar_outlined),
      ProjectStatus.active => (scheme.primary, Icons.play_circle_outline),
      ProjectStatus.onHold => (Colors.orange, Icons.pause_circle_outline),
      ProjectStatus.done => (Colors.green, Icons.check_circle_outline),
      ProjectStatus.cancelled => (scheme.error, Icons.cancel_outlined),
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color),
    );
  }
}
