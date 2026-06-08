// ============================================================
//  SMARTERP · format.dart — formattazione localizzata it_IT.
//  Valuta in Euro (es. "1.234,56 €"), percentuali e date gg/mm/aaaa.
// ============================================================
import 'package:intl/intl.dart';

class Fmt {
  Fmt._();

  static final NumberFormat _euro = NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
    decimalDigits: 2,
  );

  static final NumberFormat _decimal2 = NumberFormat('#,##0.00', 'it_IT');
  static final NumberFormat _qty = NumberFormat('#,##0.###', 'it_IT');

  static final DateFormat _date = DateFormat('dd/MM/yyyy');

  /// "1.234,56 €"
  static String euro(num value) => _euro.format(value);

  /// "1.234,56" (senza simbolo, per input/celle)
  static String amount(num value) => _decimal2.format(value);

  /// Quantita' con max 3 decimali: "2", "1,5", "0,75"
  static String qty(num value) => _qty.format(value);

  /// "22%" / "4%" / "10,5%"
  static String percent(num rate) {
    final s = rate == rate.truncate()
        ? rate.toStringAsFixed(0)
        : _decimal2.format(rate);
    return '$s%';
  }

  /// "08/06/2026"
  static String date(DateTime? d) => d == null ? '—' : _date.format(d);

  /// Parsa un importo digitato all'italiana ("1.234,56" o "1234.56").
  static double? parseAmount(String? input) {
    if (input == null) return null;
    var s = input.trim();
    if (s.isEmpty) return null;
    // Rimuove separatori di migliaia '.' e usa '.' come decimale.
    if (s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(s);
  }
}

/// Arrotondamento contabile a 2 decimali (half-up), come da prassi fiscale.
double round2(num value) => (value * 100).round() / 100;
