// ============================================================
//  SMARTERP · reports.dart — strutture per bilancio di verifica e mastrino.
// ============================================================
import '../../../core/format.dart';
import 'account.dart';

/// Riga del bilancio di verifica (totali dare/avere per conto).
class TrialBalanceRow {
  TrialBalanceRow({
    required this.accountCode,
    required this.accountName,
    required this.nature,
    this.debit = 0,
    this.credit = 0,
  });

  final String accountCode;
  final String accountName;
  final AccountNature nature;
  double debit;
  double credit;

  double get balance => round2(debit - credit);
}

/// Movimento del mastrino (estratto conto di un singolo conto).
class LedgerMovement {
  LedgerMovement({
    required this.date,
    this.entryNumber,
    this.description,
    this.debit = 0,
    this.credit = 0,
  });

  final DateTime date;
  final String? entryNumber;
  final String? description;
  final double debit;
  final double credit;
}
