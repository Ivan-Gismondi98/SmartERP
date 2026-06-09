// ============================================================
//  SMARTERP · documents_repository.dart
//  Upload su Storage (bucket 'documents') + CRUD metadati.
// ============================================================
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/document_file.dart';

class _Uploaded {
  const _Uploaded(this.path, this.url);
  final String path;
  final String url;
}

class DocumentsRepository {
  DocumentsRepository(this._client);
  final SupabaseClient _client;

  static const _bucket = 'documents';

  Future<List<DocumentFile>> list(String companyId) async {
    final rows = await _client
        .from('documents')
        .select(
            'id, company_id, title, category, description, file_name, file_path, '
            'file_url, mime_type, size_bytes, uploaded_by, created_at')
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
    return rows.map(DocumentFile.fromJson).toList();
  }

  /// Carica il file e crea il record metadati. Ritorna l'id creato.
  Future<String> upload({
    required String companyId,
    required String title,
    required String category,
    String? description,
    required List<int> bytes,
    required String fileName,
    String? mimeType,
    String? uploadedBy,
    required int stamp,
  }) async {
    final up = await _putFile(companyId, bytes, fileName, stamp);
    final doc = DocumentFile(
      companyId: companyId,
      title: title.trim().isEmpty ? fileName : title,
      category: category,
      description: description,
      fileName: fileName,
      filePath: up.path,
      fileUrl: up.url,
      mimeType: mimeType,
      sizeBytes: bytes.length,
      uploadedBy: uploadedBy,
    );
    final row =
        await _client.from('documents').insert(doc.toJson()).select('id').single();
    return row['id'] as String;
  }

  Future<_Uploaded> _putFile(
      String companyId, List<int> bytes, String fileName, int stamp) async {
    final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '$companyId/${stamp}_$safe';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true),
        );
    final url = _client.storage.from(_bucket).getPublicUrl(path);
    return _Uploaded(path, url);
  }

  /// Aggiorna i soli metadati (titolo/categoria/descrizione).
  Future<void> updateMeta(DocumentFile doc) async {
    await _client.from('documents').update({
      'title': doc.title.trim(),
      'category': doc.category.trim().isEmpty ? 'Generale' : doc.category.trim(),
      'description': (doc.description == null || doc.description!.trim().isEmpty)
          ? null
          : doc.description!.trim(),
    }).eq('id', doc.id!);
  }

  /// Elimina il record e il file su Storage (best-effort).
  Future<void> delete(DocumentFile doc) async {
    await _client.from('documents').delete().eq('id', doc.id!);
    if (doc.filePath.isNotEmpty) {
      try {
        await _client.storage.from(_bucket).remove([doc.filePath]);
      } catch (_) {
        // Il record è già rimosso; un eventuale file orfano è ininfluente.
      }
    }
  }
}

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return DocumentsRepository(ref.watch(dataClientProvider));
});
