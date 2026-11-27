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
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class Studio59ServiceDetail extends StatefulWidget {
  const Studio59ServiceDetail(
      {super.key, this.width, this.height, this.eventId});
  final double? width;
  final double? height;
  final int? eventId;

  @override
  State<Studio59ServiceDetail> createState() => _Studio59ServiceDetailState();
}

class _Studio59ServiceDetailState extends State<Studio59ServiceDetail> {
  Map<String, dynamic>? _event;
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _availableStaff = [];
  List<Map<String, dynamic>> _templates = [];
  String _token = '';
  bool _isAdmin = false;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.eventId;
    if (id == null || id < 0) {
      setState(() {
        _error = 'Selecione um serviço na agenda.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = http.Client();
    try {
      _token = (await const FlutterSecureStorage()
                  .read(key: 'studio59_staff_token') ??
              '')
          .trim();
      if (_token.isEmpty)
        throw StateError('Inicie sessão para consultar este serviço.');
      Future<Map<String, dynamic>> request(String path) async {
        final response = await client.get(
            Uri.parse('https://studio59.wiredevelop.pt/api$path'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $_token'
            }).timeout(const Duration(seconds: 20));
        if (response.statusCode == 401)
          throw StateError('A sessão expirou. Inicie sessão novamente.');
        if (response.statusCode == 403 || response.statusCode == 404)
          throw StateError('Não tem acesso a este serviço.');
        if (response.statusCode < 200 || response.statusCode >= 300)
          throw StateError(
              'Não foi possível carregar o serviço (${response.statusCode}).');
        final data = jsonDecode(response.body);
        if (data is! Map)
          throw const FormatException('Resposta inválida do servidor.');
        return Map<String, dynamic>.from(data);
      }

      final me = await request('/auth/me');
      final meData =
          me['data'] is Map ? Map<String, dynamic>.from(me['data'] as Map) : me;
      final user = meData['user'] is Map
          ? Map<String, dynamic>.from(meData['user'] as Map)
          : meData;
      final admin = const {'admin', 'administrator'}
          .contains('${user['role']}'.toLowerCase());
      _role = '${user['role'] ?? ''}'.toLowerCase();
      _userName = '${user['name'] ?? user['username'] ?? ''}';
      Map<String, dynamic>? event;
      List<Map<String, dynamic>> staff = [];
      if (id > 0) {
        final response = await request('/events/$id');
        event = response['data'] is Map
            ? Map<String, dynamic>.from(response['data'] as Map)
            : response;
        try {
          final team = await request('/events/$id/staff');
          if (team['data'] is List)
            staff = (team['data'] as List)
                .whereType<Map>()
                .map((r) => Map<String, dynamic>.from(r))
                .toList();
        } catch (_) {/* A ficha continua disponível sem a secção de equipa. */}
      } else if (!admin &&
          !const {'backoffice', 'receptionist', 'rececionista'}
              .contains(_role)) {
        throw StateError('Não tem permissão para criar serviços.');
      }
      List<Map<String, dynamic>> templates = [];
      List<Map<String, dynamic>> availableStaff = [];
      final body = await request('/events/service-templates');
      if (body['data'] is List)
        templates = (body['data'] as List)
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      if (admin) {
        if (id > 0) {
          final eligible = await request('/events/$id/staff/users');
          if (eligible['data'] is List)
            availableStaff = (eligible['data'] as List)
                .whereType<Map>()
                .map((r) => Map<String, dynamic>.from(r))
                .where((r) => r['role'] == 'photographer')
                .toList();
        }
      }
      if (!mounted) return;
      setState(() {
        _event = event;
        _staff = staff;
        _availableStaff = availableStaff;
        _templates = templates;
        _isAdmin = admin;
        _loading = false;
      });
      if (id > 0) _loadNotes();
      if (id == 0 && !_editing) _startEdit();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is StateError
            ? error.message.toString()
            : 'Não foi possível contactar o servidor.';
        _loading = false;
      });
    } finally {
      client.close();
    }
  }

  String _label(String key) =>
      const {
        'id': 'ID',
        'name': 'Serviço',
        'event_type': 'Tipo',
        'event_date': 'Data',
        'event_time': 'Hora',
        'location': 'Local',
        'estrangeiro': 'Estrangeiro',
        'city': 'Cidade',
        'address': 'Morada',
        'address2': 'Morada adicional',
        'delivery_date': 'Data de entrega',
        'guest_count': 'Convidados',
        'report_number': 'Número da reportagem',
        'legacy_report_number': 'Número anterior',
        'base_price': 'Preço base',
        'price_per_photo': 'Preço por fotografia',
        'notes': 'Notas',
        'is_active_today': 'Ativo hoje',
        'is_locked': 'Bloqueado',
      }[key] ??
      key.replaceAll('_', ' ');

  String _fieldLabel(String key) {
    final type = '${_event?['event_type'] ?? ''}';
    for (final template in _templates) {
      if ('${template['slug']}' != type) continue;
      for (final field in (template['fields'] is List
          ? template['fields'] as List
          : const [])) {
        if (field is Map && '${field['key']}' == key)
          return '${field['label'] ?? _label(key)}';
      }
    }
    return _label(key);
  }

  bool _isPhone(String key) =>
      RegExp(r'contacto|telemovel|telefone|phone|mobile', caseSensitive: false)
          .hasMatch(key);
  bool _isEmail(String key) => key.toLowerCase().contains('email');
  bool _isAddress(String key) => RegExp(
          r'morada|address|localidade|location|city|igreja_local|quinta_local|coordenadas',
          caseSensitive: false)
      .hasMatch(key);

  String _groupFor(String key) {
    final value = key.toLowerCase();
    if (value.contains('noivo') && !value.contains('noivos')) return 'Noivo';
    if (value.contains('noiva') && !value.contains('noivos')) return 'Noiva';
    if (RegExp(r'igreja|missa|cerimonia').hasMatch(value)) return 'Igreja';
    if (RegExp(r'quinta|almoco|mesa_apoio_fotografos').hasMatch(value))
      return 'Quinta';
    if (RegExp(
            r'^servico_|^event_|^price_|^base_price$|^location$|^city$|^address|^notes$|^guest_count$|^numero_convidados$|^tipo_pacote$|^data_entrega$|^delivery_date$|^estar_na_loja_as$')
        .hasMatch(value)) return 'Serviço';
    return 'Outros';
  }

