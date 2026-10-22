// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/ff_builtin_enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart' hide RepeatMode;
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

/// Definições da conta: nome, utilizador e iniciais; alterar email e palavra-passe;
/// ativar a entrada com Face ID / impressão digital / Windows Hello neste aparelho.
class Studio59StaffSettings extends StatefulWidget {
  const Studio59StaffSettings({super.key, this.width, this.height});
  final double? width;
  final double? height;
  @override
  State<Studio59StaffSettings> createState() => _Studio59StaffSettingsState();
}

class _Studio59StaffSettingsState extends State<Studio59StaffSettings> {
  static const _api = 'https://studio59.wiredevelop.pt/api';
  static const _rose = Color(0xFFB77F84);
  static const _ink = Color(0xFF292624);
  static const _muted = Color(0xFF6D625F);
  static const _storage = FlutterSecureStorage();
  static const _roles = {
    'admin': 'Administrador',
    'photographer': 'Fotógrafo',
    'staff': 'Staff',
    'backoffice': 'Backoffice',
    'receptionist': 'Receção',
  };

  String _token = '';
  Map<String, dynamic> _user = {};
  bool _loading = true;
  String? _error;

  final _email = TextEditingController();
  bool _savingEmail = false;
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPasswords = false;
  bool _savingPassword = false;

