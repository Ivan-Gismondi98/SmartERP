// ============================================================
//  SMARTERP · customer.dart — anagrafica cliente (cessionario).
//  Contiene i dati fiscali richiesti da una fattura italiana.
// ============================================================
class Customer {
  const Customer({
    required this.id,
    required this.companyId,
    required this.name,
    this.isCompany = true,
    this.vatNumber,
    this.taxCode,
    this.address,
    this.zip,
    this.city,
    this.province,
    this.country = 'IT',
    this.sdiCode = '0000000',
    this.pec,
    this.email,
    this.phone,
  });

  final String id;
  final String companyId;
  final String name;
  final bool isCompany;
  final String? vatNumber;
  final String? taxCode;
  final String? address;
  final String? zip;
  final String? city;
  final String? province;
  final String country;
  final String sdiCode;
  final String? pec;
  final String? email;
  final String? phone;

  /// Riga indirizzo compatta: "Via Roma 1, 00100 Roma (RM)".
  String get fullAddress {
    final parts = <String>[];
    if (address != null && address!.isNotEmpty) parts.add(address!);
    final cityLine = [
      if (zip != null && zip!.isNotEmpty) zip!,
      if (city != null && city!.isNotEmpty) city!,
      if (province != null && province!.isNotEmpty) '($province)',
    ].join(' ');
    if (cityLine.isNotEmpty) parts.add(cityLine);
    return parts.join(', ');
  }

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as String,
        companyId: j['company_id'] as String,
        name: j['name'] as String,
        isCompany: (j['is_company'] as bool?) ?? true,
        vatNumber: j['vat_number'] as String?,
        taxCode: j['tax_code'] as String?,
        address: j['address'] as String?,
        zip: j['zip'] as String?,
        city: j['city'] as String?,
        province: j['province'] as String?,
        country: (j['country'] as String?) ?? 'IT',
        sdiCode: (j['sdi_code'] as String?) ?? '0000000',
        pec: j['pec'] as String?,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
      );

  /// Per insert/update (esclude id/company_id, gestiti dal repository).
  Map<String, dynamic> toJson() => {
        'name': name,
        'is_company': isCompany,
        'vat_number': _n(vatNumber),
        'tax_code': _n(taxCode),
        'address': _n(address),
        'zip': _n(zip),
        'city': _n(city),
        'province': _n(province),
        'country': country,
        'sdi_code': sdiCode.isEmpty ? '0000000' : sdiCode,
        'pec': _n(pec),
        'email': _n(email),
        'phone': _n(phone),
      };

  static String? _n(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
}

/// Validazioni fiscali italiane di base.
class FiscalValidators {
  FiscalValidators._();

  /// Partita IVA italiana: 11 cifre con checksum (Luhn-like ufficiale).
  /// Accetta prefisso opzionale "IT". Ritorna null se valida, altrimenti msg.
  static String? validateVat(String? raw, {bool required = false}) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return required ? 'P.IVA obbligatoria' : null;
    var digits = v.toUpperCase().startsWith('IT') ? v.substring(2) : v;
    digits = digits.trim();
    if (!RegExp(r'^\d{11}$').hasMatch(digits)) {
      return 'La P.IVA deve avere 11 cifre';
    }
    var sum = 0;
    for (var i = 0; i < 11; i++) {
      var n = int.parse(digits[i]);
      if (i.isOdd) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
    }
    if (sum % 10 != 0) return 'P.IVA non valida (checksum)';
    return null;
  }

  /// Codice Fiscale: 16 alfanumerici (persona fisica) o 11 cifre (società).
  static String? validateTaxCode(String? raw, {bool required = false}) {
    final v = raw?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return required ? 'Codice Fiscale obbligatorio' : null;
    final isPerson = RegExp(r'^[A-Z0-9]{16}$').hasMatch(v);
    final isCompany = RegExp(r'^\d{11}$').hasMatch(v);
    if (!isPerson && !isCompany) {
      return 'Codice Fiscale non valido (16 caratteri o 11 cifre)';
    }
    return null;
  }

  /// Codice Destinatario SdI: 6 (PA) o 7 (privati) caratteri alfanumerici.
  static String? validateSdi(String? raw) {
    final v = raw?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return null; // verra' normalizzato a 0000000
    if (!RegExp(r'^[A-Z0-9]{6,7}$').hasMatch(v)) {
      return 'Codice Destinatario: 6 o 7 caratteri';
    }
    return null;
  }
}
