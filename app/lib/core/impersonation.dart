// ============================================================
//  SMARTERP · impersonation.dart
//  Stato di "impersonate": lo sviluppatore (super_admin) adotta il
//  profilo effettivo di un altro utente per testarne l'esperienza.
//  La sessione reale resta quella dello sviluppatore.
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/profile/domain/profile.dart';

class ImpersonationState {
  const ImpersonationState({this.profile, this.token, this.since});
  final Profile? profile;
  final String? token; // JWT firmato del target: query RLS-scoped
  final DateTime? since;
  bool get active => profile != null;
}

class ImpersonationController extends Notifier<ImpersonationState> {
  @override
  ImpersonationState build() => const ImpersonationState();

  void start(Profile target, String token) => state =
      ImpersonationState(profile: target, token: token, since: DateTime.now());

  void stop() => state = const ImpersonationState();
}

final impersonationProvider =
    NotifierProvider<ImpersonationController, ImpersonationState>(
        ImpersonationController.new);