  Future<void> _launch(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication))
        throw StateError('Não foi possível abrir a aplicação.');
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Não foi possível abrir a aplicação.')));
    }
  }

  Future<void> _openAddress(String address) async {
    final choice = await showCupertinoModalPopup<String>(
        context: context,
        builder: (sheetContext) => CupertinoActionSheet(
              title: const Text('Abrir morada em'),
              actions: [
                CupertinoActionSheetAction(
                    onPressed: () => Navigator.pop(sheetContext, 'apple'),
                    child: const Text('Mapas Apple')),
                CupertinoActionSheetAction(
                    onPressed: () => Navigator.pop(sheetContext, 'google'),
                    child: const Text('Google Maps')),
                CupertinoActionSheetAction(
                    onPressed: () => Navigator.pop(sheetContext, 'waze'),
                    child: const Text('Waze')),
              ],
              cancelButton: CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Cancelar')),
            ));
    if (choice == null || !mounted) return;
    final encoded = Uri.encodeQueryComponent(address);
    final url = choice == 'apple'
        ? 'https://maps.apple.com/?q=$encoded'
        : choice == 'waze'
            ? 'https://waze.com/ul?q=$encoded&navigate=yes'
            : 'https://www.google.com/maps/search/?api=1&query=$encoded';
    await _launch(Uri.parse(url));
  }

  Widget _infoCard(String key, dynamic value) {
    if (value == null || value.toString().trim().isEmpty)
      return const SizedBox.shrink();
    final label = _fieldLabel(key);
    final display = value is bool ? (value ? 'Sim' : 'Não') : value.toString();
    final phone = _isPhone(key);
    final email = _isEmail(key);
    final address = _isAddress(key);
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: phone
                  ? () => _launch(Uri(scheme: 'tel', path: display))
                  : email
                      ? () => _launch(Uri(scheme: 'mailto', path: display))
                      : address
                          ? () => _openAddress(display)
                          : null,
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Icon(
                        phone
                            ? Icons.call_outlined
                            : email
                                ? Icons.mail_outline
                                : address
                                    ? Icons.place_outlined
                                    : Icons.notes_outlined,
                        color: const Color(0xFFB77F84),
                        size: 21),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(label,
                              style: const TextStyle(
                                  color: Color(0xFF756865), fontSize: 12)),
                          const SizedBox(height: 3),
                          Text(display,
                              style: const TextStyle(
                                  color: Color(0xFF292624),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500)),
                        ])),
                    if (phone || email || address)
                      const Icon(Icons.chevron_right, color: Color(0xFFB77F84)),
                  ])),
            )));
  }

  Widget _section(String title, List<MapEntry<String, dynamic>> entries) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 18),
        Text(title,
            style: const TextStyle(
                color: Color(0xFF292624),
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (final entry in entries) _infoCard(entry.key, entry.value),
      ]);

  Widget _line(String label, dynamic value) {
    if (value == null || value.toString().trim().isEmpty)
      return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF756865), fontSize: 13)),
          const SizedBox(height: 3),
          Text(value is bool ? (value ? 'Sim' : 'Não') : value.toString(),
              style: const TextStyle(color: Color(0xFF292624), fontSize: 16)),
        ]));
  }

  Future<void> _addStaff() async {
    final eventId = widget.eventId;
    if (!_isAdmin || eventId == null || eventId <= 0) return;
    final assigned = _staff
        .map((r) => int.tryParse(
            '${r['user_id'] ?? (r['user'] is Map ? (r['user'] as Map)['id'] : '')}'))
        .toSet();
    final choices = _availableStaff
        .where((r) => !assigned.contains(int.tryParse('${r['id']}')))
        .toList();
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não existem fotógrafos disponíveis para atribuir.')));
      return;
    }
    final selected = await showDialog<int>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
            title: const Text('Atribuir fotógrafo'),
            children: choices
                .map((r) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(
                        dialogContext, int.tryParse('${r['id']}')),
                    child: Text('${r['name'] ?? r['username']}')))
                .toList()));
    if (selected == null) return;
    final client = http.Client();
    try {
      final response = await client
          .post(
              Uri.parse(
                  'https://studio59.wiredevelop.pt/api/events/$eventId/staff'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_token'
              },
              body: jsonEncode({
                'user_ids': [selected]
              }))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw StateError(
            'Não foi possível atribuir o fotógrafo (${response.statusCode}).');
      _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is StateError
                ? error.message.toString()
                : 'Não foi possível contactar o servidor.')));
    } finally {
      client.close();
    }
  }

  Future<void> _removeStaff(Map<String, dynamic> member) async {
    final eventId = widget.eventId;
    final userId = int.tryParse(
        '${member['user_id'] ?? (member['user'] is Map ? (member['user'] as Map)['id'] : '')}');
    if (!_isAdmin || eventId == null || userId == null) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Remover fotógrafo da equipa?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Voltar')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Remover'))
                ]));
    if (confirmed != true) return;
    final client = http.Client();
    try {
      final response = await client.delete(
          Uri.parse(
              'https://studio59.wiredevelop.pt/api/events/$eventId/staff/$userId'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $_token'
          }).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw StateError(
            'Não foi possível remover o fotógrafo (${response.statusCode}).');
      _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is StateError
                ? error.message.toString()
                : 'Não foi possível contactar o servidor.')));
    } finally {
      client.close();
    }
  }

  // ---- Ficha em página (estilo FileMaker/Access): rascunho automático e publicação ao guardar ----
  static const _rose = Color(0xFFB77F84);
  static const _ink = Color(0xFF292624);
  static const _muted = Color(0xFF6D625F);
  bool _editing = false;
  bool _saving = false;
  String? _formError;
  String _formType = '';
  String _role = '';
  // Equipas: número de equipas e, para cada uma, profissionais, horas na loja e para onde vai.
  List<Map<String, dynamic>> _teamOptions = [];
  String? get _teamKey {
    for (final f in _templateFields) {
      if (f['type'] == 'team' && f['source'] != 'event') return '${f['key']}';
    }
    return _templateFields.any((f) => '${f['key']}' == 'equipa_de_trabalho')
        ? 'equipa_de_trabalho'
        : null;
  }

  int get _teamCount => (int.tryParse(_c('equipas_n').text) ?? 1).clamp(1, 4);
  List<String> get _teamDestinations =>
      _templateFields.any((f) => '${f['key']}'.contains('noiv'))
          ? const ['Noivo', 'Noiva', 'Igreja', 'Quinta']
          : const ['Igreja', 'Quinta', 'Casa', 'Festa'];

  Future<void> _loadTeamOptions() async {
    final client = http.Client();
    try {
      final response = await client.get(
          Uri.parse(
              'https://studio59.wiredevelop.pt/api/service-catalog/team-options'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $_token'
          }).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        _teamOptions =
            ((jsonDecode(response.body) as Map)['data'] as List? ?? const [])
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList();
      }
    } catch (_) {
      // Sem a lista, os profissionais escrevem-se à mão, como antes.
    } finally {
      client.close();
      if (mounted) setState(() {});
    }
  }

  void _fillTeams(Map<String, dynamic> meta) {
    final key = _teamKey;
    if (key == null) return;
    List<dynamic> saved = const [];
    try {
      saved = jsonDecode('${meta['equipas_json'] ?? '[]'}') as List;
    } catch (_) {}
    final teams = saved.whereType<Map>().toList();
    if (teams.isEmpty) {
      _c('equipas_n').text = '1';
      _c('equipa_0_membros').text = '${meta[key] ?? ''}';
      _c('equipa_0_hora').text = '${meta['estar_na_loja_as'] ?? ''}';
      return;
    }
    _c('equipas_n').text = '${teams.length.clamp(1, 4)}';
    for (var i = 0; i < teams.length && i < 4; i++) {
      _c('equipa_${i}_membros').text = '${teams[i]['membros'] ?? ''}';
      _c('equipa_${i}_hora').text = '${teams[i]['hora'] ?? ''}';
      _c('equipa_${i}_destino').text = '${teams[i]['destino'] ?? ''}';
    }
  }

  List<String> _teamTokens(String text) => text
      .split(RegExp(r'[+,]'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
  String _teamMembers(int i) =>
      _teamTokens(_c('equipa_${i}_membros').text).join('+');

  /// Texto da equipa na ficha, ex.: (LM+MB)- Noivo (JL+MC)- Noiva. É daqui que o servidor associa os fotógrafos.
  String _teamsText() {
    final parts = <String>[];
    for (var i = 0; i < _teamCount; i++) {
      final members = _teamMembers(i);
      final dest = _c('equipa_${i}_destino').text.trim();
      if (members.isEmpty && dest.isEmpty) continue;
      parts.add(dest.isEmpty
          ? (_teamCount == 1
              ? _teamTokens(_c('equipa_${i}_membros').text).join(' + ')
              : '($members)')
          : '($members)- $dest');
    }
    return parts.join(' ');
  }

  void _toggleTeamMember(int i, String code) {
    final c = _c('equipa_${i}_membros');
    final tokens = _teamTokens(c.text);
    final at =
        tokens.indexWhere((t) => t.split(' ').first.toUpperCase() == code);
    if (at >= 0) {
      tokens.removeAt(at);
    } else {
      tokens.add(code);
    }
    setState(() => c.text = tokens.join(' + '));
    _touched();
  }

  Widget _teamsEditor(String label) {
    final count = _teamCount;
    final width = count == 1
        ? 'full'
        : count == 3
            ? 'third'
            : 'half';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _input('equipas_n', 'Número de equipas', 'select',
          options: const ['1', '2', '3', '4']),
      const SizedBox(height: 12),
      _grid([
        for (var i = 0; i < count; i++)
          (
            width,
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFFAF9F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFECE7E3))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(count == 1 ? label.toUpperCase() : 'EQUIPA ${i + 1}',
                          style: const TextStyle(
                              color: Color(0xFF8E6267),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1)),
                      const SizedBox(height: 8),
                      if (_teamOptions.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Wrap(spacing: 6, runSpacing: 6, children: [
                              for (final option in _teamOptions)
                                FilterChip(
                                    visualDensity: VisualDensity.compact,
                                    showCheckmark: false,
                                    selectedColor: const Color(0xFFF2E5E3),
                                    label: Text('${option['code']}'),
                                    tooltip: '${option['name'] ?? ''}',
                                    selected: _teamTokens(
                                            _c('equipa_${i}_membros').text)
                                        .any((t) =>
                                            t.split(' ').first.toUpperCase() ==
                                            '${option['code']}'),
                                    onSelected: _saving
                                        ? null
                                        : (_) => _toggleTeamMember(
                                            i, '${option['code']}')),
                            ])),
                      _fieldCaption('Profissionais'),
                      TextField(
                          controller: _c('equipa_${i}_membros'),
                          enabled: !_saving,
                          onChanged: (_) {
                            setState(() {});
                            _touched();
                          },
                          decoration: _deco(hint: 'Ex.: LM não trocar + MB')),
                      const SizedBox(height: 10),
                      _input('equipa_${i}_hora', 'Horas na loja', 'time'),
                      const SizedBox(height: 10),
                      _input('equipa_${i}_destino', 'Vai para', 'select',
                          options: _teamDestinations),
                    ]))
          ),
      ]),
    ]);
  }

  // Pack e serviços da ficha: catálogo editável em Configurações; na ficha fica uma fotografia dos nomes e preços.
  Map<String, dynamic>? _catalog;
  String? _catalogError;
  String _packId = '';
  final Set<String> _sel = {};

  List<Map<String, dynamic>> _catList(String key) =>
      (_catalog?[key] as List? ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
  Map<String, dynamic>? get _pack =>
      _catList('packs').where((p) => '${p['id']}' == _packId).firstOrNull;
  Set<String> _packItems(Map<String, dynamic>? pack) =>
      {...(pack?['items'] as List? ?? const []).map((e) => '$e')};
  String _eur(num v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

  Future<void> _loadCatalog() async {
    final client = http.Client();
    try {
      final response = await client.get(
          Uri.parse('https://studio59.wiredevelop.pt/api/service-catalog'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $_token'
          }).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200)
        throw StateError('${response.statusCode}');
      _catalog = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      _catalogError = null;
    } catch (_) {
      _catalogError = 'Não foi possível carregar os packs e serviços.';
    } finally {
      client.close();
      if (mounted) setState(() {});
    }
  }

  /// Soma dos serviços marcados que têm preço e não fazem parte do pack.
  num get _extrasTotal {
    final inPack = _packItems(_pack);
    return _catList('items')
        .where((i) =>
            _sel.contains('${i['id']}') && !inPack.contains('${i['id']}'))
        .fold<num>(
            0, (sum, i) => sum + (num.tryParse('${i['price'] ?? ''}') ?? 0));
  }

  /// Com o preço do pack conhecido, o preço base acompanha as escolhas (continua editável à mão).
  void _syncBasePrice() {
    final price = num.tryParse('${_pack?['price'] ?? ''}');
    if (price != null) _c('base_price').text = '${price + _extrasTotal}';
  }

  void _choosePack(String? id) {
    setState(() {
      _sel.removeAll(_packItems(_pack));
      _packId = id ?? '';
      _sel.addAll(_packItems(_pack));
      _syncBasePrice();
    });
    _touched();
  }

  Widget _servicesBox() {
    if (_catalog == null) {
      return _box('Pack e serviços', [
        (
          'full',
          _catalogError == null
              ? const LinearProgressIndicator(color: _rose)
              : Row(children: [
                  Expanded(
                      child: Text(_catalogError!,
                          style: const TextStyle(color: Color(0xFFB3261E)))),
                  TextButton(
                      onPressed: _loadCatalog,
                      child: const Text('Tentar novamente'))
                ])
        )
      ]);
    }
    final items = _catList('items');
    final inPack = _packItems(_pack);
    final byCategory = <String, List<Map<String, dynamic>>>{};
    for (final i in items) {
      byCategory.putIfAbsent('${i['category'] ?? 'Outros'}', () => []).add(i);
    }
    final packPrice = num.tryParse('${_pack?['price'] ?? ''}');
    final extras = _extrasTotal;
    return _box('Pack e serviços', [
      (
        'full',
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _fieldCaption('Pack'),
          DropdownButtonFormField<String>(
              value: _pack == null ? '' : _packId,
              isExpanded: true,
              decoration: _deco(),
              items: [
                const DropdownMenuItem(
                    value: '', child: Text('Sem pack (serviços à medida)')),
                for (final p in _catList('packs'))
                  DropdownMenuItem(
                      value: '${p['id']}',
                      child: Text(
                          '${p['name']}${num.tryParse('${p['price'] ?? ''}') == null ? '' : ' · ${_eur(num.parse('${p['price']}'))}'}',
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: _saving ? null : _choosePack),
          const SizedBox(height: 8),
          Text(
              _pack == null
                  ? 'Escolha um pack para marcar os serviços dele, ou marque os serviços um a um.'
                  : 'O pack marcou ${inPack.length} serviços. Pode acrescentar ou retirar abaixo.',
              style: const TextStyle(color: _muted, fontSize: 12)),
          if (_pack != null || extras > 0)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    [
                      if (_pack != null)
                        packPrice == null
                            ? 'Pack: sem preço definido'
                            : 'Pack: ${_eur(packPrice)}',
                      if (extras > 0) 'Extras: ${_eur(extras)}',
                      if (packPrice != null)
                        'Total: ${_eur(packPrice + extras)} (sem IVA)',
                    ].join(' · '),
                    style: const TextStyle(
                        color: _ink, fontWeight: FontWeight.w600))),
          const SizedBox(height: 6),
          for (final entry in byCategory.entries)
            Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: PageStorageKey('cat-${entry.key}'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  initiallyExpanded:
                      entry.value.any((i) => _sel.contains('${i['id']}')),
                  title: Text(
                      '${entry.key} (${entry.value.where((i) => _sel.contains('${i['id']}')).length}/${entry.value.length})',
                      style: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  children: [
                    for (final i in entry.value)
                      CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: _rose,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _sel.contains('${i['id']}'),
                          title: Text('${i['name']}',
                              style: const TextStyle(color: _ink)),
                          subtitle: '${i['detail'] ?? ''}'.isEmpty
                              ? null
                              : Text('${i['detail']}'),
                          secondary: inPack.contains('${i['id']}')
                              ? const Text('no pack',
                                  style: TextStyle(color: _rose, fontSize: 12))
                              : num.tryParse('${i['price'] ?? ''}') == null
                                  ? null
                                  : Text(_eur(num.parse('${i['price']}')),
                                      style: const TextStyle(
                                          color: _muted, fontSize: 12)),
                          onChanged: _saving
                              ? null
                              : (v) {
                                  setState(() {
                                    if (v == true) {
                                      _sel.add('${i['id']}');
                                    } else {
                                      _sel.remove('${i['id']}');
                                    }
                                    _syncBasePrice();
                                  });
                                  _touched();
                                })
                  ],
                )),
        ])
      ),
    ]);
  }

  /// O que foi contratado, para a equipa ver na ficha (sem preços).
  Widget _servicesView(Map<String, dynamic> event) {
    final meta =
        event['event_meta'] is Map ? event['event_meta'] as Map : const {};
    final pack = '${meta['pack_nome'] ?? ''}'.trim();
    List<dynamic> items = const [];
    try {
      items = jsonDecode('${meta['servicos_json'] ?? '[]'}') as List;
    } catch (_) {}
    if (pack.isEmpty && items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 18),
      const Text('Pack e serviços',
          style: TextStyle(
              color: Color(0xFF292624),
              fontSize: 19,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      if (pack.isNotEmpty)
        Text(pack,
            style: const TextStyle(
                color: Color(0xFF292624), fontWeight: FontWeight.w700)),
      for (final i in items.whereType<Map>())
        Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
                '• ${i['name'] ?? ''}${'${i['detail'] ?? ''}'.isEmpty ? '' : ' (${i['detail']})'}',
                style: const TextStyle(color: Color(0xFF292624)))),
    ]);
  }

  // Impressão das fichas (administração e backoffice).
  bool get _canPrintSheets => _seesTeamNotes;
  static const _sheetNames = <String, String>{
    'servico': 'Ficha de serviço',
    'filme': 'Ficha técnica de filme',
    'fotografia': 'Ficha técnica de fotografia',
    'contrato': 'Contrato',
    'contas': 'Contas (vendas e despesas)',
  };

  Future<void> _printSheets(int eventId, List<String> types) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
        content: Text('A preparar as fichas…'),
        duration: Duration(seconds: 2)));
    final client = http.Client();
    try {
      final response = await client.get(
          Uri.parse(
                  'https://studio59.wiredevelop.pt/api/events/$eventId/sheets')
              .replace(queryParameters: {'types': types.join(',')}),
          headers: {
            'Accept': 'application/pdf, application/json',
            'Authorization': 'Bearer $_token'
          }).timeout(const Duration(seconds: 60));
      if (response.statusCode != 200)
        throw StateError(
            'Não foi possível gerar as fichas (${response.statusCode}).');
      final bytes = response.bodyBytes;
      final name = 'fichas_servico_$eventId.pdf';
      try {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
      } catch (_) {
        // Sem serviço de impressão neste dispositivo: partilhar/guardar o PDF.
        await Printing.sharePdf(bytes: bytes, filename: name);
      }
    } catch (error) {
      messenger.showSnackBar(SnackBar(
          content: Text(error is StateError
              ? '${error.message}'
              : 'Não foi possível contactar o servidor.')));
    } finally {
      client.close();
    }
  }

  Future<void> _openPrintDialog() async {
    final id = widget.eventId ?? 0;
    if (id <= 0) return;
    final chosen = <String>{};
    final types = await showDialog<List<String>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, update) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: const Text('Imprimir fichas'),
                  content: SizedBox(
                      width: 420,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final entry in _sheetNames.entries)
                              CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  activeColor: _rose,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  value: chosen.contains(entry.key),
                                  title: Text(entry.value),
                                  onChanged: (v) => update(() {
                                        if (v == true) {
                                          chosen.add(entry.key);
                                        } else {
                                          chosen.remove(entry.key);
                                        }
                                      })),
                          ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancelar')),
                    OutlinedButton(
                        onPressed: () => Navigator.pop(
                            dialogContext, _sheetNames.keys.toList()),
                        child: const Text('Imprimir todas')),
                    FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: _rose),
                        onPressed: chosen.isEmpty
                            ? null
                            : () =>
                                Navigator.pop(dialogContext, chosen.toList()),
                        child: const Text('Imprimir')),
                  ],
                )));
    if (types != null && types.isNotEmpty && mounted)
      await _printSheets(id, types);
  }

  // Notas pós-evento: as minhas (privadas) e, para administração/backoffice, as de toda a equipa.
  final TextEditingController _myNote = TextEditingController();
  String? _myNoteSavedAt;
  bool _myNoteLoaded = false;
  bool _myNoteSaving = false;
  String? _myNoteError;
  List<Map<String, dynamic>> _teamNotes = [];
  bool get _seesTeamNotes => _isAdmin || _role == 'backoffice';

  String _when(dynamic iso) {
    final d = DateTime.tryParse('${iso ?? ''}'.replaceFirst(' ', 'T'));
    if (d == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _loadNotes() async {
    final id = widget.eventId ?? 0;
    if (id <= 0 || _token.isEmpty) return;
    final client = http.Client();
    try {
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token'
      };
      final mine = await client
          .get(
              Uri.parse(
                  'https://studio59.wiredevelop.pt/api/events/$id/my-notes'),
              headers: headers)
          .timeout(const Duration(seconds: 20));
      if (mine.statusCode == 200) {
        final note = (jsonDecode(mine.body) as Map)['note'];
        _myNote.text = note is Map ? '${note['body'] ?? ''}' : '';
        _myNoteSavedAt = note is Map ? '${note['updated_at'] ?? ''}' : null;
        _myNoteLoaded = true;
      }
      if (_seesTeamNotes) {
        final team = await client
            .get(
                Uri.parse(
                    'https://studio59.wiredevelop.pt/api/events/$id/team-notes'),
                headers: headers)
            .timeout(const Duration(seconds: 20));
        if (team.statusCode == 200) {
          _teamNotes =
              ((jsonDecode(team.body) as Map)['notes'] as List? ?? const [])
                  .whereType<Map>()
                  .map((m) => Map<String, dynamic>.from(m))
                  .toList();
        }
      }
    } catch (_) {
      _myNoteError = 'Não foi possível carregar as notas pós-evento.';
    } finally {
      client.close();
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveMyNote() async {
    final id = widget.eventId ?? 0;
    setState(() {
      _myNoteSaving = true;
      _myNoteError = null;
    });
    final client = http.Client();
    try {
      final response = await client
          .put(
              Uri.parse(
                  'https://studio59.wiredevelop.pt/api/events/$id/my-notes'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_token'
              },
              body: jsonEncode({'body': _myNote.text}))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw StateError('Não foi possível guardar (${response.statusCode}).');
      final note = (jsonDecode(response.body) as Map)['note'];
      _myNoteSavedAt = note is Map ? '${note['updated_at'] ?? ''}' : null;
      if (_seesTeamNotes) await _loadNotes();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notas pós-evento guardadas.')));
    } catch (error) {
      _myNoteError = error is StateError
          ? '${error.message}'
          : 'Não foi possível contactar o servidor.';
    } finally {
      client.close();
      if (mounted) setState(() => _myNoteSaving = false);
    }
  }

  Widget _postEventNotes() => Container(
        margin: const EdgeInsets.only(top: 18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFECE7E3))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Row(children: [
            Icon(Icons.edit_note, color: Color(0xFFB77F84)),
            SizedBox(width: 8),
            Expanded(
                child: Text('As minhas notas pós-evento',
                    style: TextStyle(
                        color: Color(0xFF292624),
                        fontSize: 18,
                        fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 4),
          const Text(
              'Só você e a administração veem o que escreve aqui. Os colegas não veem.',
              style: TextStyle(color: Color(0xFF6D625F), fontSize: 12)),
          const SizedBox(height: 10),
          if (!_myNoteLoaded && _myNoteError == null)
            const LinearProgressIndicator(color: Color(0xFFB77F84))
          else ...[
            TextField(
                controller: _myNote,
                enabled: !_myNoteSaving,
                minLines: 3,
                maxLines: 10,
                decoration: const InputDecoration(
                    hintText:
                        'Ex.: o padrinho pediu fotos extra com a avó; a quinta fecha às 2h…',
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                      (_myNoteSavedAt ?? '').isEmpty
                          ? 'Ainda sem notas.'
                          : 'Guardado a ${_when(_myNoteSavedAt)}',
                      style: const TextStyle(
                          color: Color(0xFF6D625F), fontSize: 12)),
                  FilledButton.icon(
                      onPressed: _myNoteSaving ? null : _saveMyNote,
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB77F84)),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label:
                          Text(_myNoteSaving ? 'A guardar…' : 'Guardar notas')),
                ]),
          ],
          if (_myNoteError != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_myNoteError!,
                    style: const TextStyle(color: Color(0xFFB3261E)))),
          if (_seesTeamNotes) ...[
            const Divider(height: 28),
            const Text('Notas da equipa (só administração)',
                style: TextStyle(
                    color: Color(0xFF292624),
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (_teamNotes.isEmpty)
              const Text('Ninguém escreveu notas pós-evento.',
                  style: TextStyle(color: Color(0xFF6D625F))),
            for (final n in _teamNotes)
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${n['name'] ?? ''} · ${_when(n['updated_at'])}',
                            style: const TextStyle(
                                color: Color(0xFF292624),
                                fontWeight: FontWeight.w600)),
                        SelectableText('${n['body'] ?? ''}',
                            style: const TextStyle(color: Color(0xFF292624))),
                      ])),
          ],
        ]),
      );
  String _userName = '';
  final Map<String, TextEditingController> _text = {};
  final Map<String, bool> _checks = {};
  final Map<String, String> _nextNumbers = {};
  Timer? _draftTimer;
  DateTime? _draftSavedAt;
  bool _dirty = false;

  bool get _canEdit =>
      _isAdmin ||
      const {'backoffice', 'receptionist', 'rececionista'}.contains(_role);
  String get _draftKey => 'studio59_event_draft_${widget.eventId ?? 0}';

  @override
  void dispose() {
    _draftTimer?.cancel();
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? get _template =>
      _templates.where((t) => '${t['slug']}' == _formType).firstOrNull;
  List<Map<String, dynamic>> get _templateFields =>
      (_template?['fields'] is List ? _template!['fields'] as List : const [])
          .whereType<Map>()
          .map((f) => Map<String, dynamic>.from(f))
          .where((f) => f['show_in_form'] != false)
          .toList()
        ..sort((a, b) {
          final s = (int.tryParse('${a['section_order']}') ?? 0)
              .compareTo(int.tryParse('${b['section_order']}') ?? 0);
          return s != 0
              ? s
              : (int.tryParse('${a['order']}') ?? 0)
                  .compareTo(int.tryParse('${b['order']}') ?? 0);
        });

  TextEditingController _c(String key, [String initial = '']) =>
      _text.putIfAbsent(key, () {
        final controller = TextEditingController(text: initial);
        controller.addListener(_touched);
        return controller;
      });

  void _touched() {
    if (!_editing) return;
    _dirty = true;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 1200), _saveDraft);
  }

  String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _nowTime() {
    final d = DateTime.now();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveDraft() async {
    if (!_editing || !_dirty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _draftKey,
          jsonEncode({
            'type': _formType,
            'values': {for (final e in _text.entries) e.key: e.value.text},
            'checks': _checks,
            'pack': _packId,
            'sel': _sel.toList(),
            'saved_at': DateTime.now().toIso8601String(),
          }));
      if (mounted) setState(() => _draftSavedAt = DateTime.now());
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      (await SharedPreferences.getInstance()).remove(_draftKey);
    } catch (_) {}
  }

  /// Próximo número sequencial: pergunta ao servidor; se não souber, fica "atribuído ao guardar".
  Future<void> _loadNextNumbers() async {
    final keys = <String>{
      'report_number',
      ..._templateFields
          .where((f) => f['auto'] == 'sequence')
          .map((f) => '${f['key']}')
    };
    final client = http.Client();
    try {
      for (final key in keys) {
        if (_nextNumbers.containsKey(key)) continue;
        try {
          final response = await client.get(
              Uri.parse(
                      'https://studio59.wiredevelop.pt/api/events/next-number')
                  .replace(
                      queryParameters: {'field': key, 'event_type': _formType}),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $_token'
              }).timeout(const Duration(seconds: 10));
          final body = jsonDecode(response.body);
          final value = body is Map
              ? (body['next'] ??
                  (body['data'] is Map ? body['data']['next'] : null))
              : null;
          if (response.statusCode == 200 && value != null)
            _nextNumbers[key] = '$value';
        } catch (_) {}
      }
    } finally {
      client.close();
    }
    if (!mounted) return;
    setState(() {
      for (final entry in _nextNumbers.entries) {
        final c = _c(entry.key);
        if ((widget.eventId ?? 0) == 0 && c.text.isEmpty) c.text = entry.value;
      }
    });
  }

  Future<void> _startEdit() async {
    final event = _event ?? <String, dynamic>{};
    final meta = event['event_meta'] is Map
        ? Map<String, dynamic>.from(event['event_meta'] as Map)
        : <String, dynamic>{};
    final isNew = (widget.eventId ?? 0) == 0;
    _formType =
        '${event['event_type'] ?? (_templates.isEmpty ? '' : _templates.first['slug'])}';
    for (final key in const [
      'name',
      'event_date',
      'event_time',
      'event_end_time',
      'location',
      'city',
      'address',
      'base_price',
      'price_per_photo',
      'notes',
      'report_number'
    ]) {
      _c(key).text = '${event[key] ?? ''}';
    }
    for (final key in const ['event_time', 'event_end_time']) {
      final m = RegExp(r'^(\d{1,2}:\d{2})').firstMatch(_c(key).text.trim());
      if (m != null) _c(key).text = m.group(1)!.padLeft(5, '0');
    }
    _c('estrangeiro').text =
        (meta['estrangeiro'] == true || '${meta['estrangeiro']}' == 'true')
            ? 'Sim'
            : 'Não';
    if (isNew) {
      _c('event_date').text = _today();
      if (_c('price_per_photo').text.isEmpty) _c('price_per_photo').text = '5';
    }
    void fillTemplate() {
      for (final f in _templateFields) {
        final key = '${f['key']}';
        final value = f['source'] == 'event' ? event[key] : meta[key];
        if (f['type'] == 'checkbox') {
          _checks[key] = value == true || value == 1 || '$value' == 'true';
          continue;
        }
        final c = _c(key);
        if (c.text.isEmpty && value != null) c.text = '$value';
        if (isNew && c.text.isEmpty) {
          switch ('${f['auto'] ?? ''}') {
            case 'today':
              c.text = _today();
              break;
            case 'now':
              c.text = _nowTime();
              break;
            case 'user':
              c.text = _userName;
              break;
          }
        }
      }
    }

    fillTemplate();
    _packId = '${meta['pack_id'] ?? ''}';
    _sel.clear();
    try {
      _sel.addAll((jsonDecode('${meta['servicos_json'] ?? '[]'}') as List)
          .whereType<Map>()
          .map((i) => '${i['id']}'));
    } catch (_) {}
    if (_catalog == null) _loadCatalog();
    _fillTeams(meta);
    if (_teamOptions.isEmpty) _loadTeamOptions();
    // Rascunho guardado neste dispositivo?
    Map<String, dynamic>? draft;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_draftKey);
      if (raw != null)
        draft = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {}
    if (draft != null && mounted) {
      final when = DateTime.tryParse('${draft['saved_at']}');
      final resume = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('Rascunho por publicar'),
                content: Text(
                    'Existe um rascunho desta ficha${when == null ? '' : ' guardado a ${when.day}/${when.month} às ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}'}. Quer continuar onde ficou?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Descartar rascunho')),
                  FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _rose),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Continuar rascunho')),
                ],
              ));
      if (resume == true) {
        _formType = '${draft['type'] ?? _formType}';
        fillTemplate();
        (draft['values'] as Map? ?? {}).forEach((k, v) => _c('$k').text = '$v');
        (draft['checks'] as Map? ?? {})
            .forEach((k, v) => _checks['$k'] = v == true);
        _packId = '${draft['pack'] ?? _packId}';
        if (draft['sel'] is List) {
          _sel
            ..clear()
            ..addAll((draft['sel'] as List).map((e) => '$e'));
        }
        _draftSavedAt = when;
      } else {
        await _clearDraft();
      }
    }
    if (!mounted) return;
    setState(() {
      _editing = true;
      _dirty = false;
      _formError = null;
    });
    if (isNew) _loadNextNumbers();
  }

  Future<void> _cancelEdit() async {
    if (_dirty) await _saveDraft();
    if ((widget.eventId ?? 0) == 0) {
      if (mounted) context.pop();
      return;
    }
    setState(() {
      _editing = false;
      _formError = null;
    });
  }

  Future<void> _publish() async {
    if (_quick) return _publishQuick();
    final date = DateTime.tryParse(_c('event_date').text.trim());
    final base =
        num.tryParse(_c('base_price').text.trim().replaceAll(',', '.'));
    final photo =
        num.tryParse(_c('price_per_photo').text.trim().replaceAll(',', '.'));
    if (_formType.isEmpty) {
      setState(() => _formError = 'Escolha o tipo de serviço.');
      return;
    }
    if (date == null) {
      setState(() => _formError = 'Indique a data do serviço.');
      return;
    }
    if (base == null || base < 0 || photo == null || photo < 0) {
      setState(
          () => _formError = 'Indique o preço base e o preço por fotografia.');
      return;
    }
    final event = _event ?? <String, dynamic>{};
    final meta = event['event_meta'] is Map
        ? Map<String, dynamic>.from(event['event_meta'] as Map)
        : <String, dynamic>{};
    final teamKey = _teamKey;
    if (teamKey != null) {
      _c(teamKey).text = _teamsText();
      final hours = <String>[];
      meta['equipas_json'] = jsonEncode([
        for (var i = 0; i < _teamCount; i++)
          {
            'membros': _teamMembers(i),
            'hora': _c('equipa_${i}_hora').text.trim(),
            'destino': _c('equipa_${i}_destino').text.trim(),
          },
      ]);
      for (var i = 0; i < _teamCount; i++) {
        final hour = _c('equipa_${i}_hora').text.trim();
        if (hour.isNotEmpty) hours.add(hour);
      }
      hours.sort();
      // A hora mais cedo continua a alimentar os convites de calendário.
      if (hours.isEmpty) {
        meta.remove('estar_na_loja_as');
      } else {
        meta['estar_na_loja_as'] = hours.first;
      }
    }
    // Horas e local do serviço vêm do conteúdo da ficha: a primeira e a última hora preenchidas e o local da igreja ou da quinta.
    final fichaHours = [
      for (final f in _templateFields)
        if (f['type'] == 'time') ...[
          if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(_c('${f['key']}').text.trim()))
            _c('${f['key']}').text.trim().padLeft(5, '0').substring(0, 5),
        ],
    ]..sort();
    var fichaPlace = '';
    for (final key in const [
      'local_cerimonia',
      'igreja_local',
      'local',
      'almoco_localidade',
      'quinta_nome',
      'quinta_local',
      'quinta'
    ]) {
      if (_templateFields
              .any((f) => '${f['key']}' == key && f['type'] != 'select') &&
          _c(key).text.trim().isNotEmpty) {
        fichaPlace = _c(key).text.trim();
        break;
      }
    }
    final payload = <String, dynamic>{
      'event_type': _formType, 'event_date': _c('event_date').text.trim(),
      'base_price': base, 'price_per_photo': photo,
      'event_time':
          fichaHours.isEmpty ? _c('event_time').text.trim() : fichaHours.first,
      'event_end_time': fichaHours.length < 2
          ? _c('event_end_time').text.trim()
          : fichaHours.last,
      // O nome é sempre gerado pelo servidor a partir dos campos da ficha; cidade e morada deixaram de existir no formulário.
      'location': fichaPlace.isEmpty ? _c('location').text.trim() : fichaPlace,
      'notes': _c('notes').text.trim(),
    };
    for (final f in _templateFields) {
      final key = '${f['key']}';
      final auto = '${f['auto'] ?? ''}';
      if (auto == 'on_save') continue;
      final dynamic value = f['type'] == 'checkbox'
          ? (_checks[key] ?? false)
          : f['type'] == 'number'
              ? (num.tryParse(_c(key).text.trim().replaceAll(',', '.')) ??
                  _c(key).text.trim())
              : _c(key).text.trim();
      if (f['required'] == true &&
          auto != 'sequence' &&
          (value == null || '$value'.isEmpty)) {
        setState(() => _formError = 'Preencha «${f['label'] ?? key}».');
        return;
      }
      if (auto == 'sequence' && (widget.eventId ?? 0) == 0)
        continue; // o servidor atribui o número definitivo
      if (f['source'] == 'event') {
        if ('$value'.isNotEmpty) payload[key] = value;
      } else {
        meta[key] = value;
      }
    }
    meta['estrangeiro'] = _c('estrangeiro').text == 'Sim';
    if (_catalog != null) {
      final pack = _pack;
      meta['pack_id'] = pack == null ? '' : _packId;
      meta['pack_nome'] = pack == null ? '' : '${pack['name'] ?? ''}';
      meta['pack_preco'] =
          pack == null ? null : num.tryParse('${pack['price'] ?? ''}');
      final inPack = _packItems(pack);
      meta['servicos_json'] = jsonEncode([
        for (final i in _catList('items'))
          if (_sel.contains('${i['id']}'))
            {
              'id': i['id'],
              'name': i['name'],
              'detail': i['detail'],
              'price': i['price'],
              'in_pack': inPack.contains('${i['id']}')
            },
      ]);
    }
    payload['event_meta'] = meta;
    setState(() {
      _saving = true;
      _formError = null;
    });
    final client = http.Client();
    try {
      final id = widget.eventId ?? 0;
      final uri = Uri.parse(
          'https://studio59.wiredevelop.pt/api/events${id > 0 ? '/$id' : ''}');
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token'
      };
      final response = id > 0
          ? await client
              .put(uri, headers: headers, body: jsonEncode(payload))
              .timeout(const Duration(seconds: 25))
          : await client
              .post(uri, headers: headers, body: jsonEncode(payload))
              .timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = '';
        try {
          final body = jsonDecode(response.body);
          if (body is Map)
            message = '${body['message'] ?? ''} ${body['errors'] ?? ''}'.trim();
        } catch (_) {}
        throw StateError(response.statusCode == 403
            ? 'Sem permissão para guardar este serviço (403).'
            : message.isEmpty
                ? 'Não foi possível guardar (${response.statusCode}).'
                : message);
      }
      final saved = jsonDecode(response.body);
      final savedId = saved is Map
          ? int.tryParse(
              '${saved['id'] ?? (saved['data'] is Map ? saved['data']['id'] : '')}')
          : null;
      await _clearDraft();
      _dirty = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Serviço publicado.')));
      // Ficha nova: imprime logo a ficha de serviço e o contrato. Numa alteração, pergunta primeiro.
      final printId = id > 0 ? id : savedId;
      if (_canPrintSheets && printId != null) {
        final doPrint = id == 0 ||
            await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                          backgroundColor: Colors.white,
                          title: const Text('Imprimir?'),
                          content: const Text(
                              'Quer imprimir a ficha de serviço e o contrato com estas alterações?'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Agora não')),
                            FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: _rose),
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('Imprimir')),
                          ],
                        )) ==
                true;
        if (doPrint && mounted)
          await _printSheets(printId, const ['servico', 'contrato']);
      }
      if (!mounted) return;
      if (id == 0 && savedId != null) {
        context.goNamed('Studio59ServiceOnline', queryParameters: {
          'eventId': serializeParam(savedId, ParamType.int)
        });
      } else {
        setState(() {
          _editing = false;
          _saving = false;
        });
        _load();
      }
    } catch (error) {
      if (mounted)
        setState(() {
          _saving = false;
          _formError = error is StateError
              ? error.message.toString()
              : 'Não foi possível contactar o servidor.';
        });
    } finally {
      client.close();
    }
  }

  Widget _grid(List<(String, Widget)> items) =>
      LayoutBuilder(builder: (context, constraints) {
        const gap = 12.0;
        final w = constraints.maxWidth;
        final narrow = w < 520;
        double size(String width) => narrow
            ? w
            : width == 'third'
                ? (w - 2 * gap) / 3 - 0.5
                : width == 'half'
                    ? (w - gap) / 2 - 0.5
                    : w;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final item in items)
            SizedBox(width: size(item.$1), child: item.$2)
        ]);
      });

  Widget _box(String title, List<(String, Widget)> items) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFECE7E3))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                  color: Color(0xFFF2E5E3),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16))),
              child: Text(title.toUpperCase(),
                  style: const TextStyle(
                      color: Color(0xFF8E6267),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1))),
          Padding(padding: const EdgeInsets.all(16), child: _grid(items)),
        ]),
      );

  Widget _fieldCaption(String text,
          {bool required = false, bool auto = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Flexible(
                child: Text('$text${required ? ' *' : ''}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600))),
            if (auto)
              const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.auto_fix_high, size: 13, color: _rose)),
          ]));

  InputDecoration _deco(
          {String? hint, Widget? suffix, bool readOnly = false}) =>
      InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: readOnly ? const Color(0xFFF2EFED) : const Color(0xFFFAF9F7),
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDD5D1))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDD5D1))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _rose, width: 1.6)),
      );

  /// Um campo da ficha conforme o tipo (texto, número, data, hora, sim/não, lista…).
  Widget _input(String key, String label, String type,
      {bool required = false,
      String? hint,
      String auto = '',
      List<String> options = const []}) {
    final readOnly = auto == 'sequence' || auto == 'on_save';
    final isNew = (widget.eventId ?? 0) == 0;
    if (type == 'checkbox') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _fieldCaption(label, required: required),
        Container(
            decoration: BoxDecoration(
                color: const Color(0xFFFAF9F7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDDD5D1))),
            child: CheckboxListTile(
                dense: true,
                value: _checks[key] ?? false,
                activeColor: _rose,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text((_checks[key] ?? false) ? 'Sim' : 'Não'),
                onChanged: _saving
                    ? null
                    : (v) {
                        setState(() => _checks[key] = v ?? false);
                        _touched();
                      })),
      ]);
    }
    final controller = _c(key);
    Widget field;
    if (readOnly) {
      field = TextField(
          controller: controller,
          readOnly: true,
          decoration: _deco(
              readOnly: true,
              hint: auto == 'on_save' || (isNew && controller.text.isEmpty)
                  ? 'Atribuído ao guardar'
                  : null));
    } else if (type == 'select') {
      final value = options.contains(controller.text) ? controller.text : null;
      field = DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          decoration: _deco(hint: hint),
          items: options
              .map((o) => DropdownMenuItem(
                  value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: _saving
              ? null
              : (v) => setState(() => controller.text = v ?? ''));
    } else if (type == 'date' || type == 'time') {
      field = TextField(
          controller: controller,
          readOnly: true,
          decoration: _deco(
              hint: hint ?? (type == 'date' ? 'AAAA-MM-DD' : 'HH:MM'),
              suffix: Icon(
                  type == 'date'
                      ? Icons.calendar_today_outlined
                      : Icons.schedule,
                  size: 18,
                  color: _muted)),
          onTap: _saving
              ? null
              : () async {
                  if (type == 'date') {
                    final current =
                        DateTime.tryParse(controller.text) ?? DateTime.now();
                    final picked = await showDatePicker(
                        context: context,
                        initialDate: current,
                        firstDate: DateTime(1990),
                        lastDate: DateTime(2100));
                    if (picked != null)
                      controller.text =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  } else {
                    final m = RegExp(r'^(\d{1,2}):(\d{2})')
                        .firstMatch(controller.text);
                    final picked = await showTimePicker(
                        context: context,
                        initialTime: m == null
                            ? const TimeOfDay(hour: 10, minute: 0)
                            : TimeOfDay(
                                hour: int.parse(m.group(1)!),
                                minute: int.parse(m.group(2)!)),
                        builder: (context, child) => MediaQuery(
                            data: MediaQuery.of(context)
                                .copyWith(alwaysUse24HourFormat: true),
                            child: child!));
                    if (picked != null)
                      controller.text =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                  }
                });
    } else {
      field = TextField(
          controller: controller,
          enabled: !_saving,
          maxLines: type == 'textarea' ? 4 : 1,
          keyboardType: type == 'number'
              ? const TextInputType.numberWithOptions(decimal: true)
              : type == 'email'
                  ? TextInputType.emailAddress
                  : TextInputType.text,
          decoration: type == 'team'
              ? _deco(
                  hint: (hint ?? '').isEmpty
                      ? 'Ex.: LM não trocar + MB + FB'
                      : hint,
                  suffix: const Icon(Icons.groups_outlined,
                      size: 18, color: _muted))
              : _deco(hint: hint));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _fieldCaption(label, required: required, auto: auto.isNotEmpty),
      field
    ]);
  }

  bool get _quick {
    final event = _event ?? const <String, dynamic>{};
    if ((widget.eventId ?? 0) <= 0 ||
        '${event['event_type'] ?? ''}' != 'outros') return false;
    final meta =
        event['event_meta'] is Map ? event['event_meta'] as Map : const {};
    if (meta['agendamento_rapido'] == true) return true;
    final tpl = _templates.where((t) => '${t['slug']}' == 'outros').firstOrNull;
    final keys = (tpl?['fields'] is List ? tpl!['fields'] as List : const [])
        .whereType<Map>()
        .where((f) => f['source'] != 'event')
        .map((f) => '${f['key']}');
    return keys.every((k) => '${meta[k] ?? ''}'.trim().isEmpty);
  }

  Widget _quickForm() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_formError != null)
          Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFBEAEA),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(_formError!,
                  style: const TextStyle(color: Color(0xFFB3261E)))),
        _box('Agendamento', [
          ('full', _input('name', 'Nome', 'text', required: true)),
          ('third', _input('event_date', 'Data', 'date', required: true)),
          ('third', _input('event_time', 'Início', 'time', required: true)),
          ('third', _input('event_end_time', 'Fim', 'time')),
          ('full', _input('location', 'Local de encontro', 'text')),
          ('full', _input('notes', 'Notas', 'textarea')),
          (
            'half',
            _input('estrangeiro', 'Estrangeiro', 'select',
                options: const ['Não', 'Sim'])
          ),
        ]),
      ]);

  Future<void> _publishQuick() async {
    final date = DateTime.tryParse(_c('event_date').text.trim());
    if (_c('name').text.trim().isEmpty) {
      setState(() => _formError = 'Indique o nome.');
      return;
    }
    if (date == null) {
      setState(() => _formError = 'Indique a data.');
      return;
    }
    if (_c('event_time').text.trim().isEmpty) {
      setState(() => _formError = 'Indique a hora de início.');
      return;
    }
    final event = _event ?? <String, dynamic>{};
    final meta = event['event_meta'] is Map
        ? Map<String, dynamic>.from(event['event_meta'] as Map)
        : <String, dynamic>{};
    meta['agendamento_rapido'] = true;
    meta['estrangeiro'] = _c('estrangeiro').text == 'Sim';
    final payload = <String, dynamic>{
      'event_type': 'outros',
      'name': _c('name').text.trim(),
      'event_date': _c('event_date').text.trim(),
      'event_time': _c('event_time').text.trim(),
      'event_end_time': _c('event_end_time').text.trim(),
      'location': _c('location').text.trim(),
      'notes': _c('notes').text.trim(),
      'base_price': event['base_price'] ?? 0,
      'price_per_photo': event['price_per_photo'] ?? 5,
      'event_meta': meta,
    };
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      final response = await http
          .put(
              Uri.parse(
                  'https://studio59.wiredevelop.pt/api/events/${widget.eventId}'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_token'
              },
              body: jsonEncode(payload))
          .timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = '';
        try {
          final body = jsonDecode(response.body);
          if (body is Map) message = '${body['message'] ?? ''}';
        } catch (_) {}
        throw StateError(message.isEmpty
            ? 'Não foi possível guardar (${response.statusCode}).'
            : message);
      }
      await _clearDraft();
      _dirty = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agendamento atualizado.')));
      setState(() {
        _editing = false;
        _saving = false;
      });
      _load();
    } catch (error) {
      if (mounted)
        setState(() {
          _saving = false;
          _formError = error is StateError
              ? error.message.toString()
              : 'Não foi possível contactar o servidor.';
        });
    }
  }

  Widget _fichaForm() {
    if (_quick) return _quickForm();
    final sections = <String, List<Map<String, dynamic>>>{};
    for (final f in _templateFields) {
      if (const {
        'name',
        'event_date',
        'event_time',
        'event_end_time',
        'location',
        'city',
        'address',
        'notes',
        'base_price',
        'price_per_photo',
        'report_number',
        'estrangeiro'
      }.contains('${f['key']}')) continue;
      sections
          .putIfAbsent(
              '${f['section'] ?? ''}'.trim().isEmpty
                  ? 'Geral'
                  : '${f['section']}',
              () => [])
          .add(f);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_formError != null)
        Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFFBEAEA),
                borderRadius: BorderRadius.circular(12)),
            child: Text(_formError!,
                style: const TextStyle(color: Color(0xFFB3261E)))),
      _box('Serviço', [
        (
          'half',
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _fieldCaption('Tipo de serviço', required: true),
            DropdownButtonFormField<String>(
                value: _templates.any((t) => '${t['slug']}' == _formType)
                    ? _formType
                    : null,
                isExpanded: true,
                isDense: true,
                decoration: _deco(),
                items: _templates
                    .map((t) => DropdownMenuItem(
                        value: '${t['slug']}',
                        child: Text('${t['name'] ?? t['slug']}')))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) {
                        setState(() => _formType = v ?? '');
                        _touched();
                        if ((widget.eventId ?? 0) == 0) {
                          _startTemplateDefaults();
                          _loadNextNumbers();
                        }
                      }),
          ])
        ),
        (
          'half',
          _input('report_number', 'Nº do serviço', 'number', auto: 'sequence')
        ),
        ('half', _input('event_date', 'Data', 'date', required: true)),
        (
          'half',
          _input('estrangeiro', 'Estrangeiro', 'select',
              options: const ['Não', 'Sim'])
        ),
        (
          'half',
          _input('base_price', 'Preço base (€)', 'number', required: true)
        ),
        (
          'half',
          _input('price_per_photo', 'Preço por fotografia (€)', 'number',
              required: true)
        ),
      ]),
      _servicesBox(),
      for (final entry in sections.entries)
        _box(entry.key, [
          for (final f in entry.value)
            if ('${f['key']}' == _teamKey)
              ('full', _teamsEditor('${f['label'] ?? 'Equipa'}'))
            else
              (
                '${f['width'] ?? 'full'}',
                _input('${f['key']}', '${f['label'] ?? f['key']}',
                    '${f['type'] ?? 'text'}',
                    required: f['required'] == true,
                    hint:
                        f['placeholder'] == null ? null : '${f['placeholder']}',
                    auto: '${f['auto'] ?? ''}',
                    options: f['options'] is List
                        ? (f['options'] as List)
                            .map((o) =>
                                o is Map ? '${o['label'] ?? o['value']}' : '$o')
                            .toList()
                        : const [])
              ),
        ]),
      _box('Notas', [('full', _input('notes', 'Notas internas', 'textarea'))]),
    ]);
  }

  void _startTemplateDefaults() {
    for (final f in _templateFields) {
      final key = '${f['key']}';
      if (f['type'] == 'checkbox') {
        _checks.putIfAbsent(key, () => false);
        continue;
      }
      final c = _c(key);
      if (c.text.isNotEmpty) continue;
      switch ('${f['auto'] ?? ''}') {
        case 'today':
          c.text = _today();
          break;
        case 'now':
          c.text = _nowTime();
          break;
        case 'user':
          c.text = _userName;
          break;
      }
    }
  }

  Widget _editBar() => Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFECE7E3)))),
        child: SafeArea(
            top: false,
            child: Row(children: [
              Icon(
                  _draftSavedAt == null
                      ? Icons.edit_note
                      : Icons.cloud_done_outlined,
                  size: 18,
                  color: _muted),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(
                      _draftSavedAt == null
                          ? 'Rascunho: as alterações são guardadas automaticamente neste dispositivo.'
                          : 'Rascunho guardado às ${_draftSavedAt!.hour.toString().padLeft(2, '0')}:${_draftSavedAt!.minute.toString().padLeft(2, '0')}:${_draftSavedAt!.second.toString().padLeft(2, '0')} · ainda não publicado',
                      style: const TextStyle(color: _muted, fontSize: 12))),
              TextButton(
                  onPressed: _saving ? null : _cancelEdit,
                  child: const Text('Fechar', style: TextStyle(color: _muted))),
              const SizedBox(width: 8),
              FilledButton.icon(
                  onPressed: _saving ? null : _publish,
                  style: FilledButton.styleFrom(backgroundColor: _rose),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.publish, size: 18),
                  label: Text((widget.eventId ?? 0) == 0
                      ? 'Guardar e publicar'
                      : 'Guardar alterações')),
            ])),
      );

  Future<void> _deleteEvent() async {
    final id = widget.eventId;
    if (!_isAdmin || id == null || id <= 0) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Cancelar este serviço?'),
                content: const Text(
                    'Esta ação cancela o serviço e as atribuições da equipa.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Voltar')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Cancelar serviço'))
                ]));
    if (confirmed != true) return;
    final client = http.Client();
    try {
      final response = await client.delete(
          Uri.parse('https://studio59.wiredevelop.pt/api/events/$id'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $_token'
          }).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw StateError(
            'Não foi possível cancelar o serviço (${response.statusCode}).');
      if (mounted) context.pop();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is StateError
                ? error.message.toString()
                : 'Não foi possível contactar o servidor.')));
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _event ?? <String, dynamic>{};
    final meta = event['event_meta'] is Map
        ? Map<String, dynamic>.from(event['event_meta'] as Map)
        : <String, dynamic>{};
    final type = _templates
        .where((t) => '${t['slug']}' == '${event['event_type']}')
        .firstOrNull;
    // Só a informação útil no dia: campos do template, pelos separadores do template.
    // Fora: números internos de cliente, dados antigos importados (Facebook/Residência) e restantes campos técnicos.
    final hidden =
        RegExp(r'^cliente_.*_num$|facebook|resid', caseSensitive: false);
    dynamic valueOf(String key) =>
        meta.containsKey(key) ? meta[key] : event[key];
    bool filled(dynamic v) =>
        v != null && v is! Map && v is! List && v.toString().trim().isNotEmpty;
    final templateFields =
        (type?['fields'] is List ? type!['fields'] as List : const [])
            .whereType<Map>()
            .map((f) => Map<String, dynamic>.from(f))
            .toList();
    final groups = <String, List<MapEntry<String, dynamic>>>{};
    groups['Serviço'] = [
      if (filled(event['location']) && templateFields.isEmpty)
        MapEntry('location', event['location']),
      if (meta['estrangeiro'] == true) const MapEntry('estrangeiro', 'Sim'),
    ];
    if (groups['Serviço']!.isEmpty) groups.remove('Serviço');
    if (templateFields.isNotEmpty) {
      for (final f in templateFields) {
        final key = '${f['key']}';
        if (hidden.hasMatch(key) ||
            const {
              'name',
              'event_date',
              'event_time',
              'event_end_time',
              'location',
              'city',
              'address',
              'notes',
              'base_price',
              'price_per_photo',
              'report_number',
              'estrangeiro'
            }.contains(key)) continue;
        var value = valueOf(key);
        if ('${f['type']}' == 'checkbox') {
          final on = value == true ||
              const {'1', 'true', 'sim', 'x', 'yes'}
                  .contains('$value'.trim().toLowerCase());
          if (!on) continue;
          value = 'Sim';
        }
        if (!filled(value)) continue;
        final section = '${f['section'] ?? ''}'.trim().isEmpty
            ? 'Geral'
            : '${f['section']}'.trim();
        groups.putIfAbsent(section, () => []).add(MapEntry(key, value));
      }
    } else {
      // Tipos antigos sem template: agrupamento por nome, sem a secção «Outros».
      for (final e in meta.entries) {
        if (!filled(e.value) || hidden.hasMatch(e.key)) continue;
        final group = _groupFor(e.key);
        if (group == 'Outros') continue;
        groups.putIfAbsent(group, () => []).add(e);
      }
    }
    if (filled(event['notes']))
      groups['Observações'] = [MapEntry('notes', event['notes'])];
    // O que é preciso no dia vem primeiro; o resto fica em «Ver ficha completa».
    final dayHours = <MapEntry<String, dynamic>>[];
    final dayPlaces = <MapEntry<String, dynamic>>[];
    final dayContacts = <MapEntry<String, dynamic>>[];
    dynamic teamText;
    final fieldTypes = {
      for (final f in templateFields) '${f['key']}': '${f['type'] ?? ''}'
    };
    final rest = <String, List<MapEntry<String, dynamic>>>{};
    final technical = <String, List<MapEntry<String, dynamic>>>{};
    groups.forEach((section, entries) {
      if (section == 'Filmador' || section == 'Fotógrafo') {
        technical[section] = entries;
        return;
      }
      for (final e in entries) {
        final key = e.key.toLowerCase();
        if (fieldTypes[e.key] == 'team' || key == 'equipa_de_trabalho') {
          teamText = e.value;
        } else if (fieldTypes[e.key] == 'time' ||
            RegExp(r'hora|missa').hasMatch(key)) {
          dayHours.add(e);
        } else if (_isPhone(key)) {
          dayContacts.add(e);
        } else if (RegExp(
                r'local|igreja|quinta|morada|coorden|cerimonia|almoco|location')
            .hasMatch(key)) {
          dayPlaces.add(e);
        } else {
          rest.putIfAbsent(section, () => []).add(e);
        }
      }
    });
    List<dynamic> teamRows = const [];
    try {
      teamRows = jsonDecode('${meta['equipas_json'] ?? '[]'}') as List;
    } catch (_) {}
    final clientNames = [
      for (final k in (type?['settings'] is Map &&
              (type!['settings'] as Map)['name_fields'] is List
          ? (type['settings'] as Map)['name_fields'] as List
          : const []))
        if (filled(meta['$k'])) '${meta['$k']}',
    ].join(' & ');
    Widget dayBlock(String title, List<MapEntry<String, dynamic>> entries) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: Color(0xFF292624),
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _grid([for (final e in entries) ('half', _infoCard(e.key, e.value))]),
        ]);
    final details = <Widget>[
      Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
              color: const Color(0xFFF2E5E3),
              borderRadius: BorderRadius.circular(22)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${type?['name'] ?? event['event_type'] ?? 'Serviço'}'
                    .toUpperCase(),
                style: const TextStyle(
                    color: Color(0xFF8E6267),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 9),
            Text(
                '${event['name'] ?? (widget.eventId == 0 ? 'Novo serviço' : 'Serviço')}',
                style: const TextStyle(
                    color: Color(0xFF292624),
                    fontSize: 23,
                    fontWeight: FontWeight.w700)),
            if (clientNames.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(clientNames,
                      style: const TextStyle(
                          color: Color(0xFF292624),
                          fontSize: 16,
                          fontWeight: FontWeight.w500))),
            if (event['event_date'] != null)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                      [
                        '${event['event_date']}'.split('T').first,
                        if (filled(event['event_time']))
                          [
                            '${event['event_time']}'.substring(
                                0,
                                '${event['event_time']}'.length >= 5
                                    ? 5
                                    : '${event['event_time']}'.length),
                            if (filled(event['event_end_time']))
                              '${event['event_end_time']}'.substring(
                                  0,
                                  '${event['event_end_time']}'.length >= 5
                                      ? 5
                                      : '${event['event_end_time']}'.length),
                          ].join('–'),
                      ].join(' · '),
                      style: const TextStyle(
                          color: Color(0xFF6D625F), fontSize: 15))),
          ])),
      if ('${event['access_pin'] ?? ''}'.trim().isNotEmpty ||
          '${event['qr_token'] ?? ''}'.trim().isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFECE7E3))),
          child: Wrap(
              spacing: 24,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Acesso dos convidados',
                          style: TextStyle(
                              color: Color(0xFF292624),
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('PIN do catálogo',
                          style: TextStyle(color: Color(0xFF6D625F))),
                      SelectableText('${event['access_pin'] ?? '—'}',
                          style: const TextStyle(
                              color: Color(0xFF292624),
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 8)),
                      const Text(
                          'Os convidados entram com este PIN ou lendo o QR.',
                          style: TextStyle(
                              color: Color(0xFF6D625F), fontSize: 12)),
                    ]),
                if ('${event['qr_token'] ?? ''}'.trim().isNotEmpty)
                  Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(6),
                      child: QrImageView(
                          data:
                              'https://studio59.wiredevelop.pt/api/public/events/qr/${event['qr_token']}',
                          size: 170,
                          backgroundColor: Colors.white)),
              ]),
        ),
      if (widget.eventId == 0 && _canEdit)
        FilledButton(
            onPressed: _startEdit,
            style: FilledButton.styleFrom(backgroundColor: _rose),
            child: const Text('Preencher ficha')),
      if (dayHours.isNotEmpty) dayBlock('Horários', dayHours),
      if (dayPlaces.isNotEmpty) dayBlock('Locais', dayPlaces),
      if (filled(teamText) || _staff.isNotEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 16),
          const Text('Equipa',
              style: TextStyle(
                  color: Color(0xFF292624),
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        filled(teamText)
                            ? '$teamText'
                            : _staff
                                .map((m) =>
                                    '${m['user'] is Map ? (m['user'] as Map)['name'] : m['name']}')
                                .join(' + '),
                        style: const TextStyle(
                            color: Color(0xFF292624),
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    for (final row in teamRows.whereType<Map>())
                      if ('${row['hora'] ?? ''}'.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                                '${row['membros'] ?? ''}${'${row['destino'] ?? ''}'.isEmpty ? '' : ' · ${row['destino']}'} · na loja às ${row['hora']}',
                                style:
                                    const TextStyle(color: Color(0xFF6D625F)))),
                  ])),
        ]),
      if (dayContacts.isNotEmpty) dayBlock('Contactos', dayContacts),
      for (final group in technical.entries) dayBlock(group.key, group.value),
      if ('${event['access_pin'] ?? ''}'.trim().isNotEmpty ||
          '${event['qr_token'] ?? ''}'.trim().isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFECE7E3))),
          child: Wrap(
              spacing: 24,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Acesso dos convidados',
                          style: TextStyle(
                              color: Color(0xFF292624),
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('PIN do catálogo',
                          style: TextStyle(color: Color(0xFF6D625F))),
                      SelectableText('${event['access_pin'] ?? '—'}',
                          style: const TextStyle(
                              color: Color(0xFF292624),
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 8)),
                      const Text(
                          'Os convidados entram com este PIN ou lendo o QR.',
                          style: TextStyle(
                              color: Color(0xFF6D625F), fontSize: 12)),
                    ]),
                if ('${event['qr_token'] ?? ''}'.trim().isNotEmpty)
                  Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(6),
                      child: QrImageView(
                          data:
                              'https://studio59.wiredevelop.pt/api/public/events/qr/${event['qr_token']}',
                          size: 170,
                          backgroundColor: Colors.white)),
              ]),
        ),
      const SizedBox(height: 10),
      Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              title: const Text('Ver ficha completa',
                  style: TextStyle(
                      color: Color(0xFF8E6267),
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              children: [
                for (final group in rest.entries)
                  if (group.value.isNotEmpty) _section(group.key, group.value),
                _servicesView(event),
                if (_staff.isNotEmpty ||
                    (_isAdmin && (widget.eventId ?? 0) > 0)) ...[
                  const SizedBox(height: 18),
                  const Text('Fotógrafos atribuídos',
                      style: TextStyle(
                          color: Color(0xFF292624),
                          fontSize: 19,
                          fontWeight: FontWeight.w600)),
                  for (final member in _staff)
                    Row(children: [
                      Expanded(
                          child: _line(
                              'Fotógrafo',
                              member['user'] is Map
                                  ? (member['user'] as Map)['name']
                                  : member['name'])),
                      if (_isAdmin)
                        IconButton(
                            onPressed: () => _removeStaff(member),
                            icon: const Icon(Icons.remove_circle_outline),
                            tooltip: 'Remover fotógrafo'),
                    ]),
                  if (_isAdmin)
                    TextButton.icon(
                        onPressed: _addStaff,
                        icon: const Icon(Icons.add),
                        label: const Text('Atribuir fotógrafo')),
                ],
              ])),
      if ((widget.eventId ?? 0) > 0) _postEventNotes(),
    ];
    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center)))
            : SingleChildScrollView(
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: _editing
                                ? _fichaForm()
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: details)))));
    return SizedBox(
        width: widget.width,
        height: widget.height,
        child: ColoredBox(
            color: const Color(0xFFFAF9F7),
            child: SafeArea(
                child: Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 20, 8),
                  child: Row(children: [
                    IconButton(
                        onPressed: _editing ? _cancelEdit : () => context.pop(),
                        icon: const Icon(Icons.arrow_back,
                            color: Color(0xFF292624))),
                    Expanded(
                        child: Text(
                            _editing
                                ? ((widget.eventId ?? 0) == 0
                                    ? 'Novo serviço'
                                    : 'Editar ficha do serviço')
                                : 'Ficha do serviço',
                            style: const TextStyle(
                                color: Color(0xFF292624),
                                fontSize: 21,
                                fontWeight: FontWeight.w700))),
                    if (_canEdit && !_editing && (widget.eventId ?? 0) > 0)
                      FilledButton.icon(
                          onPressed: _startEdit,
                          style: FilledButton.styleFrom(backgroundColor: _rose),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Editar ficha')),
                    if (_canPrintSheets &&
                        (widget.eventId ?? 0) > 0 &&
                        !_editing)
                      Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: MediaQuery.sizeOf(context).width < 700
                              ? IconButton(
                                  onPressed: _openPrintDialog,
                                  tooltip: 'Imprimir fichas',
                                  icon: const Icon(Icons.print_outlined,
                                      color: Color(0xFFB77F84)))
                              : OutlinedButton.icon(
                                  onPressed: _openPrintDialog,
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFB77F84),
                                      side: const BorderSide(
                                          color: Color(0xFFB77F84))),
                                  icon: const Icon(Icons.print_outlined,
                                      size: 18),
                                  label: const Text('Imprimir'))),
                    if (_isAdmin && (widget.eventId ?? 0) > 0 && !_editing)
                      Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => Scaffold(
                                          backgroundColor:
                                              const Color(0xFFFAF9F7),
                                          body: SafeArea(
                                              child: Studio59EventDossier(
                                                  eventId: widget.eventId))))),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFB77F84),
                                  side: const BorderSide(
                                      color: Color(0xFFB77F84))),
                              icon: const Icon(Icons.folder_open_outlined,
                                  size: 18),
                              label: const Text('Dossier'))),
                    if (_isAdmin && (widget.eventId ?? 0) > 0)
                      IconButton(
                          onPressed: _deleteEvent,
                          tooltip: 'Cancelar serviço',
                          icon: const Icon(Icons.delete_outline,
                              color: Color(0xFF292624))),
                    IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh,
                            color: Color(0xFF292624))),
                  ])),
              Expanded(child: content),
              if (_editing && !_loading) _editBar(),
            ]))));
  }
}
