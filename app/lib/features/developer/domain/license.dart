// ============================================================
//  SMARTERP · license.dart — licenza (app) di un'organizzazione.
// ============================================================
class License {
  const License({
    required this.id,
    this.companyId,
    this.companyName,
    required this.name,
    this.status = 'active',
    this.price = 0,
    this.period = 'monthly',
    this.startDate,
    this.renewalDate,
    this.notes,
    this.appCodes = const ['suite'],
    this.isDefault = false,
  });

  final String id;

  /// Organizzazione assegnataria. NULL per le licenze predefinite (pacchetti
  /// di catalogo non assegnati ad alcuna organizzazione).
  final String? companyId;
  final String? companyName;
  final String name;
  final String status; // active | suspended | expired
  final double price;
  final String period; // monthly | yearly | once
  final DateTime? startDate;
  final DateTime? renewalDate;
  final String? notes;

  /// App abilitate da questa licenza ('suite' = tutte).
  final List<String> appCodes;

  /// Licenza predefinita (seedata dal sistema): protetta, non selezionabile.
  final bool isDefault;

  bool overdueAt(DateTime now) =>
      status == 'active' &&
      renewalDate != null &&
      renewalDate!.isBefore(DateTime(now.year, now.month, now.day));

  factory License.fromJson(Map<String, dynamic> j) => License(
        id: j['id'] as String,
        companyId: j['company_id'] as String?,
        companyName: (j['companies'] as Map?)?['name'] as String?,
        name: j['name'] as String,
        status: (j['status'] as String?) ?? 'active',
        price: (j['price'] as num?)?.toDouble() ?? 0,
        period: (j['period'] as String?) ?? 'monthly',
        startDate: j['start_date'] == null
            ? null
            : DateTime.tryParse(j['start_date'] as String),
        renewalDate: j['renewal_date'] == null
            ? null
            : DateTime.tryParse(j['renewal_date'] as String),
        notes: j['notes'] as String?,
        appCodes: ((j['app_codes'] as List?)
                ?.map((e) => e as String)
                .toList()) ??
            [if (j['app_code'] != null) j['app_code'] as String else 'suite'],
        isDefault: (j['is_default'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'name': name,
        'status': status,
        'price': price,
        'period': period,
        'start_date': _d(startDate),
        'renewal_date': _d(renewalDate),
        'notes': notes,
        'app_codes': appCodes,
        // app_code (colonna legacy NOT NULL): primo codice o 'suite'.
        'app_code': appCodes.contains('suite')
            ? 'suite'
            : (appCodes.isNotEmpty ? appCodes.first : 'suite'),
      };

  static String? _d(DateTime? d) => d == null ? null : staticDate(d);

  /// Formatta una data come 'aaaa-mm-gg' (per le colonne date del DB).
  static String staticDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
