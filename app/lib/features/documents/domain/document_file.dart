// ============================================================
//  SMARTERP · document_file.dart — documento interno (metadati).
//  Il file è archiviato su Supabase Storage; qui ci sono i metadati.
// ============================================================

/// Categorie predefinite (l'utente può comunque scriverne di proprie).
const kDocCategories = <String>[
  'Generale',
  'Contratti',
  'Amministrazione',
  'Risorse umane',
  'Tecnico',
  'Commerciale',
];

class DocumentFile {
  DocumentFile({
    this.id,
    required this.companyId,
    this.title = '',
    this.category = 'Generale',
    this.description,
    this.fileName = '',
    this.filePath = '',
    this.fileUrl = '',
    this.mimeType,
    this.sizeBytes = 0,
    this.uploadedBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String? id;
  final String companyId;
  String title;
  String category;
  String? description;
  String fileName;
  String filePath;
  String fileUrl;
  String? mimeType;
  int sizeBytes;
  String? uploadedBy;
  final DateTime createdAt;

  /// Estensione in minuscolo (per scegliere l'icona).
  String get extension {
    final i = fileName.lastIndexOf('.');
    return i >= 0 ? fileName.substring(i + 1).toLowerCase() : '';
  }

  /// Dimensione leggibile (es. "1,2 MB").
  String get sizeLabel {
    if (sizeBytes <= 0) return '—';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = sizeBytes.toDouble();
    var u = 0;
    while (size >= 1024 && u < units.length - 1) {
      size /= 1024;
      u++;
    }
    final s = u == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
    return '${s.replaceAll('.', ',')} ${units[u]}';
  }

  factory DocumentFile.fromJson(Map<String, dynamic> j) => DocumentFile(
        id: j['id'] as String,
        companyId: j['company_id'] as String,
        title: (j['title'] as String?) ?? '',
        category: (j['category'] as String?) ?? 'Generale',
        description: j['description'] as String?,
        fileName: (j['file_name'] as String?) ?? '',
        filePath: (j['file_path'] as String?) ?? '',
        fileUrl: (j['file_url'] as String?) ?? '',
        mimeType: j['mime_type'] as String?,
        sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
        uploadedBy: j['uploaded_by'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  /// Per insert/update dei metadati (company_id/uploaded_by gestiti a parte).
  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'title': title.trim(),
        'category': category.trim().isEmpty ? 'Generale' : category.trim(),
        'description':
            (description == null || description!.trim().isEmpty) ? null : description!.trim(),
        'file_name': fileName,
        'file_path': filePath,
        'file_url': fileUrl,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'uploaded_by': uploadedBy,
      };
}
