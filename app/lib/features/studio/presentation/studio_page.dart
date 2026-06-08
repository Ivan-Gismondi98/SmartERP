// ============================================================
//  SMARTERP · studio_page.dart — elenco modelli documento (Studio).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../application/templates_providers.dart';
import '../data/templates_repository.dart';
import '../domain/document_template.dart';
import 'template_form_page.dart';

class StudioPage extends ConsumerWidget {
  const StudioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(canProvider(Perm.studioManage));
    final listAsync = ref.watch(templatesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Studio · Modelli documento')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _open(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo modello'),
            )
          : null,
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (templates) {
          if (templates.isEmpty) {
            return const Center(
                child: Text('Nessun modello. Crea il tuo primo modello.'));
          }
          return ListView.separated(
            itemCount: templates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = templates[i];
              return ListTile(
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: Row(children: [
                  Flexible(child: Text(t.name)),
                  if (t.isDefault)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Chip(
                        label: Text('default'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ]),
                subtitle: Text('Layout: ${t.lineStyle} · '
                    '${t.showVatSummary ? 'con riepilogo IVA' : 'senza riepilogo'}'),
                trailing: canManage
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, ref, t),
                      )
                    : null,
                onTap: canManage ? () => _open(context, ref, t) : null,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _open(
      BuildContext context, WidgetRef ref, DocumentTemplate? t) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TemplateFormPage(template: t)),
    );
    if (saved == true) ref.invalidate(templatesListProvider);
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, DocumentTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare il modello?'),
        content: Text('"${t.name}" verrà eliminato.'),
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
    await ref.read(templatesRepositoryProvider).delete(t.id);
    ref.invalidate(templatesListProvider);
  }
}
