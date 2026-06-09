// ============================================================
//  SMARTERP · opportunity.dart — opportunità CRM (pipeline commerciale).
//  Un'unica entità attraversa gli stadi: lead -> qualificato -> proposta
//  -> vinta/persa.
// ============================================================
import '../../customers/domain/customer.dart';

/// Stadio della pipeline.
enum CrmStage {
  newLead('new', 'Nuovo', false),
  qualified('qualified', 'Qualificato', false),
  proposal('proposal', 'Proposta', false),
  won('won', 'Vinta', true),
  lost('lost', 'Persa', true);

  const CrmStage(this.db, this.label, this.closed);
  final String db;
  final String label;

  /// Stadio finale (chiuso): vinta o persa.
  final bool closed;

  static CrmStage fromDb(String? v) =>
      CrmStage.values.firstWhere((s) => s.db == v, orElse: () => CrmStage.newLead);
}

/// Stadi aperti (in pipeline), nell'ordine di avanzamento.
const kOpenStages = [CrmStage.newLead, CrmStage.qualified, CrmStage.proposal];

class Opportunity {
  Opportunity({
    this.id,
    required this.companyId,
    this.title = '',
    this.customerId,
    this.customer,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.contactCompany,
    this.stage = CrmStage.newLead,
    this.expectedValue = 0,
    this.probability = 10,
    this.expectedClose,
    this.source,
    this.ownerId,
    this.notes,
  });

  final String? id;
  final String companyId;
  String title;
  String? customerId;
  Customer? customer;
  String? contactName;
  String? contactEmail;
  String? contactPhone;
  String? contactCompany;
  CrmStage stage;
  double expectedValue;
  int probability;
  DateTime? expectedClose;
  String? source;
  String? ownerId;
  String? notes;

  /// Valore ponderato sulla probabilità (per le previsioni di pipeline).
  double get weightedValue => (expectedValue * probability / 100);

  /// Nome di riferimento mostrato in lista (cliente o contatto/azienda lead).
  String get displayContact =>
      customer?.name ??
      contactCompany ??
      contactName ??
      contactEmail ??
      'Contatto non indicato';

  factory Opportunity.fromJson(Map<String, dynamic> j) {
    final cust = j['customers'];
    return Opportunity(
      id: j['id'] as String,
      companyId: j['company_id'] as String,
      title: (j['title'] as String?) ?? '',
      customerId: j['customer_id'] as String?,
      customer: cust is Map<String, dynamic> ? Customer.fromJson(cust) : null,
      contactName: j['contact_name'] as String?,
      contactEmail: j['contact_email'] as String?,
      contactPhone: j['contact_phone'] as String?,
      contactCompany: j['contact_company'] as String?,
      stage: CrmStage.fromDb(j['stage'] as String?),
      expectedValue: (j['expected_value'] as num?)?.toDouble() ?? 0,
      probability: (j['probability'] as num?)?.toInt() ?? 0,
      expectedClose: j['expected_close'] == null
          ? null
          : DateTime.parse(j['expected_close'] as String),
      source: j['source'] as String?,
      ownerId: j['owner_id'] as String?,
      notes: j['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'title': title.trim(),
        'customer_id': customerId,
        'contact_name': _n(contactName),
        'contact_email': _n(contactEmail),
        'contact_phone': _n(contactPhone),
        'contact_company': _n(contactCompany),
        'stage': stage.db,
        'expected_value': expectedValue,
        'probability': probability,
        'expected_close': expectedClose == null ? null : _d(expectedClose!),
        'source': _n(source),
        'owner_id': ownerId,
        'notes': _n(notes),
      };

  static String? _n(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
