// ============================================================
//  SMARTERP · company_branding_page.dart
//  Branding per-tenant: colori (hex) e logo, salvati in
//  companies.theme_settings e usati nei PDF.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/company_repository.dart';

/// Converte "#RRGGBB" in Color (null se non valido).
Color? hexToColor(String? hex) {
  if (hex == null) return null;
  var h = hex.trim().replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

class CompanyBrandingPage extends ConsumerStatefulWidget {
  const CompanyBrandingPage({super.key});

  @override
  ConsumerState<CompanyBrandingPage> createState() =>
      _CompanyBrandingPageState();
}

class _CompanyBrandingPageState extends ConsumerState<CompanyBrandingPage> {
  final _primary = TextEditingController();
  final _secondary = TextEditingController();
  final _accent = TextEditingController();
  final _logo = TextEditingController();
  bool _init = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_primary, _secondary, _accent, _logo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final profile = await ref.read(currentProfileProvider.future);
    final company = profile?.company;
    if (company == null) return;
    setState(() => _saving = true);
    final theme = <String, dynamic>{
      ...company.themeSettings,
      'primary': _primary.text.trim(),
      'secondary': _secondary.text.trim(),
      'accent': _accent.text.trim(),
      'logo_url': _logo.text.trim().isEmpty ? null : _logo.text.trim(),
    };
    try {
      await ref
          .read(companyRepositoryProvider)
          .updateThemeSettings(company.id, theme);
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Branding salvato.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Branding aziendale')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (profile) {
          final company = profile?.company;
          if (company == null) {
            return const Center(child: Text('Nessuna azienda associata.'));
          }
          if (!_init) {
            _primary.text = company.brandPrimaryHex;
            _secondary.text = company.brandSecondaryHex;
            _accent.text = company.brandAccentHex;
            _logo.text = company.logoUrl ?? '';
            _init = true;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Questi colori e il logo vengono applicati ai PDF delle '
                  'fatture.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              _ColorField(label: 'Colore primario', controller: _primary,
                  onChanged: () => setState(() {})),
              _ColorField(label: 'Colore secondario', controller: _secondary,
                  onChanged: () => setState(() {})),
              _ColorField(label: 'Colore accento', controller: _accent,
                  onChanged: () => setState(() {})),
              const SizedBox(height: 8),
              TextField(
                controller: _logo,
                decoration: const InputDecoration(
                  labelText: 'URL logo (opzionale)',
                  hintText: 'https://… (PNG/JPG)',
                  prefixIcon: Icon(Icons.image_outlined),
                ),
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
                label: const Text('Salva branding'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ColorField extends StatelessWidget {
  const _ColorField(
      {required this.label, required this.controller, required this.onChanged});
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(controller.text);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          labelText: label,
          hintText: '#RRGGBB',
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color ?? Colors.transparent,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            width: 24,
          ),
        ),
      ),
    );
  }
}
