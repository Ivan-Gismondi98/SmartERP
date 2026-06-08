// ============================================================
//  SMARTERP · invoice_pdf_page.dart — anteprima e stampa PDF fattura.
// ============================================================
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../profile/application/profile_providers.dart';
import '../data/invoice_pdf.dart';
import '../domain/invoice.dart';

class InvoicePdfPage extends ConsumerWidget {
  const InvoicePdfPage({super.key, required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: Text('PDF · ${invoice.displayNumber}')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (profile) {
          final company = profile?.company;
          if (company == null) {
            return const Center(
                child: Text('Dati azienda mancanti per la stampa.'));
          }
          return PdfPreview(
            build: (format) async {
              final bytes = await const InvoicePdfGenerator()
                  .build(invoice, company);
              return Uint8List.fromList(bytes);
            },
            canChangePageFormat: false,
            canChangeOrientation: false,
            pdfFileName: 'Fattura_${invoice.displayNumber.replaceAll('/', '-')}.pdf',
          );
        },
      ),
    );
  }
}
