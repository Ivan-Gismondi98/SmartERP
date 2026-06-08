// ============================================================
//  SMARTERP · supplier.dart — fornitore (azienda da cui si acquista).
// ============================================================
class Supplier {
  const Supplier({
    required this.id,
    required this.companyId,
    required this.name,
    this.vatNumber,
    this.email,
    this.phone,
    this.address,
  });

  final String id;
  final String companyId;
  final String name;
  final String? vatNumber;
  final String? email;
  final String? phone;
  final String? address;

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
        id: j['id'] as String,
        companyId: j['company_id'] as String,
        name: j['name'] as String,
        vatNumber: j['vat_number'] as String?,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        address: j['address'] as String?,
      );

  Map<String, dynamic> toJson() {
    String? n(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    return {
      'name': name.trim(),
      'vat_number': n(vatNumber),
      'email': n(email),
      'phone': n(phone),
      'address': n(address),
    };
  }
}
