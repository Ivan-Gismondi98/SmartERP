// ============================================================
//  SMARTERP · invoice_xml_page.dart — anteprima ed export XML FatturaPA.
// ============================================================
import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/fattura_pa_xml.dart';
import '../domain/invoice.dart';

class InvoiceXmlPage extends ConsumerWidget {
  const InvoiceXmlPage({super.key, required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('XML FatturaPA')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (profile) {
          final company = profile?.company;
          if (company == null) {
            return const Center(
                child: Text('Dati azienda mancanti per generare l\'XML.'));
          }
          if (company.vatDigits == null) {
            return const Center(
                child: Text('Imposta la P.IVA dell\'azienda per l\'export.'));
          }

          final result =
              const FatturaPaGenerator().build(invoice, company);
          return _XmlView(result: result);
        },
      ),
    );
  }
}

class _XmlView extends StatelessWidget {
  const _XmlView({required this.result});
  final FatturaPaResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text('File: ${result.fileName}',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              TextButton.icon(
                onPressed: () => _copy(context),
                icon: const Icon(Icons.copy),
                label: const Text('Copia'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _download(context),
                icon: const Icon(Icons.download),
                label: const Text('Scarica .xml'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            width: double.infinity,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                result.xml,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: result.xml));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('XML copiato.')));
    }
  }

  Future<void> _download(BuildContext context) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(result.xml));
      // file_saver aggiunge l'estensione: passiamo il nome senza ".xml".
      final base = result.fileName.replaceAll('.xml', '');
      await FileSaver.instance.saveFile(
        name: base,
        bytes: bytes,
        ext: 'xml',
        mimeType: MimeType.other,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Scaricato ${result.fileName}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore download: $e')));
      }
    }
  }
}
