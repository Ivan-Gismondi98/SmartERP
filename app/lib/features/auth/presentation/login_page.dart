// ============================================================
//  SMARTERP · login_page.dart — accesso. La registrazione è riservata
//  al super_admin (sviluppatore): qui si può solo richiedere un account.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/smart_erp_logo.dart';
import '../../developer/data/account_requests_repository.dart';
import '../application/auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .signIn(_emailCtrl.text, _passwordCtrl.text);
    // In caso di login riuscito, il redirect del router porta alla home.
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final theme = Theme.of(context);

    ref.listen(authControllerProvider, (prev, next) {
      next.whenOrNull(
        error: (err, _) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(_friendlyError(err)),
                backgroundColor: theme.colorScheme.error,
              ),
            );
        },
      );
    });

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: SmartErpLogo(size: 64)),
                  const SizedBox(height: 16),
                  Text('Accedi al gestionale',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Inserisci l\'email';
                      }
                      if (!v.contains('@')) return 'Email non valida';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => isLoading ? null : _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Inserisci la password' : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: isLoading ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text('Accedi'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed:
                        isLoading ? null : () => _requestAccount(context),
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Richiedi un account allo sviluppatore'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestAccount(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const _AccountRequestDialog(),
    );
  }

  String _friendlyError(Object err) {
    final msg = err.toString();
    if (msg.contains('Invalid login credentials')) {
      return 'Credenziali non valide.';
    }
    return 'Errore: $msg';
  }
}

class _AccountRequestDialog extends ConsumerStatefulWidget {
  const _AccountRequestDialog();

  @override
  ConsumerState<_AccountRequestDialog> createState() =>
      _AccountRequestDialogState();
}

class _AccountRequestDialogState
    extends ConsumerState<_AccountRequestDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _org = TextEditingController();
  final _msg = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _org, _msg]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Inserisci un\'email valida');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountRequestsRepositoryProvider).submit(
            email: _email.text,
            name: _name.text,
            organization: _org.text,
            message: _msg.text,
          );
      setState(() {
        _done = true;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return AlertDialog(
        title: const Text('Richiesta inviata'),
        content: const Text(
            'La tua richiesta è stata inviata allo sviluppatore. '
            'Verrai contattato all\'email indicata quando l\'account sarà creato.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi')),
        ],
      );
    }
    return AlertDialog(
      title: const Text('Richiedi un account'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'La registrazione è gestita dallo sviluppatore. Compila i dati e '
                'indica per quale organizzazione richiedi l\'utenza.'),
            const SizedBox(height: 12),
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nome e cognome')),
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email *')),
            TextField(
                controller: _org,
                decoration: const InputDecoration(
                    labelText: 'Organizzazione (per quale azienda)')),
            TextField(
                controller: _msg,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Messaggio (ruolo desiderato, note…)')),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Annulla')),
        FilledButton(
          onPressed: _busy ? null : _send,
          child: _busy
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Invia richiesta'),
        ),
      ],
    );
  }
}
