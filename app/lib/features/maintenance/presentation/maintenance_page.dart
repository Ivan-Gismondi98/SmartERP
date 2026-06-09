// ============================================================
//  SMARTERP · maintenance_page.dart — hub Manutenzione a schede:
//  Richieste di intervento · Attrezzature.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../application/maintenance_providers.dart';
import '../domain/equipment.dart';
import '../domain/maintenance_request.dart';
import 'equipment_form_dialog.dart';
import 'request_detail_page.dart';
import 'request_form_page.dart';

class MaintenancePage extends ConsumerStatefulWidget {
  const MaintenancePage({super.key});

  @override
  ConsumerState<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends ConsumerState<MaintenancePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(canProvider(Perm.maintenanceCreate));
    final canEquip = ref.watch(canProvider(Perm.maintenanceEquipment));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manutenzione'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Richieste'),
            Tab(text: 'Attrezzature'),
          ],
        ),
      ),
      floatingActionButton: _fab(canCreate, canEquip),
      body: TabBarView(
        controller: _tab,
        children: const [
          _RequestsTab(),
          _EquipmentTab(),
        ],
      ),
    );
  }

  Widget? _fab(bool canCreate, bool canEquip) {
    if (_tab.index == 0 && canCreate) {
      return FloatingActionButton.extended(
        onPressed: () => _openRequest(null),
        icon: const Icon(Icons.add),
        label: const Text('Richiesta'),
      );
    }
    if (_tab.index == 1 && canEquip) {
      return FloatingActionButton.extended(
        onPressed: () => _editEquipment(null),
        icon: const Icon(Icons.add),
        label: const Text('Attrezzatura'),
      );
    }
    return null;
  }

  Future<void> _openRequest(String? id) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RequestFormPage(requestId: id)),
    );
    if (changed == true) ref.invalidate(maintenanceRequestsProvider);
  }

  Future<void> _editEquipment(Equipment? e) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => EquipmentFormDialog(equipment: e),
    );
    if (saved == true) ref.invalidate(equipmentListProvider);
  }
}

// ============================================================
//  TAB — Richieste
// ============================================================
class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(maintenanceRequestsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore: $e')),
      data: (reqs) {
        if (reqs.isEmpty) {
          return const Center(child: Text('Nessuna richiesta.'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(maintenanceRequestsProvider),
          child: ListView.separated(
            itemCount: reqs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = reqs[i];
              return ListTile(
                leading: _StatusBadge(status: r.status),
                title: Text(r.title, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    '${r.equipmentName ?? 'Generale'} · ${r.type.label}'
                    '${r.scheduledDate != null ? ' · ${Fmt.date(r.scheduledDate)}' : ''}'),
                trailing: _PriorityChip(priority: r.priority),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => RequestDetailPage(requestId: r.id!)));
                  ref.invalidate(maintenanceRequestsProvider);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final MaintenanceStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (status) {
      MaintenanceStatus.open => (scheme.primary, Icons.report_problem_outlined),
      MaintenanceStatus.inProgress =>
        (Colors.orange, Icons.build_circle_outlined),
      MaintenanceStatus.done => (Colors.green, Icons.task_alt),
      MaintenanceStatus.cancelled => (scheme.outline, Icons.cancel_outlined),
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});
  final MaintenancePriority priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      MaintenancePriority.low => Colors.blueGrey,
      MaintenancePriority.medium => Colors.teal,
      MaintenancePriority.high => Colors.orange,
      MaintenancePriority.urgent => Colors.red,
    };
    return Text(priority.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600));
  }
}

// ============================================================
//  TAB — Attrezzature
// ============================================================
class _EquipmentTab extends ConsumerWidget {
  const _EquipmentTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(equipmentListProvider);
    final canEquip = ref.watch(canProvider(Perm.maintenanceEquipment));
    final now = DateTime.now();
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Nessuna attrezzatura registrata.'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(equipmentListProvider),
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = items[i];
              final overdue = e.overdue(now);
              return ListTile(
                leading: _EquipStatusIcon(status: e.status),
                title: Text(e.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    '${[e.code, e.category, e.location].where((x) => x != null && x.isNotEmpty).join(' · ')}'
                    '${e.nextService != null ? '\nProssima manut.: ${Fmt.date(e.nextService)}' : ''}',
                    style: overdue
                        ? const TextStyle(color: Colors.orange)
                        : null),
                isThreeLine: e.nextService != null,
                trailing: Text(e.status.label,
                    style: Theme.of(context).textTheme.bodySmall),
                onTap: canEquip
                    ? () async {
                        final saved = await showDialog<bool>(
                          context: context,
                          builder: (_) => EquipmentFormDialog(equipment: e),
                        );
                        if (saved == true) {
                          ref.invalidate(equipmentListProvider);
                        }
                      }
                    : null,
              );
            },
          ),
        );
      },
    );
  }
}

class _EquipStatusIcon extends StatelessWidget {
  const _EquipStatusIcon({required this.status});
  final EquipmentStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (status) {
      EquipmentStatus.operational => (Colors.green, Icons.check_circle_outline),
      EquipmentStatus.maintenance => (Colors.orange, Icons.build_outlined),
      EquipmentStatus.outOfService => (scheme.error, Icons.do_not_disturb_on_outlined),
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color),
    );
  }
}
