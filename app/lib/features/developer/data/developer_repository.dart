// ============================================================
//  SMARTERP · developer_repository.dart
//  Licenze/pagamenti + aggregati per la Dashboard Sviluppatore.
//  Lo scope (tutte le org) è garantito dalla RLS per super_admin.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/app_bundle.dart';
import '../domain/license.dart';

/// Dati aggregati della dashboard.
class DashboardData {
  const DashboardData({
    required this.organizations,
    required this.totalPaid,
    required this.overdueLicenses,
    required this.activeLicenses,
    required this.bugBySeverity,
    required this.ticketsByStatus,
    required this.paidByCompany,
  });
  final int organizations;
  final double totalPaid;
  final int overdueLicenses;
  final int activeLicenses;
  final Map<String, int> bugBySeverity;
  final Map<String, int> ticketsByStatus;
  final Map<String, double> paidByCompany;
}

class DeveloperRepository {
  DeveloperRepository(this._client);
  final SupabaseClient _client;

  static const _licSelect =
      'id, company_id, name, status, price, period, start_date, renewal_date, '
      'notes, app_code, app_codes, companies ( name )';

  Future<List<License>> listLicenses() async {
    final rows = await _client
        .from('licenses')
        .select(_licSelect)
        .order('company_id');
    return rows.map(License.fromJson).toList();
  }

  Future<void> create(License l) async {
    await _client.from('licenses').insert(l.toJson());
  }

  Future<void> update(License l) async {
    await _client.from('licenses').update(l.toJson()).eq('id', l.id);
  }

  Future<void> delete(String id) async {
    await _client.from('licenses').delete().eq('id', id);
  }

  // ----- Bundle (pacchetti) -----
  Future<List<AppBundle>> listBundles() async {
    final rows = await _client
        .from('app_bundles')
        .select('id, name, description, app_codes, price, period, is_default')
        .order('name');
    return rows.map(AppBundle.fromJson).toList();
  }

  Future<void> createBundle(AppBundle b) async {
    await _client.from('app_bundles').insert(b.toJson());
  }

  Future<void> updateBundle(AppBundle b) async {
    await _client.from('app_bundles').update(b.toJson()).eq('id', b.id);
  }

  Future<void> deleteBundle(String id) async {
    await _client.from('app_bundles').delete().eq('id', id);
  }

  Future<void> addPayment(
      String licenseId, String companyId, double amount, DateTime paidAt,
      {String? note}) async {
    await _client.from('license_payments').insert({
      'license_id': licenseId,
      'company_id': companyId,
      'amount': amount,
      'paid_at': License.staticDate(paidAt),
      'note': note,
    });
  }

  Future<DashboardData> dashboard({int bugDays = 30}) async {
    final now = DateTime.now();

    final companies = await _client.from('companies').select('id');
    final licenses = await listLicenses();
    final payments =
        await _client.from('license_payments').select('company_id, amount');

    final paidByCompany = <String, double>{};
    var totalPaid = 0.0;
    for (final p in payments) {
      final cid = p['company_id'] as String;
      final amt = (p['amount'] as num?)?.toDouble() ?? 0;
      paidByCompany[cid] = (paidByCompany[cid] ?? 0) + amt;
      totalPaid += amt;
    }

    // Bug per gravità (ultimi N giorni).
    final since = now.toUtc().subtract(Duration(days: bugDays)).toIso8601String();
    final errs = await _client
        .from('error_logs')
        .select('severity')
        .gte('created_at', since);
    final bugBySeverity = <String, int>{};
    for (final e in errs) {
      final s = (e['severity'] as String?) ?? 'error';
      bugBySeverity[s] = (bugBySeverity[s] ?? 0) + 1;
    }

    // Ticket per stato.
    final tickets = await _client.from('tickets').select('status');
    final ticketsByStatus = <String, int>{};
    for (final t in tickets) {
      final s = (t['status'] as String?) ?? 'open';
      ticketsByStatus[s] = (ticketsByStatus[s] ?? 0) + 1;
    }

    return DashboardData(
      organizations: companies.length,
      totalPaid: totalPaid,
      overdueLicenses: licenses.where((l) => l.overdueAt(now)).length,
      activeLicenses: licenses.where((l) => l.status == 'active').length,
      bugBySeverity: bugBySeverity,
      ticketsByStatus: ticketsByStatus,
      paidByCompany: paidByCompany,
    );
  }
}

final developerRepositoryProvider = Provider<DeveloperRepository>((ref) {
  return DeveloperRepository(ref.watch(supabaseClientProvider));
});
