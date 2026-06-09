// ============================================================
//  SMARTERP · crm_page.dart — pipeline commerciale (lead/opportunità)
//  raggruppata per stadio, con KPI e ricerca.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../../core/reporting/entity_report_page.dart';
import '../application/crm_providers.dart';
import '../application/crm_report.dart';
import '../domain/opportunity.dart';
import 'crm_detail_page.dart';
import 'crm_form_page.dart';

class CrmPage extends ConsumerStatefulWidget {
  const CrmPage({super.key});

  @override
  ConsumerState<CrmPage> createState() => _CrmPageState();
}

class _CrmPageState extends ConsumerState<CrmPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(canProvider(Perm.crmCreate));
    final listAsync = ref.watch(opportunitiesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM'),
        actions: [
          IconButton(
            tooltip: 'Report / Export',
            icon: const Icon(Icons.assessment_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    EntityReportPage<Opportunity>(spec: crmReportSpec))),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(null),
              icon: const Icon(Icons.add),
              label: const Text('Nuova opportunità'),
            )
          : null,
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (all) {
          final q = _query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? all
              : all
                  .where((o) =>
                      '${o.title} ${o.displayContact}'.toLowerCase().contains(q))
                  .toList();
          return Column(
            children: [
              _SummaryHeader(opps: all),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Cerca per titolo o contatto',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Nessuna opportunità.'))
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(opportunitiesListProvider),
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 88),
                          children: [
                            for (final stage in CrmStage.values)
                              ..._stageSection(context, stage, filtered),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _stageSection(
      BuildContext context, CrmStage stage, List<Opportunity> all) {
    final items = all.where((o) => o.stage == stage).toList();
    if (items.isEmpty) return const [];
    final value = items.fold<double>(0, (s, o) => s + o.expectedValue);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            _StageDot(stage: stage),
            const SizedBox(width: 8),
            Text('${stage.label}  (${items.length})',
                style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            Text(Fmt.euro(value),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      for (final o in items)
        _OppTile(opp: o, onTap: () => _openDetail(o.id!)),
    ];
  }

  Future<void> _openEditor(String? id) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CrmFormPage(opportunityId: id)),
    );
    if (changed == true) ref.invalidate(opportunitiesListProvider);
  }

  Future<void> _openDetail(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CrmDetailPage(opportunityId: id)),
    );
    ref.invalidate(opportunitiesListProvider);
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.opps});
  final List<Opportunity> opps;

  @override
  Widget build(BuildContext context) {
    final open = opps.where((o) => !o.stage.closed).toList();
    final weighted = open.fold<double>(0, (s, o) => s + o.weightedValue);
    final won = opps.where((o) => o.stage == CrmStage.won).toList();
    final wonValue = won.fold<double>(0, (s, o) => s + o.expectedValue);

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        children: [
          _kpi(context, 'Aperte', '${open.length}'),
          _kpi(context, 'Previsione ponderata', Fmt.euro(weighted)),
          _kpi(context, 'Vinte', '${won.length}'),
          _kpi(context, 'Valore vinto', Fmt.euro(wonValue)),
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

class _OppTile extends StatelessWidget {
  const _OppTile({required this.opp, required this.onTap});
  final Opportunity opp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _StageDot(stage: opp.stage),
      title: Text(opp.title, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '${opp.displayContact}'
          '${opp.expectedClose != null ? '  ·  chiusura ${Fmt.date(opp.expectedClose)}' : ''}'
          '  ·  ${opp.probability}%'),
      trailing: Text(Fmt.euro(opp.expectedValue),
          style: Theme.of(context).textTheme.titleMedium),
      onTap: onTap,
    );
  }
}

class _StageDot extends StatelessWidget {
  const _StageDot({required this.stage});
  final CrmStage stage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (stage) {
      CrmStage.newLead => scheme.outline,
      CrmStage.qualified => scheme.primary,
      CrmStage.proposal => Colors.orange,
      CrmStage.won => Colors.green,
      CrmStage.lost => scheme.error,
    };
    final icon = switch (stage) {
      CrmStage.newLead => Icons.fiber_new_outlined,
      CrmStage.qualified => Icons.verified_outlined,
      CrmStage.proposal => Icons.description_outlined,
      CrmStage.won => Icons.emoji_events_outlined,
      CrmStage.lost => Icons.cancel_outlined,
    };
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
