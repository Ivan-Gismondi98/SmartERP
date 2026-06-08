// ============================================================
//  SMARTERP · app_user.dart — utente (profilo + email) per la gestione.
// ============================================================
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
    this.companyId,
    this.companyName,
    this.isActive = true,
  });

  final String id;
  final String email;
  final String? fullName;
  final String role; // super_admin | admin | employee | customer
  final String? companyId;
  final String? companyName;
  final bool isActive;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        email: (j['email'] as String?) ?? '',
        fullName: j['full_name'] as String?,
        role: (j['role'] as String?) ?? 'customer',
        companyId: j['company_id'] as String?,
        companyName: j['company_name'] as String?,
        isActive: (j['is_active'] as bool?) ?? true,
      );
}

const kRoleLabels = <String, String>{
  'super_admin': 'Sviluppatore (super admin)',
  'admin': 'Amministratore',
  'employee': 'Dipendente',
  'customer': 'Utente',
};
