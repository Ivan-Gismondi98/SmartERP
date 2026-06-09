// ============================================================
//  SMARTERP · assistant_controller.dart
//  Conversazione dell'Assistente IA (persistente per tutta la sessione,
//  sopravvive al cambio di pagina/app). Risponde dai documenti .md
//  filtrando per ruolo, permessi e licenze dell'utente.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/licensing.dart';
import '../../../core/permissions/permissions_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/profile.dart';
import '../data/knowledge_base.dart';

class AssistantMessage {
  const AssistantMessage(this.fromUser, this.text);
  final bool fromUser;
  final String text;
}

class AssistantState {
  const AssistantState({this.messages = const [], this.thinking = false});
  final List<AssistantMessage> messages;
  final bool thinking;

  AssistantState copy({List<AssistantMessage>? messages, bool? thinking}) =>
      AssistantState(
          messages: messages ?? this.messages,
          thinking: thinking ?? this.thinking);
}

String _roleDb(UserRole r) => switch (r) {
      UserRole.superAdmin => 'super_admin',
      UserRole.admin => 'admin',
      UserRole.employee => 'employee',
      UserRole.customer => 'customer',
    };

String appFromPath(String? path) {
  if (path == null) return 'general';
  if (path.startsWith('/invoices')) return 'invoices';
  // Vendite condivide la licenza/guida delle Fatture (app 'invoices').
  if (path.startsWith('/sales')) return 'invoices';
  if (path.startsWith('/customers')) return 'customers';
  if (path.startsWith('/products')) return 'products';
  if (path.startsWith('/chat')) return 'chat';
  if (path.startsWith('/studio')) return 'studio';
  if (path.startsWith('/crm')) return 'crm';
  if (path.startsWith('/accounting')) return 'accounting';
  if (path.startsWith('/documents')) return 'documents';
  if (path.startsWith('/production')) return 'production';
  // Acquisti include i Fornitori (licenza 'purchases').
  if (path.startsWith('/purchases')) return 'purchases';
  if (path.startsWith('/suppliers')) return 'purchases';
  if (path.startsWith('/maintenance')) return 'maintenance';
  if (path.startsWith('/projects')) return 'projects';
  return 'general';
}

class AssistantController extends StateNotifier<AssistantState> {
  AssistantController(this._ref) : super(const AssistantState());
  final Ref _ref;

  void reset() => state = const AssistantState();

  Future<void> ask(String query, {String? currentPath}) async {
    final q = query.trim();
    if (q.isEmpty || state.thinking) return;
    state = state.copy(
      messages: [...state.messages, AssistantMessage(true, q)],
      thinking: true,
    );
    final answer = await _answer(q, currentPath);
    state = state.copy(
      messages: [...state.messages, AssistantMessage(false, answer)],
      thinking: false,
    );
  }

  Future<String> _answer(String query, String? currentPath) async {
    final topics = await _ref.read(knowledgeBaseProvider.future);
    final profile = await _ref.read(currentProfileProvider.future);
    final perms = _ref.read(allowedPermissionsProvider).valueOrNull ?? const {};
    final licensed = _ref.read(licensedAppsProvider).valueOrNull ?? const {};
    final role = profile?.role ?? UserRole.customer;
    final roleStr = _roleDb(role);
    final isSuper = role == UserRole.superAdmin;
    final currentApp = appFromPath(currentPath);

    final tokens = query
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zà-ù0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3)
        .toList();
    if (tokens.isEmpty) {
      return 'Fammi una domanda su come usare l\'app (es. "come creo una fattura?").';
    }

    // Punteggia i topic; bonus per quelli dell'app in cui ti trovi.
    HelpTopic? best;
    var bestScore = 0;
    for (final t in topics) {
      var s = t.score(tokens);
      if (s == 0) continue;
      if (t.app == currentApp) s += 3;
      if (s > bestScore) {
        bestScore = s;
        best = t;
      }
    }

    if (best == null) {
      return 'Non ho trovato indicazioni precise su questo.\n'
          '• Se la domanda riguarda un altro modulo, aprilo e riformula: '
          'leggerò la guida di quella sezione.\n'
          '• Prova a essere più specifico (es. "come emetto una fattura?", '
          '"come carico il magazzino?").';
    }

    // App non licenziata per l'organizzazione.
    if (best.app != 'general' && !isSuper && !licensed.contains(best.app)) {
      return 'L\'argomento riguarda il modulo "${best.app}", che non risulta '
          'attivo per la tua organizzazione. Contatta l\'amministratore per '
          'attivare la licenza.';
    }

    // Operazione riservata: permesso mancante o ruolo non ammesso.
    final lacksPerm = best.permission != null &&
        !isSuper &&
        !perms.contains(best.permission);
    final lacksRole = best.roles.isNotEmpty &&
        !isSuper &&
        !best.roles.contains(roleStr);
    if (lacksPerm || lacksRole) {
      final who = best.roles.isNotEmpty
          ? best.roles.map(_roleLabel).join(' / ')
          : 'chi ha il permesso necessario';
      return '🔒 "${best.title}" è un\'operazione riservata a $who'
          '${best.permission != null ? ' (permesso "${best.permission}")' : ''}.\n'
          'Con il tuo ruolo (${_roleLabel(roleStr)}) non puoi eseguirla: '
          'chiedi al tuo amministratore di abilitarti o di procedere lui.';
    }

    final prefix = best.app != currentApp && best.app != 'general'
        ? '(dal modulo "${best.app}")\n\n'
        : '';
    return '$prefix**${best.title}**\n\n${best.body}';
  }

  String _roleLabel(String r) => switch (r) {
        'super_admin' => 'Sviluppatore',
        'admin' => 'Amministratore',
        'employee' => 'Dipendente',
        _ => 'Utente',
      };
}

/// Provider app-wide: NON autoDispose, così la conversazione persiste
/// quando si passa da un'app all'altra.
final assistantControllerProvider =
    StateNotifierProvider<AssistantController, AssistantState>((ref) {
  return AssistantController(ref);
});
