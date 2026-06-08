// ============================================================
//  SMARTERP · customer_form_page.dart — crea/modifica cliente.
//  Valida P.IVA, Codice Fiscale e Codice Destinatario SdI.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../data/customers_repository.dart';
import '../domain/customer.dart';

class CustomerFormPage extends ConsumerStatefulWidget {
  const CustomerFormPage({super.key, this.customer});

  final Customer? customer;

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _vat;
  late final TextEditingController _taxCode;
  late final TextEditingController _address;
  late final TextEditingController _zip;
  late final TextEditingController _city;
  late final TextEditingController _province;
  late final TextEditingController _sdi;
  late final TextEditingController _pec;
  late final TextEditingController _email;
  late final TextEditingController _phone;

  bool _isCompany = true;
  bool _saving = false;

  Customer? get _existing => widget.customer;

  @override
  void initState() {
    super.initState();
    final c = _existing;
    _isCompany = c?.isCompany ?? true;
    _name = TextEditingController(text: c?.name ?? '');
    _vat = TextEditingController(text: c?.vatNumber ?? '');
    _taxCode = TextEditingController(text: c?.taxCode ?? '');
    _address = TextEditingController(text: c?.address ?? '');
    _zip = TextEditingController(text: c?.zip ?? '');
    _city = TextEditingController(text: c?.city ?? '');
    _province = TextEditingController(text: c?.province ?? '');
    _sdi = TextEditingController(text: c?.sdiCode ?? '0000000');
    _pec = TextEditingController(text: c?.pec ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
  }

  @override
  void dispose() {
    for (final ctrl in [
      _name, _vat, _taxCode, _address, _zip, _city, _province, _sdi, _pec,
      _email, _phone
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = await ref.read(currentProfileProvider.future);
    final companyId = profile?.companyId;
    if (companyId == null) {
      _snack('Nessuna azienda associata al profilo.');
      return;
    }

    setState(() => _saving = true);
    final draft = Customer(
      id: _existing?.id ?? '',
      companyId: companyId,
      name: _name.text.trim(),
      isCompany: _isCompany,
      vatNumber: _vat.text,
      taxCode: _taxCode.text,
      address: _address.text,
      zip: _zip.text,
      city: _city.text,
      province: _province.text.toUpperCase(),
      sdiCode: _sdi.text.trim().toUpperCase(),
      pec: _pec.text,
      email: _email.text,
      phone: _phone.text,
    );

    try {
      final repo = ref.read(customersRepositoryProvider);
      if (_existing == null) {
        await repo.create(companyId, draft);
      } else {
        await repo.update(draft);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      _snack('Errore nel salvataggio: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'Nuovo cliente' : 'Modifica cliente'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Azienda'), icon: Icon(Icons.business)),
                ButtonSegment(value: false, label: Text('Privato'), icon: Icon(Icons.person)),
              ],
              selected: {_isCompany},
              onSelectionChanged: (s) => setState(() => _isCompany = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: _isCompany ? 'Denominazione *' : 'Nome e cognome *',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vat,
              decoration: const InputDecoration(
                labelText: 'Partita IVA',
                hintText: 'es. 09876543210',
              ),
              validator: (v) =>
                  FiscalValidators.validateVat(v, required: _isCompany),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _taxCode,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Codice Fiscale'),
              validator: (v) => FiscalValidators.validateTaxCode(v,
                  required: !_isCompany),
            ),
            const Divider(height: 32),
            const Text('Sede / Indirizzo'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Indirizzo'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _zip,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'CAP'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'Città'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _province,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 2,
                    decoration: const InputDecoration(
                        labelText: 'Prov.', counterText: ''),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('Fatturazione elettronica (SdI)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _sdi,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Codice Destinatario',
                hintText: '0000000 se si usa la PEC',
              ),
              validator: (v) => FiscalValidators.validateSdi(v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pec,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'PEC destinatario'),
            ),
            const Divider(height: 32),
            const Text('Contatti'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefono'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }
}