  bool _bioSupported = false;
  bool _bioEnabled = false;
  String _bioName = 'biometria';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token'
      };

  void _snack(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _message(http.Response r, String fallback) {
    try {
      final b = jsonDecode(r.body);
      if (b is Map) {
        if (b['errors'] is Map && (b['errors'] as Map).isNotEmpty) {
          final first = (b['errors'] as Map).values.first;
          return first is List && first.isNotEmpty
              ? '${first.first}'
              : '$first';
        }
        if (b['message'] != null) return '${b['message']}';
      }
    } catch (_) {}
    return '$fallback (${r.statusCode}).';
  }

  /// Iniciais como o servidor as reconhece na «Equipa de trabalho»: 1.ª letra do primeiro e do último nome.
  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '—';
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _token = (await _storage.read(key: 'studio59_staff_token') ?? '').trim();
      final r = await http
          .get(Uri.parse('$_api/auth/me'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200)
        throw StateError(_message(r, 'Não foi possível carregar a conta'));
      final b = jsonDecode(r.body);
      final data = b is Map && b['user'] is Map
          ? b['user']
          : (b is Map && b['data'] is Map ? b['data'] : b);
      _user = Map<String, dynamic>.from(data as Map);
      _email.text = '${_user['email'] ?? ''}';
      try {
        final auth = LocalAuthentication();
        _bioSupported =
            await auth.isDeviceSupported() && await auth.canCheckBiometrics;
        final types = _bioSupported
            ? await auth.getAvailableBiometrics()
            : <BiometricType>[];
        _bioName = types.contains(BiometricType.face)
            ? 'Face ID'
            : (Theme.of(context).platform == TargetPlatform.windows
                ? 'Windows Hello'
                : 'impressão digital');
        _bioEnabled = (await _storage.read(key: 'studio59_bio_enabled')) == '1';
      } catch (_) {
        _bioSupported = false;
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e is StateError
              ? e.message.toString()
              : 'Sem ligação ao servidor.';
        });
      }
    }
  }

  Future<void> _saveEmail() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _snack('Indique um email válido.');
      return;
    }
    setState(() => _savingEmail = true);
    try {
      final r = await http
          .put(Uri.parse('$_api/auth/me'),
              headers: _headers,
              body: jsonEncode({
                'name': _user['name'],
                'username': _user['username'],
                'email': email
              }))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode < 200 || r.statusCode >= 300)
        throw StateError(_message(r, 'Não foi possível guardar'));
      _user['email'] = email;
      _snack('Email atualizado.');
    } catch (e) {
      _snack(
          e is StateError ? e.message.toString() : 'Sem ligação ao servidor.');
    } finally {
      if (mounted) setState(() => _savingEmail = false);
    }
  }

  Future<void> _savePassword() async {
    if (_current.text.isEmpty || _new.text.isEmpty) {
      _snack('Preencha a palavra-passe atual e a nova.');
      return;
    }
    if (_new.text.length < 8) {
      _snack('A nova palavra-passe tem de ter pelo menos 8 caracteres.');
      return;
    }
    if (_new.text != _confirm.text) {
      _snack('A confirmação não é igual à nova palavra-passe.');
      return;
    }
    setState(() => _savingPassword = true);
    try {
      final r = await http
          .post(Uri.parse('$_api/auth/change-password'),
              headers: _headers,
              body: jsonEncode({
                'current_password': _current.text,
                'password': _new.text,
                'password_confirmation': _confirm.text
              }))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode < 200 || r.statusCode >= 300)
        throw StateError(_message(r, 'Não foi possível alterar'));
      if (_bioEnabled)
        await _storage.write(key: 'studio59_bio_password', value: _new.text);
      _current.clear();
      _new.clear();
      _confirm.clear();
      _snack(
          'Palavra-passe alterada. As outras sessões abertas foram terminadas.');
    } catch (e) {
      _snack(
          e is StateError ? e.message.toString() : 'Sem ligação ao servidor.');
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _toggleBiometrics(bool on) async {
    if (!on) {
      await _storage.delete(key: 'studio59_bio_password');
      await _storage.delete(key: 'studio59_bio_login');
      await _storage.write(key: 'studio59_bio_enabled', value: '0');
      setState(() => _bioEnabled = false);
      _snack('Entrada com $_bioName desligada neste aparelho.');
      return;
    }
    // Pede a palavra-passe (é ela que fica guardada de forma segura no aparelho) e confirma-a no servidor.
    final controller = TextEditingController();
    var obscure = true;
    final password = await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, update) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: Text('Ativar $_bioName'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                        'Confirme a sua palavra-passe. Fica guardada só neste aparelho, protegida pelo sistema.'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      obscureText: obscure,
                      autofocus: true,
                      decoration: InputDecoration(
                          labelText: 'Palavra-passe',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                              onPressed: () => update(() => obscure = !obscure),
                              icon: Icon(obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined))),
                    ),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancelar')),
                    FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: _rose),
                        onPressed: () =>
                            Navigator.pop(dialogContext, controller.text),
                        child: const Text('Continuar')),
                  ],
                )));
    controller.dispose();
    if (password == null || password.isEmpty) return;
    final login = '${_user['username'] ?? ''}'.trim().isNotEmpty
        ? '${_user['username']}'
        : '${_user['email']}';
    try {
      final check = await http
          .post(Uri.parse('$_api/auth/login'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json'
              },
              body: jsonEncode({'login': login, 'password': password}))
          .timeout(const Duration(seconds: 20));
      if (check.statusCode != 200) {
        _snack(check.statusCode == 422
            ? 'Palavra-passe incorreta.'
            : _message(check, 'Não foi possível confirmar'));
        return;
      }
      // Termina a sessão extra criada só para confirmar a palavra-passe.
      final extra = '${(jsonDecode(check.body) as Map)['token'] ?? ''}';
      if (extra.isNotEmpty) {
        http.post(Uri.parse('$_api/auth/logout'), headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $extra'
        }).ignore();
      }
      final ok = await LocalAuthentication().authenticate(
          localizedReason: 'Confirme para ativar a entrada com $_bioName');
      if (!ok) return;
      await _storage.write(key: 'studio59_bio_login', value: login);
      await _storage.write(key: 'studio59_bio_password', value: password);
      await _storage.write(key: 'studio59_bio_enabled', value: '1');
      await _storage.write(key: 'studio59_bio_asked', value: '1');
      setState(() => _bioEnabled = true);
      _snack('Pronto: no login, use «Entrar com $_bioName».');
    } on PlatformException catch (e) {
      _snack('Não foi possível usar a biometria (${e.code}).');
    } catch (_) {
      _snack('Sem ligação ao servidor.');
    }
  }

  Widget _card(String title, IconData icon, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFECE7E3))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, color: _rose),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    color: _ink, fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ]),
      );

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 120,
              child: Text(label, style: const TextStyle(color: _muted))),
          Expanded(
              child: SelectableText(value.isEmpty ? '—' : value,
                  style: const TextStyle(
                      color: _ink, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _passwordField(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          obscureText: !_showPasswords,
          decoration: InputDecoration(
              labelText: label,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final name = '${_user['name'] ?? ''}';
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFFFAF9F7),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(children: [
            IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: _ink)),
            const Expanded(
                child: Text('Definições',
                    style: TextStyle(
                        color: _ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w700))),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _rose))
              : _error != null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!,
                          style: const TextStyle(color: Color(0xFF9B3D3D))),
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: _load,
                          child: const Text('Tentar novamente')),
                    ]))
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _card('A minha conta', Icons.badge_outlined, [
                                Row(children: [
                                  CircleAvatar(
                                      radius: 30,
                                      backgroundColor: const Color(0xFFF2E5E3),
                                      child: Text(_initials(name),
                                          style: const TextStyle(
                                              color: _rose,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800))),
                                  const SizedBox(width: 14),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(name,
                                            style: const TextStyle(
                                                color: _ink,
                                                fontSize: 19,
                                                fontWeight: FontWeight.w700)),
                                        Text(
                                            _roles['${_user['role']}'] ??
                                                '${_user['role'] ?? ''}',
                                            style:
                                                const TextStyle(color: _muted)),
                                      ])),
                                ]),
                                const SizedBox(height: 14),
                                _info('Nome', name),
                                _info(
                                    'Utilizador', '${_user['username'] ?? ''}'),
                                _info('Iniciais', _initials(name)),
                                const Text(
                                    'Na «Equipa de trabalho» das fichas, o seu utilizador ou as suas iniciais identificam-no.',
                                    style:
                                        TextStyle(color: _muted, fontSize: 12)),
                              ]),
                              _card('Email', Icons.mail_outline, [
                                TextField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                      labelText: 'Email',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12))),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton(
                                      style: FilledButton.styleFrom(
                                          backgroundColor: _rose),
                                      onPressed:
                                          _savingEmail ? null : _saveEmail,
                                      child: Text(_savingEmail
                                          ? 'A guardar…'
                                          : 'Guardar email')),
                                ),
                              ]),
                              _card('Palavra-passe', Icons.lock_outline, [
                                _passwordField(_current, 'Palavra-passe atual'),
                                _passwordField(_new,
                                    'Nova palavra-passe (mínimo 8 caracteres)'),
                                _passwordField(
                                    _confirm, 'Confirmar a nova palavra-passe'),
                                Row(children: [
                                  Checkbox(
                                      value: _showPasswords,
                                      activeColor: _rose,
                                      onChanged: (v) => setState(
                                          () => _showPasswords = v ?? false)),
                                  const Text('Mostrar palavras-passe'),
                                  const Spacer(),
                                  FilledButton(
                                      style: FilledButton.styleFrom(
                                          backgroundColor: _rose),
                                      onPressed: _savingPassword
                                          ? null
                                          : _savePassword,
                                      child: Text(_savingPassword
                                          ? 'A alterar…'
                                          : 'Alterar')),
                                ]),
                              ]),
                              _card('Entrada rápida', Icons.fingerprint, [
                                if (!_bioSupported)
                                  const Text(
                                      'Este aparelho não tem Face ID, impressão digital ou Windows Hello configurados.',
                                      style: TextStyle(color: _muted))
                                else
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    activeColor: _rose,
                                    value: _bioEnabled,
                                    onChanged: _toggleBiometrics,
                                    title: Text('Entrar com $_bioName'),
                                    subtitle: const Text(
                                        'No login, entra como quando desbloqueia o aparelho. Só vale para este aparelho.'),
                                  ),
                              ]),
                            ]),
                      ),
                    ),
        ),
      ]),
    );
  }
}
