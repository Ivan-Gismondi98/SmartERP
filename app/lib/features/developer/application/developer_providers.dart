// ============================================================
//  SMARTERP · developer_providers.dart
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_providers.dart';
import '../data/developer_repository.dart';
import '../domain/app_bundle.dart';
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

final bundlesListProvider = FutureProvider<List<AppBundle>>((ref) async {
  return ref.watch(developerRepositoryProvider).listBundles();
});
