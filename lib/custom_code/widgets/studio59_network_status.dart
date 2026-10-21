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

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

class Studio59NetworkStatus extends StatefulWidget {
  const Studio59NetworkStatus({super.key, this.width, this.height});
  final double? width;
  final double? height;
  @override
  State<Studio59NetworkStatus> createState() => _Studio59NetworkStatusState();
}

class _Studio59NetworkStatusState extends State<Studio59NetworkStatus> {
  static const _rose = Color(0xFFB77F84);
  Map<String, dynamic> _state = {};
  bool _checking = true;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    _check(false);
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  Future<void> _check(bool rescan) async {
    _retry?.cancel();
    if (mounted) setState(() => _checking = true);
    Map<String, dynamic> result;
    try {
      result = Map<String, dynamic>.from(jsonDecode(
              await studio59Offline('prepare', jsonEncode({'rescan': rescan})))
          as Map);
    } catch (_) {
      result = {'mode': 'offline'};
    }
    if (!mounted) return;
    setState(() {
      _state = result;
      _checking = false;
    });
    // Sem internet e sem sessão: continua a procurar para entrar automaticamente.
    if (result['mode'] == 'offline') {
      _retry = Timer(const Duration(seconds: 12), () => _check(false));
    }
  }

  Widget _box(List<Widget> children) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24)),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );

  Widget _link(String label, IconData icon, VoidCallback onTap,
          {bool primary = false}) =>
      primary
          ? FilledButton.icon(
              onPressed: onTap,
              style: FilledButton.styleFrom(backgroundColor: _rose),
              icon: Icon(icon, size: 18),
              label: Text(label))
          : TextButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18, color: Colors.white70),
              label:
                  Text(label, style: const TextStyle(color: Colors.white70)));

  @override
  Widget build(BuildContext context) {
    final mode = '${_state['mode'] ?? ''}';
    final desktop = _state['desktop'] == true;
    if (_checking && _state.isEmpty) {
      return const Padding(
          padding: EdgeInsets.all(8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white54)),
            SizedBox(width: 10),
            Text('A verificar a ligação…',
                style: TextStyle(color: Colors.white54)),
          ]));
    }
    if (mode == 'online') {
      if (!desktop)
        return Center(
            child: _link('Procurar sessão offline na rede', Icons.wifi_find,
                () => _check(true)));
      return Center(
          child: _link('Modo offline', Icons.wifi_tethering,
              () => context.pushNamed('Studio59OfflineHostPage')));
    }
    if (mode == 'host') {
      return _box([
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.wifi_tethering, color: Color(0xFF81C784), size: 18),
          SizedBox(width: 8),
          Text('Sessão offline ativa neste computador',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        Text('«${_state['name']}» · PIN ${_state['pin']} · ${_state['ip']}',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
          _link('Painel da sessão', Icons.dashboard_outlined,
              () => context.pushNamed('Studio59OfflineHostPage'),
              primary: true),
          _link('Gerir pedidos', Icons.receipt_long_outlined,
              () => context.pushNamed('TeamOperationsOnline')),
        ]),
      ]);
    }
    if (mode == 'client') {
      return _box([
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.wifi, color: Color(0xFF81C784), size: 18),
          SizedBox(width: 8),
          Text('Ligado à sessão offline',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        Text('«${_state['session_name'] ?? ''}» · ${_state['host'] ?? ''}',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center),
        const Text(
            'Introduza o PIN ou leia o QR da sessão para abrir o catálogo.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
            textAlign: TextAlign.center),
        _link('Procurar novamente', Icons.refresh, () => _check(true)),
      ]);
    }
    return _box([
      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off, color: Colors.white70, size: 18),
        SizedBox(width: 8),
        Flexible(
            child: Text('Sem internet e sem sessão offline nesta rede',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center)),
      ]),
      const SizedBox(height: 4),
      Text(
          _checking
              ? 'A procurar na rede…'
              : 'A procurar automaticamente de 12 em 12 segundos.',
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 6),
      Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
        if (desktop)
          _link('Criar sessão offline', Icons.wifi_tethering,
              () => context.pushNamed('Studio59OfflineHostPage'),
              primary: true),
        _link('Procurar agora', Icons.refresh, () => _check(true)),
      ]),
    ]);
  }
}
