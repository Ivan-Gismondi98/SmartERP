// ============================================================
//  SMARTERP · accounting_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/accounting_repository.dart';
import '../domain/account.dart';
import '../domain/cost_center.dart';
import '../domain/journal_entry.dart';
import '../domain/reports.dart';

final accountsListProvider = FutureProvider<List<Account>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <Account>[];
  return ref.watch(accountingRepositoryProvider).listAccounts(companyId);
});

final costCentersListProvider = FutureProvider<List<CostCenter>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <CostCenter>[];
  return ref.watch(accountingRepositoryProvider).listCostCenters(companyId);
});

final journalEntriesProvider = FutureProvider<List<JournalEntry>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final companyId = profile?.companyId;
  if (companyId == null) return <JournalEntry>[];
  return ref.watch(accountingRepositoryProvider).listEntries(companyId);
});

final journalEntryDetailProvider =
    FutureProvider.family<JournalEntry, String>((ref, id) async {
  return ref.watch(accountingRepositoryProvider).getEntry(id);
});

final trialBalanceProvider =
    FutureProvider<List<TrialBalanceRow>>((ref) async {
  // Dipende dalle registrazioni: si aggiorna quando cambiano.
  ref.watch(journalEntriesProvider);
  return ref.watch(accountingRepositoryProvider).trialBalance();
});

final ledgerProvider =
    FutureProvider.family<List<LedgerMovement>, String>((ref, accountId) async {
  return ref.watch(accountingRepositoryProvider).ledger(accountId);
});
