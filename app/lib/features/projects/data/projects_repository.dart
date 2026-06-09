// ============================================================
//  SMARTERP · projects_repository.dart — CRUD progetti e attività.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/project.dart';
import '../domain/project_task.dart';

const _projSelect =
    'id, company_id, customer_id, name, status, start_date, due_date, budget, '
    'manager, description, '
    'customers ( id, company_id, name, is_company, vat_number, tax_code, '
    'address, zip, city, province, country, sdi_code, pec, email, phone )';

const _taskSelect =
    'id, project_id, position, title, description, status, priority, '
    'assigned_to, due_date';

class ProjectsRepository {
  ProjectsRepository(this._client);
  final SupabaseClient _client;

  Future<List<Project>> list(String companyId) async {
    final rows = await _client
        .from('projects')
        .select('$_projSelect, project_tasks ( $_taskSelect )')
        .eq('company_id', companyId)
        .order('due_date', ascending: true, nullsFirst: false)
        .order('created_at', ascending: false);
    return rows.map(Project.fromJson).toList();
  }

  Future<Project> getById(String id) async {
    final row = await _client
        .from('projects')
        .select('$_projSelect, project_tasks ( $_taskSelect )')
        .eq('id', id)
        .single();
    return Project.fromJson(row);
  }

  Future<String> create(Project p) async {
    final row =
        await _client.from('projects').insert(p.toJson()).select('id').single();
    return row['id'] as String;
  }

  Future<void> update(Project p) async {
    await _client.from('projects').update(p.toJson()).eq('id', p.id!);
  }

  Future<void> delete(String id) async {
    await _client.from('projects').delete().eq('id', id);
  }

  // ---------------- Attività ----------------
  Future<void> saveTask(ProjectTask t) async {
    if (t.id == null) {
      await _client.from('project_tasks').insert(t.toJson());
    } else {
      await _client.from('project_tasks').update(t.toJson()).eq('id', t.id!);
    }
  }

  Future<void> setTaskStatus(String id, TaskStatus status) async {
    await _client
        .from('project_tasks')
        .update({'status': status.db}).eq('id', id);
  }

  Future<void> deleteTask(String id) async {
    await _client.from('project_tasks').delete().eq('id', id);
  }
}

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return ProjectsRepository(ref.watch(dataClientProvider));
});
