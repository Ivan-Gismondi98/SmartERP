// ============================================================
//  SMARTERP · developer_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_providers.dart';
import '../data/developer_repository.dart';
import '../domain/license.dart';

/// Elenco organizzazioni (id, name) per i selettori del developer.
final organizationsProvider =
    FutureProvider<List<({String id, String name})>>((ref) async {
  final rows = await ref
      .watch(supabaseClientProvider)
      .from('companies')
      .select('id, name')
      .order('name');
  return rows
      .map((r) => (id: r['id'] as String, name: (r['name'] as String?) ?? '—'))
      .toList();
});

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  return ref.watch(developerRepositoryProvider).dashboard();
});

final licensesListProvider = FutureProvider<List<License>>((ref) async {
  return ref.watch(developerRepositoryProvider).listLicenses();
});

/// Catalogo pacchetti = licenze predefinite (is_default, senza organizzazione).
final defaultPackagesProvider = FutureProvider<List<License>>((ref) async {
  final all = await ref.watch(licensesListProvider.future);
  return all.where((l) => l.isDefault).toList();
});
