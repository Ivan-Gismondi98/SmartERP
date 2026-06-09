// ============================================================
//  SMARTERP · account.dart — conto del piano dei conti.
// ============================================================

/// Natura del conto (sezione di bilancio).
enum AccountNature {
  attivo('attivo', 'Attività', true),
  passivo('passivo', 'Passività', false),
  patrimonio('patrimonio', 'Patrimonio netto', false),
  costo('costo', 'Costo', true),
  ricavo('ricavo', 'Ricavo', false);

  const AccountNature(this.db, this.label, this.debitPositive);
  final String db;
  final String label;

  /// True se il saldo "naturale" del conto è in dare (attività e costi).
  /// Serve a presentare il saldo con segno coerente.
  final bool debitPositive;

  static AccountNature fromDb(String? v) => AccountNature.values
      .firstWhere((n) => n.db == v, orElse: () => AccountNature.costo);

  /// True se il conto appartiene allo Stato Patrimoniale.
  bool get isBalanceSheet =>
      this == attivo || this == passivo || this == patrimonio;

  /// True se il conto appartiene al Conto Economico.
  bool get isIncomeStatement => this == costo || this == ricavo;
}

class Account {
  Account({
    this.id,
    required this.companyId,
    this.code = '',
    this.name = '',
    this.nature = AccountNature.costo,
    this.isActive = true,
  });

  final String? id;
  final String companyId;
  String code;
  String name;
  AccountNature nature;
  bool isActive;

  String get display => '$code · $name';

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String,
        companyId: j['company_id'] as String,
        code: (j['code'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        nature: AccountNature.fromDb(j['nature'] as String?),
        isActive: (j['is_active'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'code': code.trim(),
        'name': name.trim(),
        'nature': nature.db,
        'is_active': isActive,
      };
}
