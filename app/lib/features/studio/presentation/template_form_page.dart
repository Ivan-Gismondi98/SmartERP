// ============================================================
//  SMARTERP · template_form_page.dart — editor di un modello documento.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/templates_repository.dart';
import '../domain/document_template.dart';

class TemplateFormPage extends ConsumerStatefulWidget {
  const TemplateFormPage({super.key, this.template});
  final DocumentTemplate? template;

  @override
  ConsumerState<TemplateFormPage> createState() => _TemplateFormPageState();
}

class _TemplateFormPageState extends ConsumerState<TemplateFormPage> {
  final _name = TextEditingController();
  final _header = TextEditingController();
  final _footer = TextEditingController();
  final _primary = TextEditingController();

  String _lineStyle = 'auto';
  bool _showLogo = true;
  bool _showVat = true;
  bool _isDefault = false;
  bool _saving = false;

  DocumentTemplate? get _existing => widget.template;

  @override
  void initState() {
    super.initState();
    final t = _existing;
    _name.text = t?.name ?? '';
    _header.text = t?.headerText ?? '';
    _footer.text = t?.footerText ?? '';
    _primary.text = t?.primaryHex ?? '';
    _lineStyle = t?.lineStyle ?? 'auto';
    _showLogo = t?.showLogo ?? true;
    _showVat = t?.showVatSummary ?? true;
    _isDefault = t?.isDefault ?? false;
  }

  @override
  void dispose() {
    for (final c in [_name, _header, _footer, _primary]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _snack('Inserisci un nome per il modello.');
      return;
    }
    final profile = await ref.read(currentProfileProvider.future);
    final companyId = profile?.companyId;
    if (companyId == null) return;
    setState(() => _saving = true);

    final config = <String, dynamic>{
      'header_text': _header.text.trim(),
      'footer_text': _footer.text.trim(),
      'show_logo': _showLogo,
      'show_vat_summary': _showVat,
      'line_style': _lineStyle,
      'primary_hex': _primary.text.trim().isEmpty ? null : _primary.text.trim(),
    };
    final t = DocumentTemplate(
      id: _existing?.id ?? '',
      companyId: companyId,
      name: _name.text.trim(),
      docType: _existing?.docType ?? 'both',
      isDefault: _isDefault,
      config: config,
    );
    try {
      final repo = ref.read(templatesRepositoryProvider);
      if (_existing == null) {
        await repo.create(companyId, t);
      } else {
        await repo.update(t);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      _snack('Errore: $e');
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title:
              Text(_existing == null ? 'Nuovo modello' : 'Modifica modello')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nome modello *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _header,
            decoration: const InputDecoration(
                labelText: 'Testo intestazione (header)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _footer,
            maxLines: 2,
            decoration:
                const InputDecoration(labelText: 'Testo piè di pagina (footer)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _primary,
            decoration: const InputDecoration(
              labelText: 'Colore primario override (#RRGGBB)',
              hintText: 'Vuoto = usa il branding aziendale',
            ),
          ),
          const Divider(height: 32),
          Text('Layout righe', style: Theme.of(context).textTheme.titleSmall),
          RadioGroup<String>(
            groupValue: _lineStyle,
            onChanged: (v) => setState(() => _lineStyle = v ?? 'auto'),
            child: const Column(
              children: [
                RadioListTile(
                  value: 'auto',
                  title: Text('Automatico'),
                  subtitle: Text('Catalogo solo per i prodotti con flag attivo'),
                ),
                RadioListTile(
                  value: 'catalog',
                  title: Text('Sempre catalogo'),
                  subtitle: Text('Titolo + immagine + descrizione per ogni riga'),
                ),
                RadioListTile(
                  value: 'compact',
                  title: Text('Sempre compatto'),
                  subtitle: Text('Riga sintetica (descrizione + importi)'),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Mostra logo aziendale'),
            value: _showLogo,
            onChanged: (v) => setState(() => _showLogo = v),
          ),
          SwitchListTile(
            title: const Text('Mostra riepilogo IVA'),
            value: _showVat,
            onChanged: (v) => setState(() => _showVat = v),
          ),
          SwitchListTile(
            title: const Text('Modello predefinito'),
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('Salva modello'),
          ),
        ],
      ),
    );
  }
}
