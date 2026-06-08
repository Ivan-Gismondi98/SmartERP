// ============================================================
//  SMARTERP · ticket.dart — segnalazione/ticket.
// ============================================================
class Ticket {
  const Ticket({
    required this.id,
    this.companyId,
    this.companyName,
    required this.title,
    this.description,
    this.status = 'open',
    this.priority = 'medium',
    this.target = 'developer',
    this.errorLogId,
    this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String? companyId;
  final String? companyName;
  final String title;
  final String? description;
  final String status; // open | in_progress | resolved | closed
  final String priority; // low | medium | high
  final String target; // admin | developer
  final String? errorLogId;
  final String? createdBy;
  final DateTime createdAt;

  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
        id: j['id'] as String,
        companyId: j['company_id'] as String?,
        companyName: (j['companies'] as Map?)?['name'] as String?,
        title: (j['title'] as String?) ?? '',
        description: j['description'] as String?,
        status: (j['status'] as String?) ?? 'open',
        priority: (j['priority'] as String?) ?? 'medium',
        target: (j['target'] as String?) ?? 'developer',
        errorLogId: j['error_log_id'] as String?,
        createdBy: j['created_by'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

const kTicketStatuses = <String, String>{
  'open': 'Aperto',
  'in_progress': 'In lavorazione',
  'resolved': 'Risolto',
  'closed': 'Chiuso',
};

String ticketStatusLabel(String s) => kTicketStatuses[s] ?? s;
String ticketTargetLabel(String t) =>
    t == 'admin' ? 'Amministratore' : 'Sviluppatore';
