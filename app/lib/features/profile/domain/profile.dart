// ============================================================
//  SMARTERP · profile.dart — modelli di dominio Profile e Company.
//  Mappano le tabelle public.profiles e public.companies.
// ============================================================

/// Ruoli applicativi (enum public.user_role lato DB).
enum UserRole {
  superAdmin,
  admin,
  employee,
  customer;

  static UserRole fromDb(String? value) {
    switch (value) {
      case 'super_admin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'employee':
        return UserRole.employee;
      default:
        return UserRole.customer;
    }
  }

  String get label {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Amministratore';
      case UserRole.employee:
        return 'Dipendente';
      case UserRole.customer:
        return 'Cliente';
    }
  }

  /// Accesso alle aree gestionali (magazzino, fatture, chat interna).
  bool get isStaff =>
      this == UserRole.superAdmin ||
      this == UserRole.admin ||
      this == UserRole.employee;
}

class Company {
  const Company({
    required this.id,
    required this.name,
    this.vatNumber,
    this.taxCode,
    this.regimeFiscale = 'RF01',
    this.address,
    this.zip,
    this.city,
    this.province,
    this.country = 'IT',
    this.transmissionFormat = 'FPR12',
    this.email,
    this.themeSettings = const {},
  });

  final String id;
  final String name;
  final String? vatNumber;
  final String? taxCode;
  final String regimeFiscale;
  final String? address;
  final String? zip;
  final String? city;
  final String? province;
  final String country;
  final String transmissionFormat;
  final String? email;
  final Map<String, dynamic> themeSettings;

  /// P.IVA senza eventuale prefisso "IT".
  String? get vatDigits {
    final v = vatNumber?.trim();
    if (v == null || v.isEmpty) return null;
    return v.toUpperCase().startsWith('IT') ? v.substring(2) : v;
  }

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Azienda',
      vatNumber: json['vat_number'] as String?,
      taxCode: json['tax_code'] as String?,
      regimeFiscale: (json['regime_fiscale'] as String?) ?? 'RF01',
      address: json['address'] as String?,
      zip: json['zip'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      country: (json['country'] as String?) ?? 'IT',
      transmissionFormat: (json['transmission_format'] as String?) ?? 'FPR12',
      email: json['email'] as String?,
      themeSettings:
          (json['theme_settings'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

class Profile {
  const Profile({
    required this.id,
    required this.role,
    this.companyId,
    this.fullName,
    this.avatarUrl,
    this.phone,
    this.isActive = true,
    this.company,
  });

  final String id;
  final UserRole role;
  final String? companyId;
  final String? fullName;
  final String? avatarUrl;
  final String? phone;
  final bool isActive;

  /// Azienda associata, se la query l'ha inclusa (join su companies).
  final Company? company;

  factory Profile.fromJson(Map<String, dynamic> json) {
    final companyJson = json['companies'];
    return Profile(
      id: json['id'] as String,
      role: UserRole.fromDb(json['role'] as String?),
      companyId: json['company_id'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      company: companyJson is Map<String, dynamic>
          ? Company.fromJson(companyJson)
          : null,
    );
  }

  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty) ? fullName! : 'Utente';
}
