// ============================================================
//  SMARTERP · fattura_pa_xml.dart
//  Genera l'XML della Fattura Elettronica secondo il tracciato SdI
//  (FatturaElettronica versione 1.2.2). Copre il caso "ordinario":
//  header (trasmissione, cedente, cessionario) + body (dati generali,
//  righe, riepilogo IVA per aliquota/natura, bollo).
//
//  NOTA: l'XML NON e' firmato digitalmente (.p7m): la firma/invio allo
//  SdI e' un passaggio successivo (accreditamento + firma qualificata).
// ============================================================
import 'package:xml/xml.dart';

import '../../customers/domain/customer.dart';
import '../../profile/domain/profile.dart';
import '../domain/invoice.dart';

class FatturaPaResult {
  const FatturaPaResult({required this.xml, required this.fileName});
  final String xml;
  final String fileName;
}

class FatturaPaGenerator {
  const FatturaPaGenerator();

  static const _ns = 'http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2';

  String _n2(num v) => v.toStringAsFixed(2);
  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Progressivo invio (alfanumerico, max 10): usiamo la sequenza interna.
  String _progressivo(Invoice inv) =>
      (inv.numberingSeq ?? 1).toString().padLeft(5, '0');

  FatturaPaResult build(Invoice inv, Company seller) {
    final cust = inv.customer;
    final format = seller.transmissionFormat;
    final progressivo = _progressivo(inv);

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'p:FatturaElettronica',
      attributes: {
        'versione': format,
        'xmlns:p': _ns,
        'xmlns:ds': 'http://www.w3.org/2000/09/xmldsig#',
        'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance',
      },
      nest: () {
        _header(builder, inv, seller, cust, format, progressivo);
        _body(builder, inv);
      },
    );

