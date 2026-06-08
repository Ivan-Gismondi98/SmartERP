// Verifica la generazione dell'XML FatturaPA su una fattura di esempio.
import 'package:flutter_test/flutter_test.dart';
import 'package:smarterp/features/customers/domain/customer.dart';
import 'package:smarterp/features/invoices/data/fattura_pa_xml.dart';
import 'package:smarterp/features/invoices/domain/invoice.dart';
import 'package:smarterp/features/invoices/domain/vat.dart';
import 'package:smarterp/features/profile/domain/profile.dart';
import 'package:xml/xml.dart';

void main() {
  const company = Company(
    id: 'c1',
    name: 'Talete Demo S.r.l.',
    vatNumber: 'IT01234567890',
    taxCode: '01234567890',
    regimeFiscale: 'RF01',
    address: 'Via Garibaldi 10',
    zip: '20121',
    city: 'Milano',
    province: 'MI',
  );

  const customer = Customer(
    id: 'k1',
    companyId: 'c1',
    name: 'Cliente Esempio S.p.A.',
    vatNumber: 'IT09876543210',
    address: 'Via Roma 1',
    zip: '00100',
    city: 'Roma',
    province: 'RM',
    sdiCode: '0000000',
    pec: 'cliente@pec.it',
  );

  test('Genera un XML FatturaPA ben formato e con i dati attesi', () {
    final inv = Invoice(
      companyId: 'c1',
      customerId: 'k1',
      customer: customer,
      invoiceNumber: '1/2026',
      status: InvoiceStatus.sent,
      numberingSeq: 1,
      numberingYear: 2026,
      issueDate: DateTime(2026, 6, 8),
      stampDuty: 2.0,
      items: [
        InvoiceItem(
            description: 'Consulenza', quantity: 1, unitPrice: 100, vatRate: 22),
        InvoiceItem(
            description: 'Prestazione esente',
            quantity: 1,
            unitPrice: 80,
            vatRate: 0,
            vatNature: VatNature.n4),
      ],
    );

    final result = const FatturaPaGenerator().build(inv, company);

    // Ben formato: deve fare il parse senza errori.
    final doc = XmlDocument.parse(result.xml);

    // Root + versione
    final root = doc.rootElement;
    expect(root.name.qualified, 'p:FatturaElettronica');
    expect(root.getAttribute('versione'), 'FPR12');

    // Nome file: IT<piva>_<progressivo>.xml
    expect(result.fileName, 'IT01234567890_00001.xml');

    // Dati chiave
    expect(result.xml, contains('<Numero>1/2026</Numero>'));
    expect(result.xml, contains('<TipoDocumento>TD01</TipoDocumento>'));
    expect(result.xml, contains('<CodiceDestinatario>0000000</CodiceDestinatario>'));
    expect(result.xml, contains('<PECDestinatario>cliente@pec.it</PECDestinatario>'));
    expect(result.xml, contains('<Natura>N4</Natura>'));
    expect(result.xml, contains('<ImportoBollo>2.00</ImportoBollo>'));

    // Riepilogo: 2 aliquote (22 e 0)
    final riepiloghi = doc.findAllElements('DatiRiepilogo').toList();
    expect(riepiloghi.length, 2);

    // Totale documento = 100 + 80 (imponibili) + 22 (IVA) + 2 (bollo) = 204
    expect(result.xml, contains('<ImportoTotaleDocumento>204.00</ImportoTotaleDocumento>'));
  });
}
