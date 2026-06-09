// ============================================================
//  SMARTERP · accounting_repository.dart
//  Piano dei conti, centri di costo, registrazioni di prima nota
//  (partita doppia) + report (bilancio di verifica, mastrino).
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../domain/account.dart';
import '../domain/cost_center.dart';
import '../domain/journal_entry.dart';
import '../domain/reports.dart';

const _entrySelect =
    'id, company_id, entry_date, description, doc_ref, entry_number, '
    'numbering_year, numbering_seq';

const _lineSelect =
    'id, position, account_id, description, debit, credit, cost_center_id, '
    'accounting_accounts ( code, name ), accounting_cost_centers ( code )';

class AccountingRepository {
  AccountingRepository(this._client);
  final SupabaseClient _client;

  // ---------------- Piano dei conti ----------------
  Future<List<Account>> listAccounts(String companyId) async {
    final rows = await _client
        .from('accounting_accounts')
        .select('id, company_id, code, name, nature, is_active')
        .eq('company_id', companyId)
        .order('code');
    return rows.map(Account.fromJson).toList();
  }

  Future<void> createAccount(Account a) async {
    await _client.from('accounting_accounts').insert(a.toJson());
  }

  Future<void> updateAccount(Account a) async {
    await _client.from('accounting_accounts').update(a.toJson()).eq('id', a.id!);
  }

  Future<void> deleteAccount(String id) async {
    await _client.from('accounting_accounts').delete().eq('id', id);
  }

  // ---------------- Centri di costo ----------------
  Future<List<CostCenter>> listCostCenters(String companyId) async {
    final rows = await _client
        .from('accounting_cost_centers')
        .select('id, company_id, code, name, is_active')
        .eq('company_id', companyId)
        .order('code');
    return rows.map(CostCenter.fromJson).toList();
  }

  Future<void> createCostCenter(CostCenter c) async {
    await _client.from('accounting_cost_centers').insert(c.toJson());
  }

  Future<void> updateCostCenter(CostCenter c) async {
    await _client
        .from('accounting_cost_centers')
        .update(c.toJson())
        .eq('id', c.id!);
  }

  Future<void> deleteCostCenter(String id) async {
    await _client.from('accounting_cost_centers').delete().eq('id', id);
  }

  // ---------------- Registrazioni (prima nota) ----------------
  Future<List<JournalEntry>> listEntries(String companyId) async {
    final rows = await _client
        .from('accounting_entries')
        .select('$_entrySelect, accounting_lines ( $_lineSelect )')
        .eq('company_id', companyId)
        .order('entry_date', ascending: false)
        .order('numbering_seq', ascending: false, nullsFirst: true);
    return rows.map(JournalEntry.fromJson).toList();
  }

  Future<JournalEntry> getEntry(String id) async {
    final row = await _client
        .from('accounting_entries')
        .select('$_entrySelect, accounting_lines ( $_lineSelect )')
        .eq('id', id)
        .single();
    return JournalEntry.fromJson(row);
  }

  Future<String> createEntry(JournalEntry e) async {
    final header = await _client
        .from('accounting_entries')
        .insert(e.toJson())
        .select('id')
        .single();
    final id = header['id'] as String;
    await _replaceLines(id, e.lines);
    return id;
  }

  Future<void> updateEntry(JournalEntry e) async {
    await _client.from('accounting_entries').update(e.toJson()).eq('id', e.id!);
    await _replaceLines(e.id!, e.lines);
  }

  Future<void> _replaceLines(String entryId, List<JournalLine> lines) async {
    await _client.from('accounting_lines').delete().eq('entry_id', entryId);
    if (lines.isEmpty) return;
    final payload = <Map<String, dynamic>>[];
    for (var i = 0; i < lines.length; i++) {
      payload.add({
        ...lines[i].toJson(),
        'position': i,
        'entry_id': entryId,
      });
    }
    await _client.from('accounting_lines').insert(payload);
  }

  Future<void> deleteEntry(String id) async {
    await _client.from('accounting_entries').delete().eq('id', id);
  }

  /// Assegna il numero progressivo (per azienda+anno) alla registrazione.
  Future<String> assignNumber(String entryId) async {
    final n = await _client
        .rpc('assign_journal_number', params: {'p_entry_id': entryId});
    return n as String;
  }

  // ---------------- Report ----------------
  /// Bilancio di verifica: somma dare/avere per conto (azienda corrente,
  /// limitata da RLS). Ordinato per codice conto.
  Future<List<TrialBalanceRow>> trialBalance() async {
    final rows = await _client.from('accounting_lines').select(
        'debit, credit, accounting_accounts ( code, name, nature )');
    final byCode = <String, TrialBalanceRow>{};
    for (final r in rows) {
      final acc = r['accounting_accounts'] as Map?;
      if (acc == null) continue;
      final code = (acc['code'] as String?) ?? '—';
      final row = byCode.putIfAbsent(
        code,
        () => TrialBalanceRow(
          accountCode: code,
          accountName: (acc['name'] as String?) ?? '',
          nature: AccountNature.fromDb(acc['nature'] as String?),
        ),
      );
      row.debit += (r['debit'] as num?)?.toDouble() ?? 0;
      row.credit += (r['credit'] as num?)?.toDouble() ?? 0;
    }
    final list = byCode.values.toList()
      ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    return list;
  }

  /// Mastrino di un conto: movimenti ordinati per data.
  Future<List<LedgerMovement>> ledger(String accountId) async {
    final rows = await _client
        .from('accounting_lines')
        .select(
            'debit, credit, description, accounting_entries ( entry_date, entry_number, description )')
        .eq('account_id', accountId);
    final movements = <LedgerMovement>[];
    for (final r in rows) {
      final e = r['accounting_entries'] as Map?;
      if (e == null) continue;
      movements.add(LedgerMovement(
        date: DateTime.parse(e['entry_date'] as String),
        entryNumber: e['entry_number'] as String?,
        description: (r['description'] as String?) ??
            (e['description'] as String?),
        debit: (r['debit'] as num?)?.toDouble() ?? 0,
        credit: (r['credit'] as num?)?.toDouble() ?? 0,
      ));
    }
    movements.sort((a, b) => a.date.compareTo(b.date));
    return movements;
  }
}

final accountingRepositoryProvider = Provider<AccountingRepository>((ref) {
  return AccountingRepository(ref.watch(dataClientProvider));
});
