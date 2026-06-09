// ============================================================
//  SMARTERP · accounting_import_export.dart — Import/Export PRIMA NOTA a
//  livello di RIGA. Righe con lo stesso "Documento" = una registrazione.
//  Import con risoluzione conto (per codice, creato se assente) e centro di
//  costo (per codice). Solo le registrazioni QUADRATE (Dare = Avere) vengono
//  importate. Colonne import/export coincidenti.
// ============================================================
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/reporting/report_spec.dart';
import '../../profile/application/profile_providers.dart';
import '../data/accounting_repository.dart';
import '../domain/account.dart';
import '../domain/cost_center.dart';
import '../domain/journal_entry.dart';

class JournalLineRow {
  JournalLineRow({
    required this.docRef,
    required this.date,
    required this.description,
    required this.ref,
    required this.accountCode,
    required this.accountName,
    required this.debit,
    required this.credit,
    required this.costCenter,
  });

  final String docRef, date, description, ref, accountCode, accountName,
      debit, credit, costCenter;
}

final _df = DateFormat('dd/MM/yyyy');

DateTime? _parseDate(String? s) {
  final v = (s ?? '').trim();
  if (v.isEmpty) return null;
  try {
    return _df.parseStrict(v);
  } catch (_) {
    return DateTime.tryParse(v);
  }
}

final accountingLinesSpec = ReportSpec<JournalLineRow>(
  title: 'Prima nota (righe)',
  fileBase: 'prima_nota_righe',
  columns: [
    ReportColumn('Documento', (r) => r.docRef),
    ReportColumn('Data', (r) => r.date),
    ReportColumn('Causale', (r) => r.description),
    ReportColumn('Riferimento', (r) => r.ref),
    ReportColumn('Conto', (r) => r.accountCode),
    ReportColumn('Conto nome', (r) => r.accountName),
    ReportColumn('Dare', (r) => r.debit),
    ReportColumn('Avere', (r) => r.credit),
    ReportColumn('Centro di costo', (r) => r.costCenter),
  ],
  load: (ref) async {
    final profile = await ref.read(currentProfileProvider.future);
    final cid = profile?.companyId;
    if (cid == null) return <JournalLineRow>[];
    final entries = await ref.read(accountingRepositoryProvider).listEntries(cid);
    final out = <JournalLineRow>[];
    for (final e in entries) {
      if (e.lines.isEmpty) continue;
      for (final l in e.lines) {
        out.add(JournalLineRow(
          docRef: e.displayNumber,
          date: Fmt.date(e.entryDate),
          description: e.description,
          ref: e.docRef ?? '',
          accountCode: l.accountCode ?? '',
          accountName: l.accountName ?? '',
          debit: l.debit == 0 ? '' : Fmt.amount(l.debit),
          credit: l.credit == 0 ? '' : Fmt.amount(l.credit),
          costCenter: l.costCenterCode ?? '',
        ));
      }
    }
    return out;
  },
  importRows: (ref, rows) async {
    final profile = await ref.read(currentProfileProvider.future);
    final cid = profile?.companyId;
    if (cid == null) throw 'Nessuna azienda associata';
    final repo = ref.read(accountingRepositoryProvider);

    // Raggruppa per "Documento".
    final groups = <String, List<Map<String, String>>>{};
    var synthetic = 0;
    for (final m in rows) {
      final key = (m['Documento'] ?? '').trim();
      final gk = key.isEmpty ? '__row${synthetic++}' : key;
      (groups[gk] ??= []).add(m);
    }

    // 1) Crea i conti e i centri di costo mancanti (una volta sola).
    var accounts = await repo.listAccounts(cid);
    final accByCode = {for (final a in accounts) a.code.trim().toLowerCase(): a};
    final neededAccounts = <String, String>{}; // code -> name
    final neededCenters = <String>{};
    for (final m in rows) {
      final code = (m['Conto'] ?? '').trim();
      if (code.isNotEmpty && !accByCode.containsKey(code.toLowerCase())) {
        neededAccounts[code] = (m['Conto nome'] ?? '').trim();
      }
      final cc = (m['Centro di costo'] ?? '').trim();
      if (cc.isNotEmpty) neededCenters.add(cc);
    }
    for (final e in neededAccounts.entries) {
      await repo.createAccount(Account(
        companyId: cid,
        code: e.key,
        name: e.value.isEmpty ? e.key : e.value,
        nature: AccountNature.costo,
      ));
    }
    if (neededAccounts.isNotEmpty) {
      accounts = await repo.listAccounts(cid);
    }
    final accIdByCode = {
      for (final a in accounts) a.code.trim().toLowerCase(): a.id!
    };

    var centers = await repo.listCostCenters(cid);
    final ccByCode = {for (final c in centers) c.code.trim().toLowerCase(): c};
    final toCreateCc =
        neededCenters.where((c) => !ccByCode.containsKey(c.toLowerCase()));
    for (final code in toCreateCc) {
      await repo.createCostCenter(
          CostCenter(companyId: cid, code: code, name: code));
    }
    if (toCreateCc.isNotEmpty) {
      centers = await repo.listCostCenters(cid);
    }
    final ccIdByCode = {
      for (final c in centers) c.code.trim().toLowerCase(): c.id!
    };

    // 2) Crea le registrazioni quadrate.
    var count = 0;
    for (final entry in groups.entries) {
      final lines = entry.value;
      final first = lines.first;
      final jl = <JournalLine>[];
      for (final m in lines) {
        final code = (m['Conto'] ?? '').trim().toLowerCase();
        final accId = accIdByCode[code];
        if (accId == null) continue;
        final ccCode = (m['Centro di costo'] ?? '').trim().toLowerCase();
        jl.add(JournalLine(
          accountId: accId,
          debit: Fmt.parseAmount(m['Dare']) ?? 0,
          credit: Fmt.parseAmount(m['Avere']) ?? 0,
          costCenterId: ccCode.isEmpty ? null : ccIdByCode[ccCode],
        ));
      }
      final je = JournalEntry(
        companyId: cid,
        entryDate: _parseDate(first['Data']) ?? DateTime.now(),
        description: (first['Causale'] ?? '').trim(),
        docRef: (first['Riferimento'] ?? '').trim().isEmpty
            ? null
            : first['Riferimento']!.trim(),
        lines: jl,
      );
      // Solo registrazioni quadrate (Dare = Avere, totale > 0).
      if (!je.isBalanced) continue;
      final id = await repo.createEntry(je);
      await repo.assignNumber(id);
      count++;
    }
    return count;
  },
);
