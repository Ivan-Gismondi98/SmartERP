// ============================================================
//  SMARTERP · vat.dart — aliquote IVA italiane e codici Natura.
// ============================================================

/// Aliquote IVA ordinarie italiane (in punti percentuali).
const kVatRates = <double>[22, 10, 5, 4, 0];

/// Codici "Natura" (tracciato FatturaPA) usati quando l'aliquota e' 0:
/// indicano il motivo di assenza dell'IVA. Obbligatori a 0% in fattura.
enum VatNature {
  n1('N1', 'Escluse ex art. 15'),
  n2_1('N2.1', 'Non soggette - art. 7-7septies'),
  n2_2('N2.2', 'Non soggette - altri casi'),
  n3_1('N3.1', 'Non imponibili - esportazioni'),
  n3_2('N3.2', 'Non imponibili - cessioni intracomunitarie'),
  n3_5('N3.5', 'Non imponibili - dichiarazione d\'intento'),
  n4('N4', 'Esenti'),
  n5('N5', 'Regime del margine / IVA non esposta'),
  n6_2('N6.2', 'Reverse charge - oro e argento'),
  n7('N7', 'IVA assolta in altro Stato UE');

  const VatNature(this.code, this.label);
  final String code;
  final String label;

  static VatNature? fromCode(String? code) {
    if (code == null) return null;
    for (final n in VatNature.values) {
      if (n.code == code) return n;
    }
    return null;
  }
}
