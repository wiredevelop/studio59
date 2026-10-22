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

import '/app_state.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

/// Login da equipa: utilizador/email e palavra-passe (com «ver senha») ou entrada biométrica
/// (Face ID / impressão digital / Windows Hello) quando ativada nas definições.
class Studio59StaffLogin extends StatefulWidget {
  const Studio59StaffLogin({super.key, this.width, this.height});
  final double? width;
  final double? height;
  @override
  State<Studio59StaffLogin> createState() => _Studio59StaffLoginState();
}

class _Studio59StaffLoginState extends State<Studio59StaffLogin> {
  static const _rose = Color(0xFFB77F84);
  static const _ink = Color(0xFF292624);
  static const _muted = Color(0xFF6D625F);
  static const _line = Color(0xFFE5DDDA);
  static const _storage = FlutterSecureStorage();

  final _login = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _busy = false;
  bool _checking = true;
  bool _bioEnabled = false;
  String _bioLabel = 'Entrar com biometria';
  IconData _bioIcon = Icons.fingerprint;
  String? _error;

  bool get _offline => FFAppState().offlineApiBase.isNotEmpty;
  String get _base => _offline
      ? FFAppState().offlineApiBase
      : 'https://studio59.wiredevelop.pt/api';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Sessão guardada válida: segue logo para o painel.
  Future<void> _restore() async {
    try {
      final token =
          (await _storage.read(key: 'studio59_staff_token') ?? '').trim();
      if (token.isNotEmpty) {
        final response = await http.get(Uri.parse('$_base/auth/me'), headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token'
        }).timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          if (mounted) context.goNamed('Studio59DashboardOnline');
          return;
        }
        if (response.statusCode == 401)
          await _storage.delete(key: 'studio59_staff_token');
      }
      _login.text = await _storage.read(key: 'studio59_last_login') ?? '';
      await _loadBiometrics();
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _loadBiometrics() async {
    if (_offline) return;
    try {
      final enabled = (await _storage.read(key: 'studio59_bio_enabled')) == '1';
      if (!enabled) return;
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) return;
      final types = await auth.getAvailableBiometrics();
      final face = types.contains(BiometricType.face);
      setState(() {
        _bioEnabled = true;
        _bioLabel = face
            ? 'Entrar com Face ID'
            : (Theme.of(context).platform == TargetPlatform.windows
                ? 'Entrar com Windows Hello'
                : 'Entrar com impressão digital');
        _bioIcon = face ? Icons.face_outlined : Icons.fingerprint;
      });
    } catch (_) {}
  }

  Future<void> _submit(
      {String? login, String? password, bool biometric = false}) async {
    final user = (login ?? _login.text).trim();
    final pass = password ?? _password.text;
    if (user.isEmpty || pass.isEmpty) {
      setState(
          () => _error = 'Indique o utilizador (ou email) e a palavra-passe.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await http
          .post(Uri.parse('$_base/auth/login'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json'
              },
              body: jsonEncode({'login': user, 'password': pass}))
          .timeout(const Duration(seconds: 20));
      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (_) {}
      if (response.statusCode == 200 &&
          body is Map &&
          '${body['token'] ?? ''}'.isNotEmpty) {
        await _storage.write(
            key: 'studio59_staff_token', value: '${body['token']}');
        if (!_offline)
          await _storage.write(key: 'studio59_last_login', value: user);
        if (!mounted) return;
        if (!biometric && !_offline) await _offerBiometrics(user, pass);
        if (mounted) context.goNamed('Studio59DashboardOnline');
        return;
      }
      String message;
      if (response.statusCode == 422) {
        message = 'Utilizador ou palavra-passe incorretos.';
        if (biometric) {
          // A palavra-passe mudou noutro sítio: desliga a entrada biométrica neste aparelho.
          await _storage.delete(key: 'studio59_bio_password');
          await _storage.write(key: 'studio59_bio_enabled', value: '0');
          _bioEnabled = false;
          message =
              'A palavra-passe foi alterada. Entre com a nova palavra-passe e volte a ativar a biometria nas definições.';
        }
      } else if (response.statusCode == 403) {
        message = body is Map && body['message'] != null
            ? '${body['message']}'
            : 'Sem acesso.';
      } else if (response.statusCode == 429) {
        message = 'Demasiadas tentativas. Aguarde um pouco e tente de novo.';
      } else {
        message = 'Não foi possível entrar (${response.statusCode}).';
      }
      setState(() {
        _busy = false;
        _error = message;
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = _offline
            ? 'Sem ligação ao computador da sessão offline.'
            : 'Sem ligação ao servidor. Verifique a internet.';
      });
    }
  }

  Future<void> _biometricLogin() async {
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: 'Confirme a sua identidade para entrar no Studio 59',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (!ok) return;
      final login = await _storage.read(key: 'studio59_bio_login');
      final password = await _storage.read(key: 'studio59_bio_password');
      if (login == null || password == null) {
        setState(() => _error =
            'Entrada biométrica não configurada. Entre com a palavra-passe.');
        return;
      }
      _login.text = login;
      await _submit(login: login, password: password, biometric: true);
    } on PlatformException catch (e) {
      setState(
          () => _error = 'Biometria indisponível neste aparelho (${e.code}).');
    } catch (_) {
      setState(() => _error = 'Biometria indisponível neste aparelho.');
    }
  }

  /// Depois do primeiro login com palavra-passe, propõe ativar a biometria neste aparelho.
  Future<void> _offerBiometrics(String login, String password) async {
    try {
      if ((await _storage.read(key: 'studio59_bio_asked')) == '1') return;
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported() || !await auth.canCheckBiometrics)
        return;
      await _storage.write(key: 'studio59_bio_asked', value: '1');
      if (!mounted) return;
      final yes = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('Entrar mais depressa?'),
                content: const Text(
                    'Pode entrar com Face ID, impressão digital ou Windows Hello, como quando desbloqueia o aparelho. Pode mudar isto nas definições.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Agora não')),
                  FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _rose),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Ativar')),
                ],
              ));
      if (yes != true) return;
      final ok = await auth.authenticate(
          localizedReason: 'Confirme para ativar a entrada biométrica');
      if (!ok) return;
      await _storage.write(key: 'studio59_bio_login', value: login);
      await _storage.write(key: 'studio59_bio_password', value: password);
      await _storage.write(key: 'studio59_bio_enabled', value: '1');
    } catch (_) {}
  }

  InputDecoration _deco(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFFAF9F7),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _rose, width: 1.6)),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFFFAF9F7),
      child: SafeArea(
        child: _checking
            ? const Center(child: CircularProgressIndicator(color: _rose))
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AutofillGroup(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                    onPressed: () =>
                                        context.goNamed('WelcomeScreen'),
                                    icon: const Icon(Icons.arrow_back,
                                        color: _muted),
                                    label: const Text('Voltar ao início',
                                        style: TextStyle(color: _muted)))),
                            const SizedBox(height: 8),
                            Center(
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Image.asset(
                                        'assets/images/studio_59_logo.jpeg',
                                        width: 120,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                                Icons.camera_alt_outlined,
                                                size: 64,
                                                color: _rose)))),
                            const SizedBox(height: 18),
                            const Text('Área da equipa',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: _ink,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(
                                _offline
                                    ? 'Sessão offline · entre com o utilizador definido na sessão'
                                    : 'Entre com o seu utilizador ou email',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: _muted)),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                      color: const Color(0xFFECE7E3)),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Color(0x0F000000),
                                        blurRadius: 18,
                                        offset: Offset(0, 6))
                                  ]),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextField(
                                      controller: _login,
                                      enabled: !_busy,
                                      autofillHints: const [
                                        AutofillHints.username,
                                        AutofillHints.email
                                      ],
                                      keyboardType: TextInputType.emailAddress,
                                      autocorrect: false,
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) =>
                                          _passwordFocus.requestFocus(),
                                      onChanged: (_) {
                                        if (_error != null)
                                          setState(() => _error = null);
                                      },
                                      decoration: _deco('Utilizador ou email',
                                          Icons.person_outline),
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: _password,
                                      focusNode: _passwordFocus,
                                      enabled: !_busy,
                                      obscureText: _obscure,
                                      autofillHints: const [
                                        AutofillHints.password
                                      ],
                                      textInputAction: TextInputAction.go,
                                      onSubmitted: (_) => _submit(),
                                      onChanged: (_) {
                                        if (_error != null)
                                          setState(() => _error = null);
                                      },
                                      decoration: _deco(
                                          'Palavra-passe', Icons.lock_outline,
                                          suffix: IconButton(
                                              tooltip: _obscure
                                                  ? 'Mostrar palavra-passe'
                                                  : 'Esconder palavra-passe',
                                              onPressed: () => setState(
                                                  () => _obscure = !_obscure),
                                              icon: Icon(
                                                  _obscure
                                                      ? Icons
                                                          .visibility_outlined
                                                      : Icons
                                                          .visibility_off_outlined,
                                                  color: _muted))),
                                    ),
                                    if (_error != null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 14),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFFBEAEA),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Row(children: [
                                          const Icon(Icons.error_outline,
                                              color: Color(0xFF9B3D3D),
                                              size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                              child: Text(_error!,
                                                  style: const TextStyle(
                                                      color:
                                                          Color(0xFF9B3D3D)))),
                                        ]),
                                      ),
                                    const SizedBox(height: 18),
                                    FilledButton(
                                      onPressed: _busy ? null : () => _submit(),
                                      style: FilledButton.styleFrom(
                                          backgroundColor: _rose,
                                          padding: const EdgeInsets.all(18),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14))),
                                      child: _busy
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2.4,
                                                  color: Colors.white))
                                          : const Text('Entrar',
                                              style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w700)),
                                    ),
                                    if (_bioEnabled && !_offline) ...[
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed:
                                            _busy ? null : _biometricLogin,
                                        style: OutlinedButton.styleFrom(
                                            foregroundColor: _rose,
                                            side:
                                                const BorderSide(color: _rose),
                                            padding: const EdgeInsets.all(16),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14))),
                                        icon: Icon(_bioIcon),
                                        label: Text(_bioLabel,
                                            style:
                                                const TextStyle(fontSize: 16)),
                                      ),
                                    ],
                                  ]),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                                'Esqueceu-se da palavra-passe? Peça ao administrador para a redefinir.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _muted, fontSize: 13)),
                          ]),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
