// ============================================================
//  SMARTERP · error_logs_repository.dart — lettura registro errori.
//  Lo scope (tutte le aziende / solo la propria) è applicato dalla RLS.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/error_log.dart';

class ErrorLogsRepository {
  ErrorLogsRepository(this._client);
  final SupabaseClient _client;

  /// Errori degli ultimi [days] giorni, opzionalmente filtrati per gravità.
  Future<List<ErrorLog>> list({int days = 30, String? severity}) async {
    final since = DateTime.now()
        .toUtc()
        .subtract(Duration(days: days))
        .toIso8601String();
    var q = _client
        .from('error_logs')
        .select('id, company_id, severity, module, message, details, route, created_at')
        .gte('created_at', since);
    if (severity != null) q = q.eq('severity', severity);
    final rows = await q.order('created_at', ascending: false).limit(500);
    return rows.map(ErrorLog.fromJson).toList();
  }

  Future<void> delete(String id) async {
    await _client.from('error_logs').delete().eq('id', id);
  }
}

final errorLogsRepositoryProvider = Provider<ErrorLogsRepository>((ref) {
  return ErrorLogsRepository(ref.watch(supabaseClientProvider));
});
