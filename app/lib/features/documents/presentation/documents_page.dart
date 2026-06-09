// ============================================================
//  SMARTERP · documents_page.dart — archivio documenti interni.
//  Upload su Storage, ricerca, filtro per categoria, apertura e gestione.
// ============================================================
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/permissions/permission_codes.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../application/documents_providers.dart';
import '../data/documents_repository.dart';
import '../domain/document_file.dart';

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});

  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  String _query = '';
  String? _category;
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(canProvider(Perm.documentsCreate));
    final canEdit = ref.watch(canProvider(Perm.documentsEdit));
    final canDelete = ref.watch(canProvider(Perm.documentsDelete));
    final listAsync = ref.watch(documentsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documenti')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _uploading ? null : _pickAndUpload,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file),
              label: const Text('Carica'),
            )
          : null,
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (all) {
          final categories = <String>{for (final d in all) d.category}.toList()
            ..sort();
          final q = _query.trim().toLowerCase();
          final filtered = all.where((d) {
            if (_category != null && d.category != _category) return false;
            if (q.isEmpty) return true;
            return '${d.title} ${d.fileName} ${d.description ?? ''}'
                .toLowerCase()
                .contains(q);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Cerca documenti',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              if (categories.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      ChoiceChip(
                        label: const Text('Tutte'),
                        selected: _category == null,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                      const SizedBox(width: 8),
                      for (final c in categories) ...[
                        ChoiceChip(
                          label: Text(c),
                          selected: _category == c,
                          onSelected: (_) => setState(
                              () => _category = _category == c ? null : c),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Nessun documento.'))
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(documentsListProvider),
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) => _DocTile(
                            doc: filtered[i],
                            canEdit: canEdit,
                            canDelete: canDelete,
                            onOpen: () => _open(filtered[i]),
                            onEdit: () => _editMeta(filtered[i]),
                            onDelete: () => _delete(filtered[i]),
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

  Future<void> _open(DocumentFile d) async {
    final uri = Uri.tryParse(d.fileUrl);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('Impossibile aprire il documento.');
    }
  }

  Future<void> _pickAndUpload() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.bytes == null) {
      _snack('Impossibile leggere il file selezionato.');
      return;
    }
    if (!mounted) return;
    final meta = await showDialog<_UploadMeta>(
      context: context,
      builder: (_) => _UploadDialog(fileName: f.name),
    );
    if (meta == null) return;

    setState(() => _uploading = true);
    try {
      final profile = await ref.read(currentProfileProvider.future);
      final companyId = profile?.companyId;
      if (companyId == null) throw 'Nessuna azienda associata';
      await ref.read(documentsRepositoryProvider).upload(
            companyId: companyId,
            title: meta.title,
            category: meta.category,
            description: meta.description,
            bytes: f.bytes!,
            fileName: f.name,
            mimeType: f.extension,
            uploadedBy: profile?.id,
            stamp: DateTime.now().millisecondsSinceEpoch,
          );
      ref.invalidate(documentsListProvider);
      _snack('Documento caricato.');
    } catch (e) {
      _snack('Errore upload: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _editMeta(DocumentFile d) async {
    final meta = await showDialog<_UploadMeta>(
      context: context,
      builder: (_) => _UploadDialog(
        fileName: d.fileName,
        initialTitle: d.title,
        initialCategory: d.category,
        initialDescription: d.description,
      ),
    );
    if (meta == null) return;
    try {
      d
        ..title = meta.title
        ..category = meta.category
        ..description = meta.description;
      await ref.read(documentsRepositoryProvider).updateMeta(d);
      ref.invalidate(documentsListProvider);
    } catch (e) {
      _snack('Errore: $e');
    }
  }

  Future<void> _delete(DocumentFile d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare il documento?'),
        content: Text(d.title),
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
      await ref.read(documentsRepositoryProvider).delete(d);
      ref.invalidate(documentsListProvider);
    } catch (e) {
      _snack('Errore: $e');
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.doc,
    required this.canEdit,
    required this.canDelete,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });
  final DocumentFile doc;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  IconData get _icon => switch (doc.extension) {
        'pdf' => Icons.picture_as_pdf,
        'doc' || 'docx' => Icons.description,
        'xls' || 'xlsx' || 'csv' => Icons.table_chart,
        'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' => Icons.image,
        'zip' || 'rar' || '7z' => Icons.folder_zip,
        _ => Icons.insert_drive_file,
      };

  @override
  Widget build(BuildContext context) {
    final when = DateFormat('dd/MM/yyyy').format(doc.createdAt.toLocal());
    return ListTile(
      leading: Icon(_icon, color: Theme.of(context).colorScheme.primary),
      title: Text(doc.title, overflow: TextOverflow.ellipsis),
      subtitle: Text('${doc.category} · ${doc.sizeLabel} · $when'),
      onTap: onOpen,
      trailing: (canEdit || canDelete)
          ? PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'open') onOpen();
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'open', child: Text('Apri')),
                if (canEdit)
                  const PopupMenuItem(value: 'edit', child: Text('Modifica dati')),
                if (canDelete)
                  const PopupMenuItem(value: 'delete', child: Text('Elimina')),
              ],
            )
          : const Icon(Icons.open_in_new, size: 18),
    );
  }
}

class _UploadMeta {
  const _UploadMeta(this.title, this.category, this.description);
  final String title;
  final String category;
  final String? description;
}

class _UploadDialog extends StatefulWidget {
  const _UploadDialog({
    required this.fileName,
    this.initialTitle,
    this.initialCategory,
    this.initialDescription,
  });
  final String fileName;
  final String? initialTitle;
  final String? initialCategory;
  final String? initialDescription;

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late String _category;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
        text: widget.initialTitle ?? widget.fileName);
    _desc = TextEditingController(text: widget.initialDescription ?? '');
    _category = widget.initialCategory ?? kDocCategories.first;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Le categorie note + eventuale categoria personalizzata già impostata.
    final cats = <String>{...kDocCategories, _category}.toList();
    return AlertDialog(
      title: Text(widget.initialTitle == null ? 'Carica documento' : 'Modifica dati'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.fileName,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Titolo *')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [
                for (final c in cats)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) =>
                  setState(() => _category = v ?? kDocCategories.first),
            ),
            const SizedBox(height: 8),
            TextField(
                controller: _desc,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descrizione')),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla')),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty) return;
            Navigator.pop(
                context, _UploadMeta(_title.text, _category, _desc.text));
          },
          child: Text(widget.initialTitle == null ? 'Carica' : 'Salva'),
        ),
      ],
    );
  }
}
