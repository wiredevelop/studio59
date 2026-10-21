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
    final payload = <String, dynamic>{
      'event_type': _formType,
      'event_date': _c('event_date').text.trim(),
      'base_price': base,
      'price_per_photo': photo,
      'event_time': _c('event_time').text.trim(),
      'event_end_time': _c('event_end_time').text.trim(),
      'location': _c('location').text.trim(),
      'city': _c('city').text.trim(),
      'address': _c('address').text.trim(),
      'notes': _c('notes').text.trim(),
      if (_c('name').text.trim().isNotEmpty) 'name': _c('name').text.trim(),
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
          decoration: _deco(hint: hint));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _fieldCaption(label, required: required, auto: auto.isNotEmpty),
      field
    ]);
  }

  Widget _fichaForm() {
    final sections = <String, List<Map<String, dynamic>>>{};
    for (final f in _templateFields) {
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
        (
          'full',
          _input('name', 'Nome do serviço', 'text',
              hint: 'Gerado a partir dos campos da ficha se ficar vazio')
        ),
        ('third', _input('event_date', 'Data', 'date', required: true)),
        ('third', _input('event_time', 'Hora de início', 'time')),
        ('third', _input('event_end_time', 'Hora de fim', 'time')),
        ('half', _input('location', 'Local', 'text')),
        ('half', _input('city', 'Cidade', 'text')),
        ('full', _input('address', 'Morada', 'text')),
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
      for (final entry in sections.entries)
        _box(entry.key, [
          for (final f in entry.value)
            (
              '${f['width'] ?? 'full'}',
              _input('${f['key']}', '${f['label'] ?? f['key']}',
                  '${f['type'] ?? 'text'}',
                  required: f['required'] == true,
                  hint: f['placeholder'] == null ? null : '${f['placeholder']}',
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
    final all = <MapEntry<String, dynamic>>[
      ...event.entries.where((e) => !const {
            'name',
            'event_meta',
            'qr_token',
            'access_pin'
          }.contains(e.key)),
      ...meta.entries,
    ]
        .where((e) =>
            e.value != null &&
            e.value.toString().trim().isNotEmpty &&
            e.value is! Map &&
            e.value is! List)
        // Campos retirados da ficha (dados antigos importados): Facebook e Residência após casamento.
        .where((e) =>
            !RegExp(r'facebook|resid', caseSensitive: false).hasMatch(e.key))
        .toList();
    final groups = <String, List<MapEntry<String, dynamic>>>{
      'Noivo': [],
      'Noiva': [],
      'Igreja': [],
      'Quinta': [],
      'Serviço': [],
      'Outros': [],
    };
    for (final field in all) {
      groups[_groupFor(field.key)]!.add(field);
    }
    final type = _templates
        .where((t) => '${t['slug']}' == '${event['event_type']}')
        .firstOrNull;
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
            if (event['event_date'] != null)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                      '${event['event_date']}${event['event_time'] == null ? '' : ' · ${event['event_time']}'}',
                      style: const TextStyle(
                          color: Color(0xFF6D625F), fontSize: 15))),
          ])),
      if (widget.eventId == 0 && _canEdit)
        FilledButton(
            onPressed: _startEdit,
            style: FilledButton.styleFrom(backgroundColor: _rose),
            child: const Text('Preencher ficha')),
      for (final group in groups.entries)
        if (group.value.isNotEmpty) _section(group.key, group.value),
      if (_staff.isNotEmpty || (_isAdmin && (widget.eventId ?? 0) > 0)) ...[
        const SizedBox(height: 18),
        const Text('Equipa',
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
