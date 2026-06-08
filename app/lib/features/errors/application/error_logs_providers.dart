// ============================================================
//  SMARTERP · error_logs_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/error_logs_repository.dart';
import '../domain/error_log.dart';

/// Filtro corrente del registro errori.
class ErrorFilter {
  const ErrorFilter({this.days = 30, this.severity});
  final int days;
  final String? severity;

  ErrorFilter copyWith({int? days, String? severity, bool clearSeverity = false}) =>
      ErrorFilter(
        days: days ?? this.days,
        severity: clearSeverity ? null : (severity ?? this.severity),
      );
}

final errorFilterProvider =
    StateProvider<ErrorFilter>((ref) => const ErrorFilter());

final errorLogsProvider = FutureProvider<List<ErrorLog>>((ref) async {
  final f = ref.watch(errorFilterProvider);
  return ref
      .watch(errorLogsRepositoryProvider)
      .list(days: f.days, severity: f.severity);
});
