// ============================================================
//  SMARTERP · document_template.dart — modello grafico documento.
//  La configurazione grafica è in `config` (jsonb).
// ============================================================
class DocumentTemplate {
  const DocumentTemplate({
    required this.id,
    required this.companyId,
    required this.name,
    this.docType = 'both',
    this.isDefault = false,
    this.config = const {},
  });

  final String id;
  final String companyId;
  final String name;
  final String docType; // invoice | quote | both
  final bool isDefault;
  final Map<String, dynamic> config;

  // ----- config tipizzata -----
  String get headerText => (config['header_text'] as String?) ?? '';
  String get footerText => (config['footer_text'] as String?) ?? '';
  bool get showLogo => (config['show_logo'] as bool?) ?? true;
  bool get showVatSummary => (config['show_vat_summary'] as bool?) ?? true;

  /// 'auto' (usa il flag per-prodotto), 'catalog' (tutte catalogo),
  /// 'compact' (tutte compatte).
  String get lineStyle => (config['line_style'] as String?) ?? 'auto';

  /// Override colore primario "#RRGGBB" (null = usa il branding azienda).
  String? get primaryHex {
    final v = config['primary_hex'];
    return (v is String && v.trim().isNotEmpty) ? v.trim() : null;
  }

  factory DocumentTemplate.fromJson(Map<String, dynamic> j) => DocumentTemplate(
        id: j['id'] as String,
        companyId: j['company_id'] as String,
        name: j['name'] as String,
        docType: (j['doc_type'] as String?) ?? 'both',
        isDefault: (j['is_default'] as bool?) ?? false,
        config: (j['config'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'doc_type': docType,
        'is_default': isDefault,
        'config': config,
      };

  DocumentTemplate copyWith({
    String? name,
    bool? isDefault,
    Map<String, dynamic>? config,
  }) =>
      DocumentTemplate(
        id: id,
        companyId: companyId,
        name: name ?? this.name,
        docType: docType,
        isDefault: isDefault ?? this.isDefault,
        config: config ?? this.config,
      );
}
