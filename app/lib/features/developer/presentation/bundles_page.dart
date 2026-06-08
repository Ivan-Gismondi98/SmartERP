// ============================================================
//  SMARTERP · bundles_page.dart — catalogo Pacchetti di licenze (super).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/licensing.dart';
import '../application/developer_providers.dart';
import '../data/developer_repository.dart';
import '../domain/app_bundle.dart';

class BundlesPage extends ConsumerWidget {
  const BundlesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bundlesListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pacchetti di licenze')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo pacchetto'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (bundles) {
          if (bundles.isEmpty) {
            return const Center(child: Text('Nessun pacchetto.'));
          }
          return ListView.separated(
            itemCount: bundles.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final b = bundles[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.widgets_outlined)),
                title: Text('${b.name} · ${Fmt.euro(b.price)}/${b.period}'),
                subtitle: Text(b.appCodes.map(appLabel).join(', ')),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await ref.read(developerRepositoryProvider).deleteBundle(b.id);
                    ref.invalidate(bundlesListProvider);
                  },
                ),
                onTap: () => _edit(context, ref, b),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, AppBundle? b) async {
    await showDialog(context: context, builder: (_) => _BundleDialog(bundle: b));
    ref.invalidate(bundlesListProvider);
  }
}

class _BundleDialog extends ConsumerStatefulWidget {
  const _BundleDialog({this.bundle});
  final AppBundle? bundle;

  @override
  ConsumerState<_BundleDialog> createState() => _BundleDialogState();
}

class _BundleDialogState extends ConsumerState<_BundleDialog> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  String _period = 'monthly';
  final Set<String> _apps = {};
  bool _busy = false;

  bool get _isNew => widget.bundle == null;

  @override
  void initState() {
    super.initState();
    final b = widget.bundle;
    if (b != null) {
      _name.text = b.name;
      _desc.text = b.description ?? '';
      _price.text = b.price == 0 ? '' : Fmt.amount(b.price);
      _period = b.period;
      _apps.addAll(b.appCodes);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _desc, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _apps.isEmpty) return;
    setState(() => _busy = true);
    final b = AppBundle(
      id: widget.bundle?.id ?? '',
      name: _name.text.trim(),
      description: _desc.text,
      appCodes: _apps.toList(),
      price: Fmt.parseAmount(_price.text) ?? 0,
      period: _period,
    );
    try {
      final repo = ref.read(developerRepositoryProvider);
      if (_isNew) {
        await repo.createBundle(b);
      } else {
        await repo.updateBundle(b);
      }
      if (mounted) Navigator.pop(context);
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
      title: Text(_isNew ? 'Nuovo pacchetto' : 'Modifica pacchetto'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nome *')),
              TextField(
                  controller: _desc,
                  decoration: const InputDecoration(labelText: 'Descrizione')),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Prezzo €'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _period,
                    decoration: const InputDecoration(labelText: 'Periodo'),
                    items: const [
                      DropdownMenuItem(value: 'monthly', child: Text('Mensile')),
                      DropdownMenuItem(value: 'yearly', child: Text('Annuale')),
                      DropdownMenuItem(value: 'once', child: Text('Una tantum')),
                    ],
                    onChanged: (v) => setState(() => _period = v ?? 'monthly'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              const Text('App incluse'),
              for (final code in kAppModules)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(appLabel(code)),
                  value: _apps.contains(code),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _apps.add(code);
                    } else {
                      _apps.remove(code);
                    }
                  }),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Annulla')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salva'),
        ),
      ],
    );
  }
}
