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
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class Studio59OfflineSession extends StatefulWidget {
  const Studio59OfflineSession({super.key, this.width, this.height});
  final double? width;
  final double? height;
  @override
  State<Studio59OfflineSession> createState() => _Studio59OfflineSessionState();
}

class _Studio59OfflineSessionState extends State<Studio59OfflineSession> {
  static const _rose = Color(0xFFB77F84);
  static const _roseSoft = Color(0xFFF2E5E3);
  static const _ink = Color(0xFF292624);
  static const _muted = Color(0xFF6D625F);
  static const _line = Color(0xFFECE7E3);
  final _name = TextEditingController();
  final _price = TextEditingController(text: '5,00');
  final _pin =
      TextEditingController(text: (1000 + Random().nextInt(9000)).toString());
  final _user = TextEditingController(text: 'equipa');
  final _password = TextEditingController();
  DateTime _date = DateTime.now();
  String? _folder;
  Map<String, dynamic>? _inspect;
  Map<String, dynamic> _status = {};
  bool _loading = true;
  bool _busy = false;
  bool _resume = false;
  bool _showPassword = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_status['running'] == true) _refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_name, _price, _pin, _user, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Map<String, dynamic>> _call(String command,
          [Map<String, dynamic>? args]) async =>
      Map<String, dynamic>.from(
          jsonDecode(await studio59Offline(command, jsonEncode(args ?? {})))
              as Map);

  Future<void> _refresh() async {
    final status = await _call('status');
    if (mounted)
      setState(() {
        _status = status;
        _loading = false;
      });
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform
        .getDirectoryPath(dialogTitle: 'Selecione a pasta provas');
    if (path == null) return;
    setState(() {
      _folder = path;
      _inspect = null;
      _error = null;
      _resume = false;
    });
    final result = await _call('inspect', {'folder': path});
    if (!mounted) return;
    setState(() {
      _inspect = result;
      final existing = result['existing'];
      _resume = existing is Map &&
          existing['invalid'] != true &&
          existing['closed_at'] == null;
      if (result['ok'] != true) _error = '${result['message']}';
    });
  }

  String _dateText(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _start() async {
    if (_folder == null) {
      setState(() => _error = 'Selecione a pasta provas.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _call('start', {
      'folder': _folder,
      'resume': _resume,
      'name': _name.text.trim(),
      'event_date': _dateText(_date),
      'price_per_photo': _price.text.trim(),
      'pin': _pin.text.trim(),
      'staff_username': _user.text.trim(),
      'staff_password': _password.text,
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result['ok'] == true && result['running'] == true) {
        _status = result;
        _password.clear();
      } else {
        _error = '${result['message'] ?? 'Não foi possível iniciar a sessão.'}';
      }
    });
  }

  Future<void> _stop() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Terminar sessão offline?'),
              content: const Text(
                  'Os dispositivos deixam de conseguir aceder ao catálogo. Todos os pedidos e registos ficam guardados no ficheiro JSON da pasta provas.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: FilledButton.styleFrom(backgroundColor: _rose),
                    child: const Text('Terminar')),
              ],
            ));
    if (confirmed != true) return;
    final result = await _call('stop');
    if (mounted) setState(() => _status = result);
  }

  InputDecoration _decoration(String label, {IconData? icon, Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFFAF9F7),
        prefixIcon: icon == null ? null : Icon(icon, color: _muted, size: 20),
        suffixIcon: suffix,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _rose, width: 1.6)),
      );

  Widget _card(String title, Widget child, {String? subtitle}) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title,
              style: const TextStyle(
                  color: _ink, fontSize: 17, fontWeight: FontWeight.w700)),
          if (subtitle != null)
            Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(subtitle,
                    style: const TextStyle(color: _muted, fontSize: 13))),
          const SizedBox(height: 14),
          child,
        ]),
      );

  String _eta(int seconds) {
    if (seconds <= 60) return 'menos de 1 minuto';
    final minutes = (seconds / 60).ceil();
    return minutes == 1 ? 'cerca de 1 minuto' : 'cerca de $minutes minutos';
  }

  Widget _facesCard(Map<String, dynamic> f) {
    final total = (f['total'] as num?)?.toInt() ?? 0;
    final indexed = (f['indexed'] as num?)?.toInt() ?? 0;
    final ready = f['ready'] == true;
    final problem = f['problem'] as String?;
    final eta = (f['eta_seconds'] as num?)?.toInt() ?? 0;
    final color = problem != null
        ? const Color(0xFF9B3D3D)
        : ready
            ? const Color(0xFF2E7D32)
            : _rose;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ready ? Icons.check_circle : Icons.face_retouching_natural,
              color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  problem != null
                      ? 'Reconhecimento facial indisponível'
                      : ready
                          ? 'Reconhecimento facial pronto'
                          : f['preparing'] == true
                              ? 'Reconhecimento facial: a preparar…'
                              : 'Reconhecimento facial: a analisar fotografias',
                  style: const TextStyle(
                      color: _ink, fontSize: 17, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 10),
        if (problem != null)
          Text(problem, style: const TextStyle(color: Color(0xFF9B3D3D)))
        else ...[
          ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                  minHeight: 10,
                  value: total == 0 ? (ready ? 1 : null) : indexed / total,
                  color: color,
                  backgroundColor: const Color(0xFFF3EEEC))),
          const SizedBox(height: 8),
          Text(
              ready
                  ? '$total fotografias analisadas. Os convidados já podem usar «Encontrar as minhas fotos».'
                  : '$indexed de $total fotografias analisadas · falta ${_eta(eta)}. Até lá, o botão no catálogo mostra este tempo.',
              style: const TextStyle(color: _muted)),
        ],
      ]),
    );
  }

  Widget _stat(String label, String value, {Color? color}) => Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color ?? const Color(0xFFFAF9F7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: const TextStyle(
                  color: _ink, fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        ]),
      );

  Widget _form() {
    final existing = _inspect?['existing'];
    final canResume = existing is Map && existing['invalid'] != true;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Criar sessão offline',
          style: TextStyle(
              color: _ink, fontSize: 24, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      const Text(
          'Este computador passa a servir o catálogo aos dispositivos ligados à mesma rede (router sem internet). Tudo o que acontecer fica guardado num ficheiro JSON dentro da pasta provas.',
          style: TextStyle(color: _muted)),
      const SizedBox(height: 18),
      _card(
          'Pasta provas',
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            OutlinedButton.icon(
                onPressed: _busy ? null : _pickFolder,
                icon: const Icon(Icons.folder_open),
                style: OutlinedButton.styleFrom(
                    foregroundColor: _rose,
                    side: const BorderSide(color: _rose),
                    padding: const EdgeInsets.all(14)),
                label: Text(_folder ?? 'Selecionar pasta',
                    overflow: TextOverflow.ellipsis)),
            if (_inspect?['ok'] == true)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                      '${_inspect!['photos']} fotografias encontradas (JPG/PNG).',
                      style: const TextStyle(color: _ink))),
            if (canResume)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: _roseSoft,
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Já existe uma sessão nesta pasta: «${existing['name']}» · ${existing['event_date']} · ${existing['orders']} pedidos${existing['closed_at'] != null ? ' · terminada' : ''}',
                                style: const TextStyle(
                                    color: _ink, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, children: [
                              ChoiceChip(
                                  label: const Text('Retomar esta sessão'),
                                  selected: _resume,
                                  selectedColor: Colors.white,
                                  onSelected: (_) =>
                                      setState(() => _resume = true)),
                              ChoiceChip(
                                  label: const Text(
                                      'Criar nova (guarda cópia da anterior)'),
                                  selected: !_resume,
                                  selectedColor: Colors.white,
                                  onSelected: (_) =>
                                      setState(() => _resume = false)),
                            ]),
                          ]))),
          ]),
          subtitle: 'Pasta com as fotografias que vão aparecer no catálogo.'),
      if (!_resume)
        _card(
            'Evento',
            Column(children: [
              TextField(
                  controller: _name,
                  decoration: _decoration('Nome da sessão / evento',
                      icon: Icons.event_outlined)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100));
                          if (picked != null) setState(() => _date = picked);
                        },
                        child: InputDecorator(
                            decoration: _decoration('Data',
                                icon: Icons.calendar_today_outlined),
                            child: Text(_dateText(_date))))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: _decoration('Preço por fotografia (€)',
                            icon: Icons.euro))),
              ]),
              const SizedBox(height: 10),
              TextField(
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: _decoration('PIN do catálogo (4 dígitos)',
                      icon: Icons.pin_outlined)),
            ])),
      _card(
          _resume ? 'Confirmar acesso da equipa' : 'Acesso da equipa',
          Column(children: [
            if (!_resume) ...[
              TextField(
                  controller: _user,
                  decoration:
                      _decoration('Utilizador', icon: Icons.person_outline)),
              const SizedBox(height: 10)
            ],
            TextField(
                controller: _password,
                obscureText: !_showPassword,
                decoration: _decoration('Palavra-passe',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: _muted)))),
          ]),
          subtitle: _resume
              ? 'Introduza a palavra-passe definida quando a sessão foi criada.'
              : 'A equipa entra com estas credenciais no login habitual para gerir os pedidos desta sessão.'),
      if (_error != null)
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!,
                style: const TextStyle(color: Color(0xFF9B3D3D)))),
      FilledButton.icon(
          onPressed: _busy ? null : _start,
          style: FilledButton.styleFrom(
              backgroundColor: _rose,
              padding: const EdgeInsets.all(18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.wifi_tethering),
          label: Text(
              _resume ? 'Retomar sessão offline' : 'Iniciar sessão offline',
              style: const TextStyle(fontSize: 16))),
    ]);
  }

  Widget _dashboard() {
    final s = _status;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
                color: Color(0xFF2E7D32), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        const Expanded(
            child: Text('Sessão offline ativa',
                style: TextStyle(
                    color: _ink, fontSize: 24, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 6),
      Text(
          '${s['name']} · ${s['event_date']} · ${s['price_per_photo']} € por fotografia',
          style: const TextStyle(color: _muted)),
      const SizedBox(height: 18),
      Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line)),
                child: Column(children: [
                  QrImageView(
                      data: '${s['qr']}',
                      size: 210,
                      backgroundColor: Colors.white),
                  const SizedBox(height: 8),
                  const Text('QR do catálogo', style: TextStyle(color: _muted)),
                ])),
            Container(
                width: 300,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: _roseSoft, borderRadius: BorderRadius.circular(18)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PIN do catálogo',
                          style: TextStyle(color: _muted)),
                      Text('${s['pin']}',
                          style: const TextStyle(
                              color: _ink,
                              fontSize: 46,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 8)),
                      const SizedBox(height: 14),
                      const Text('Endereço na rede',
                          style: TextStyle(color: _muted)),
                      SelectableText('${s['ip']}:${s['port']}',
                          style: const TextStyle(
                              color: _ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      const Text('Acesso da equipa',
                          style: TextStyle(color: _muted)),
                      Text('Utilizador: ${s['staff_username']}',
                          style: const TextStyle(
                              color: _ink, fontWeight: FontWeight.w600)),
                    ])),
          ]),
      const SizedBox(height: 18),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _stat('Fotografias', '${s['photos']}'),
        _stat('Dispositivos', '${s['devices']}'),
        _stat('Pedidos', '${s['orders']}'),
        _stat('Por atender', '${s['pending']}', color: const Color(0xFFFFF3E0)),
        _stat('Pagos', '${s['paid']}', color: const Color(0xFFE8F5E9)),
        _stat('Devem', '${s['debts']}', color: const Color(0xFFFBEAEA)),
        _stat('Troco por entregar', '${s['change_owed']}'),
        _stat('Total vendido', '${s['total_sold']}'),
        _stat('Recebido', '${s['total_received']}'),
      ]),
      const SizedBox(height: 16),
      if (s['faces'] is Map)
        _facesCard(Map<String, dynamic>.from(s['faces'] as Map)),
      const SizedBox(height: 12),
      Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(14)),
          child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.power_outlined, color: Color(0xFF8D6E00)),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                        'Enquanto a sessão estiver aberta, este computador não entra em suspensão sozinho e pode bloquear o ecrã. '
                        'Num portátil, deixe-o ligado à corrente e não feche a tampa, a não ser que nas opções de energia do Windows «Ao fechar a tampa» esteja em «Não fazer nada».',
                        style: TextStyle(color: Color(0xFF5D4A00)))),
              ])),
      const SizedBox(height: 14),
      Text('Ficheiro: ${s['file']}',
          style: const TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 18),
      FilledButton.icon(
          onPressed: () => context.pushNamed('TeamOperationsOnline'),
          style: FilledButton.styleFrom(
              backgroundColor: _rose,
              padding: const EdgeInsets.all(18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Gerir pedidos (login da equipa)',
              style: TextStyle(fontSize: 16))),
      const SizedBox(height: 10),
      OutlinedButton.icon(
          onPressed: _stop,
          style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF9B3D3D),
              side: const BorderSide(color: Color(0xFF9B3D3D)),
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('Terminar sessão offline')),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final desktop = _status['desktop'] == true;
    return SizedBox(
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        child: ColoredBox(
            color: const Color(0xFFFAF9F7),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _rose))
                : Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                      onPressed: () =>
                                          context.goNamed('WelcomeScreen'),
                                      icon: const Icon(Icons.arrow_back,
                                          color: _muted),
                                      label: const Text('Ecrã inicial',
                                          style: TextStyle(color: _muted)))),
                              const SizedBox(height: 8),
                              if (!desktop)
                                const Text(
                                    'A sessão offline só pode ser criada num computador Windows ou macOS.',
                                    style: TextStyle(color: _ink, fontSize: 16))
                              else if (_status['running'] == true)
                                _dashboard()
                              else
                                _form(),
                            ])))));
  }
}
