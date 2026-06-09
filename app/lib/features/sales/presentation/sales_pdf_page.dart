// ============================================================
//  SMARTERP · sales_pdf_page.dart — anteprima e stampa PDF di un
//  preventivo/ordine (con il modello Studio scelto, se presente).
// ============================================================
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../profile/application/profile_providers.dart';
import '../../studio/application/templates_providers.dart';
import '../data/sales_pdf.dart';
import '../domain/sales_document.dart';

class SalesPdfPage extends ConsumerWidget {
  const SalesPdfPage({super.key, required this.doc});

  final SalesDocument doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: Text('PDF · ${doc.displayNumber}')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (profile) {
          final company = profile?.company;
          if (company == null) {
            return const Center(
                child: Text('Dati azienda mancanti per la stampa.'));
          }
          final templateAsync = doc.templateId == null
              ? null
              : ref.watch(templateByIdProvider(doc.templateId!));
          final template = templateAsync?.valueOrNull;

          return PdfPreview(
            key: ValueKey(template?.id ?? 'standard'),
            build: (format) async {
              final bytes = await const SalesPdfGenerator()
                  .build(doc, company, template: template);
              return Uint8List.fromList(bytes);
            },
            canChangePageFormat: false,
            canChangeOrientation: false,
            pdfFileName:
                '${doc.kindLabel}_${doc.displayNumber.replaceAll('/', '-')}.pdf',
          );
        },
      ),
    );
  }
}
