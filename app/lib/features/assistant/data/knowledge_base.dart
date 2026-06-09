// ============================================================
//  SMARTERP · knowledge_base.dart
//  Carica i documenti .md per applicativo (assets) e li trasforma in
//  "topic" interrogabili. Ogni topic può richiedere un permesso/ruolo.
// ============================================================
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Un argomento di aiuto estratto da un file .md.
class HelpTopic {
  HelpTopic({
    required this.app,
    required this.title,
    required this.body,
    this.permission,
    this.roles = const {},
    this.keywords = const [],
  });

  final String app; // codice app (invoices, products, general, ...)
  final String title;
  final String body;
  final String? permission; // permesso richiesto per l'operazione
  final Set<String> roles; // ruoli ammessi (vuoto = tutti)
  final List<String> keywords;

  /// Testo su cui calcolare la pertinenza alla domanda.
  late final String _haystack =
      ('$title ${keywords.join(' ')} $body').toLowerCase();

  int score(List<String> queryTokens) {
    var s = 0;
    final t = title.toLowerCase();
    final kw = keywords.join(' ').toLowerCase();
    for (final q in queryTokens) {
      if (q.length < 3) continue;
      if (t.contains(q)) s += 5;
      if (kw.contains(q)) s += 4;
      if (_haystack.contains(q)) s += 1;
    }
    return s;
  }
}

const _files = <String>[
  'general', 'invoices', 'customers', 'products', 'chat', 'studio',
  'crm', 'accounting', 'documents', 'production', 'purchases', 'maintenance',
  'projects'
];

/// Tutti i topic di aiuto (caricati una volta dagli assets).
final knowledgeBaseProvider = FutureProvider<List<HelpTopic>>((ref) async {
  final topics = <HelpTopic>[];
  for (final f in _files) {
    try {
      final raw = await rootBundle.loadString('assets/assistant/$f.md');
      topics.addAll(_parse(f, raw));
    } catch (_) {/* file mancante: ignora */}
  }
  return topics;
});

List<HelpTopic> _parse(String app, String raw) {
  final lines = raw.split('\n');
  final result = <HelpTopic>[];
  String? title;
  String? meta;
  final body = StringBuffer();

  void flush() {
    if (title != null) {
      final m = _parseMeta(meta);
      result.add(HelpTopic(
        app: (m['app'] ?? app).trim(),
        title: title!.trim(),
        body: body.toString().trim(),
        permission: m['perm']?.trim(),
        roles: (m['roles'] ?? '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet(),
        keywords: (m['keywords'] ?? '')
            .split(',')
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList(),
      ));
    }
    title = null;
    meta = null;
    body.clear();
  }

  for (final line in lines) {
    if (line.startsWith('## ')) {
      flush();
      title = line.substring(3);
    } else if (title != null &&
        line.trimLeft().startsWith('<!--') &&
        meta == null &&
        body.isEmpty) {
      meta = line.trim().replaceAll('<!--', '').replaceAll('-->', '').trim();
    } else if (title != null) {
      body.writeln(line);
    }
  }
  flush();
  return result;
}

Map<String, String> _parseMeta(String? meta) {
  final map = <String, String>{};
  if (meta == null) return map;
  for (final part in meta.split(';')) {
    final i = part.indexOf(':');
    if (i > 0) {
      map[part.substring(0, i).trim()] = part.substring(i + 1).trim();
    }
  }
  return map;
}
