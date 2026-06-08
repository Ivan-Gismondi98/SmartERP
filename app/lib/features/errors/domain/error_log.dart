// ============================================================
//  SMARTERP · error_log.dart — voce del registro errori.
// ============================================================
class ErrorLog {
  const ErrorLog({
    required this.id,
    this.companyId,
    this.severity = 'error',
    this.module,
    required this.message,
    this.details,
    this.route,
    required this.createdAt,
  });

  final String id;
  final String? companyId;
  final String severity;
  final String? module;
  final String message;
  final String? details;
  final String? route;
  final DateTime createdAt;

  factory ErrorLog.fromJson(Map<String, dynamic> j) => ErrorLog(
        id: j['id'] as String,
        companyId: j['company_id'] as String?,
        severity: (j['severity'] as String?) ?? 'error',
        module: j['module'] as String?,
        message: (j['message'] as String?) ?? '',
        details: j['details'] as String?,
        route: j['route'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// Livelli di gravità (per filtri e badge).
const kSeverities = <String>['info', 'warning', 'error', 'fatal'];

String severityLabel(String s) {
  switch (s) {
    case 'info':
      return 'Info';
    case 'warning':
      return 'Avviso';
    case 'fatal':
      return 'Critico';
    default:
      return 'Errore';
  }
}