    final doc = builder.buildDocument();
    final xml = doc.toXmlString(pretty: true, indent: '  ');
    final fileName = 'IT${seller.vatDigits ?? '00000000000'}_$progressivo.xml';
    return FatturaPaResult(xml: xml, fileName: fileName);
  }

  // ---------- HEADER ----------
  void _header(XmlBuilder b, Invoice inv, Company seller, Customer? cust,
      String format, String progressivo) {
    b.element('FatturaElettronicaHeader', nest: () {
      // DatiTrasmissione
      b.element('DatiTrasmissione', nest: () {
        b.element('IdTrasmittente', nest: () {
          b.element('IdPaese', nest: seller.country);
          b.element('IdCodice', nest: seller.vatDigits ?? '');
        });
        b.element('ProgressivoInvio', nest: progressivo);
        b.element('FormatoTrasmissione', nest: format);
        final sdi = (cust?.sdiCode.isNotEmpty ?? false) ? cust!.sdiCode : '0000000';
        b.element('CodiceDestinatario', nest: sdi);
        if (sdi == '0000000' &&
            cust?.pec != null &&
            cust!.pec!.trim().isNotEmpty) {
          b.element('PECDestinatario', nest: cust.pec!.trim());
        }
      });

      // CedentePrestatore (venditore = azienda)
      b.element('CedentePrestatore', nest: () {
        b.element('DatiAnagrafici', nest: () {
          b.element('IdFiscaleIVA', nest: () {
            b.element('IdPaese', nest: seller.country);
            b.element('IdCodice', nest: seller.vatDigits ?? '');
          });
          if (seller.taxCode != null && seller.taxCode!.trim().isNotEmpty) {
            b.element('CodiceFiscale', nest: seller.taxCode!.trim());
          }
          b.element('Anagrafica', nest: () {
            b.element('Denominazione', nest: seller.name);
          });
          b.element('RegimeFiscale', nest: seller.regimeFiscale);
        });
        _sede(b, seller.address, seller.zip, seller.city, seller.province,
            seller.country);
      });

      // CessionarioCommittente (cliente)
      b.element('CessionarioCommittente', nest: () {
        b.element('DatiAnagrafici', nest: () {
          final vat = _vatDigits(cust?.vatNumber);
          if (vat != null) {
            b.element('IdFiscaleIVA', nest: () {
              b.element('IdPaese', nest: cust?.country ?? 'IT');
              b.element('IdCodice', nest: vat);
            });
          }
          if (cust?.taxCode != null && cust!.taxCode!.trim().isNotEmpty) {
            b.element('CodiceFiscale', nest: cust.taxCode!.trim());
          }
          b.element('Anagrafica', nest: () {
            b.element('Denominazione', nest: cust?.name ?? 'Cliente');
          });
        });
        _sede(b, cust?.address, cust?.zip, cust?.city, cust?.province,
            cust?.country ?? 'IT');
      });
    });
  }

  void _sede(XmlBuilder b, String? address, String? zip, String? city,
      String? province, String country) {
    b.element('Sede', nest: () {
      b.element('Indirizzo', nest: _orDash(address));
      b.element('CAP', nest: _orZip(zip));
      b.element('Comune', nest: _orDash(city));
      if (province != null && province.trim().isNotEmpty) {
        b.element('Provincia', nest: province.trim().toUpperCase());
      }
      b.element('Nazione', nest: country);
    });
  }

  // ---------- BODY ----------
  void _body(XmlBuilder b, Invoice inv) {
    b.element('FatturaElettronicaBody', nest: () {
      b.element('DatiGenerali', nest: () {
        b.element('DatiGeneraliDocumento', nest: () {
          b.element('TipoDocumento', nest: inv.documentType);
          b.element('Divisa', nest: 'EUR');
          b.element('Data', nest: _date(inv.issueDate));
          b.element('Numero', nest: inv.displayNumber);
          if (inv.stampDuty > 0) {
            b.element('DatiBollo', nest: () {
              b.element('BolloVirtuale', nest: 'SI');
              b.element('ImportoBollo', nest: _n2(inv.stampDuty));
            });
          }
          b.element('ImportoTotaleDocumento', nest: _n2(inv.total));
        });
      });

      b.element('DatiBeniServizi', nest: () {
        // Righe
        for (var i = 0; i < inv.items.length; i++) {
          final it = inv.items[i];
          b.element('DettaglioLinee', nest: () {
            b.element('NumeroLinea', nest: '${i + 1}');
            b.element('Descrizione', nest: it.description);
            b.element('Quantita', nest: it.quantity.toStringAsFixed(2));
            b.element('PrezzoUnitario', nest: _n2(it.unitPrice));
            if (it.discountPercent > 0) {
              b.element('ScontoMaggiorazione', nest: () {
                b.element('Tipo', nest: 'SC');
                b.element('Percentuale', nest: _n2(it.discountPercent));
              });
            }
            b.element('PrezzoTotale', nest: _n2(it.taxableBase));
            b.element('AliquotaIVA', nest: _n2(it.vatRate));
            if (it.vatRate == 0 && it.vatNature != null) {
              b.element('Natura', nest: it.vatNature!.code);
            }
          });
        }
        // Riepilogo IVA per aliquota/natura
        for (final l in inv.vatSummary) {
          b.element('DatiRiepilogo', nest: () {
            b.element('AliquotaIVA', nest: _n2(l.vatRate));
            if (l.vatRate == 0 && l.nature != null) {
              b.element('Natura', nest: l.nature!.code);
            }
            b.element('ImponibileImporto', nest: _n2(l.taxable));
            b.element('Imposta', nest: _n2(l.tax));
            b.element('EsigibilitaIVA', nest: 'I'); // I = IVA immediata
          });
        }
      });
    });
  }

  // ---------- helper ----------
  String _orDash(String? v) => (v == null || v.trim().isEmpty) ? '-' : v.trim();
  String _orZip(String? v) =>
      (v == null || v.trim().isEmpty) ? '00000' : v.trim();

  String? _vatDigits(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final s = v.trim();
    return s.toUpperCase().startsWith('IT') ? s.substring(2) : s;
  }
}
