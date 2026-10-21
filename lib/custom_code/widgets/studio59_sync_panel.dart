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
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class Studio59SyncPanel extends StatefulWidget {
  const Studio59SyncPanel({super.key, this.width, this.height});
  final double? width;
  final double? height;
  @override
  State<Studio59SyncPanel> createState() => _Studio59SyncPanelState();
}

class _Studio59SyncPanelState extends State<Studio59SyncPanel> {
  static const _base = 'https://studio59.wiredevelop.pt/api';
  static const _rose = Color(0xFFB77F84);
  static const _roseSoft = Color(0xFFF2E5E3);
  static const _ink = Color(0xFF292624);
  static const _muted = Color(0xFF6D625F);
  static const _line = Color(0xFFECE7E3);
  static const _danger = Color(0xFF9B3D3D);
  static const _months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro'
  ];
  static const _progressFile = 'studio59_sincronizacao.json';

  String _token = '';
  Map<String, dynamic> _user = {};
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _loadError;
  int? _year;
  int? _month;
  int? _day;
  int? _eventId;

  String? _folder;
  List<File> _files = [];
  File? _jsonFile;
  Map<String, dynamic>? _payload;
  String _payloadHash = '';
  Map<String, dynamic>? _previous;

  bool _busy = false;
  int _doneBatches = 0;
  int _totalBatches = 0;
  String _step = '';
  String? _error;
  Map<String, dynamic>? _result;

  bool get _desktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};
  List<Map<String, dynamic>> _rows(Map<String, dynamic> body) {
    final data = body['data'];
    final list = data is List
        ? data
        : data is Map
            ? data['data']
            : null;
    return list is List
        ? list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : [];
  }

  String _apiError(http.Response response) {
    String message = '';
    try {
      message = '${_map(jsonDecode(response.body))['message'] ?? ''}';
    } catch (_) {}
    if (response.statusCode == 401)
      return 'A sessão expirou. Inicie sessão novamente.';
    if (response.statusCode == 403)
      return 'O servidor não autorizou a importação (403). O seu utilizador precisa da permissão offline.import ou de estar atribuído a este serviço.';
    if (response.statusCode == 413)
      return 'Ficheiro demasiado grande para o servidor (413).';
    return message.isEmpty
        ? 'Erro do servidor (${response.statusCode}).'
        : '$message (${response.statusCode})';
  }

  DateTime? _date(Map<String, dynamic> event) =>
      DateTime.tryParse('${event['event_date'] ?? ''}');
  String _sep() => Platform.pathSeparator;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final client = http.Client();
    try {
      _token = (await const FlutterSecureStorage()
                  .read(key: 'studio59_staff_token') ??
              '')
          .trim();
      if (_token.isEmpty) throw StateError('Inicie sessão para sincronizar.');
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token'
      };
      final me = await client
          .get(Uri.parse('$_base/auth/me'), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (me.statusCode != 200) throw StateError(_apiError(me));
      final meBody = _map(jsonDecode(me.body));
      final meData = meBody['data'] is Map ? _map(meBody['data']) : meBody;
      _user = meData['user'] is Map ? _map(meData['user']) : meData;
      final events = <Map<String, dynamic>>[];
      var page = 1;
      var last = 1;
      final assignedOnly = !const {
        'admin',
        'administrator',
        'backoffice',
        'receptionist',
        'rececionista'
      }.contains('${_user['role']}'.toLowerCase());
      do {
        final response = await client
            .get(
                Uri.parse(
                    '$_base/events?page=$page&per_page=200${assignedOnly ? '&assigned_only=1' : ''}'),
                headers: headers)
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) throw StateError(_apiError(response));
        final body = _map(jsonDecode(response.body));
        events.addAll(_rows(body));
        final nested = body['data'] is Map ? _map(body['data']) : body;
        last =
            int.tryParse('${nested['last_page'] ?? body['last_page'] ?? 1}') ??
                1;
        page++;
      } while (page <= last && page <= 100);
      final role = '${_user['role']}'.toLowerCase();
      // Fotógrafos: apenas serviços em que estão atribuídos (o servidor já filtra; aqui reforça-se quando a ficha traz a equipa).
      final userId = int.tryParse('${_user['id']}');
      final visible = role == 'admin' || role == 'administrator'
          ? events
          : events.where((event) {
              final staff =
                  event['staff'] ?? event['staff_members'] ?? event['team'];
              if (staff is! List || userId == null) return true;
              return staff.whereType<Map>().any((m) =>
                  int.tryParse(
                      '${m['user_id'] ?? _map(m['user'])['id'] ?? m['id']}') ==
                  userId);
            }).toList();
      if (mounted)
        setState(() {
          _events = visible;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _loadError = e is StateError
              ? e.message.toString()
              : 'Não foi possível contactar o servidor.';
          _loading = false;
        });
    } finally {
      client.close();
    }
  }

  Map<String, dynamic>? get _event =>
      _events.where((e) => int.tryParse('${e['id']}') == _eventId).firstOrNull;

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform
        .getDirectoryPath(dialogTitle: 'Selecione a pasta provas');
    if (path == null) return;
    setState(() {
      _folder = path;
      _files = [];
      _error = null;
      _result = null;
    });
    final folder = Directory(path);
    final files = <File>[];
    await for (final entity
        in folder.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = entity.path.substring(path.length + 1);
      if (relative.split(RegExp(r'[\\/]')).any((part) => part.startsWith('.')))
        continue;
      final lower = relative.toLowerCase();
      if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) files.add(entity);
    }
    files.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    Map<String, dynamic>? previous;
    final progress = File('$path${_sep()}$_progressFile');
    if (await progress.exists()) {
      try {
        previous = _map(jsonDecode(await progress.readAsString()));
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _files = files;
      _previous = previous;
    });
    final auto = File('$path${_sep()}studio59_sessao_offline.json');
    if (_jsonFile == null && await auto.exists()) await _useJson(auto);
  }

  Future<void> _pickJson() async {
    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
        initialDirectory: _folder);
    final path = picked?.files.single.path;
    if (path == null) return;
    await _useJson(File(path));
  }

  Future<void> _useJson(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final payload = jsonDecode(utf8.decode(bytes));
      if (payload is! Map ||
          payload['orders'] is! List ||
          payload['photos'] is! List) {
        throw const FormatException(
            'O ficheiro não é um registo de sessão offline (faltam photos/orders).');
      }
      if (!mounted) return;
      setState(() {
        _jsonFile = file;
        _payload = Map<String, dynamic>.from(payload);
        _payloadHash = sha256.convert(bytes).toString();
        _error = null;
        _result = null;
        final date = DateTime.tryParse(
            '${_map(payload['event'])['event_date'] ?? _map(payload['session'])['event_date'] ?? ''}');
        if (date != null && _eventId == null) {
          final match = _events.where((e) {
            final d = _date(e);
            return d != null &&
                d.year == date.year &&
                d.month == date.month &&
                d.day == date.day;
          }).toList();
          if (match.isNotEmpty) {
            _year = date.year;
            _month = date.month;
            _day = date.day;
            if (match.length == 1)
              _eventId = int.tryParse('${match.first['id']}');
          }
        }
      });
    } catch (e) {
      if (mounted)
        setState(() => _error = e is FormatException
            ? e.message
            : 'Não foi possível ler o ficheiro JSON.');
    }
  }

  String _relative(File file) =>
      file.path.substring(_folder!.length + 1).replaceAll('\\', '/');

  /// Fotografias a enviar: as do JSON que existem na pasta (por caminho relativo ou nome).
  List<(File, Map<String, dynamic>)> get _uploads {
    final payload = _payload;
    if (payload == null || _folder == null) return [];
    final byPath = {for (final f in _files) _relative(f).toLowerCase(): f};
    final byName = {
      for (final f in _files) _relative(f).split('/').last.toLowerCase(): f
    };
    final result = <(File, Map<String, dynamic>)>[];
    for (final raw in payload['photos'] as List) {
      final photo = _map(raw);
      final path = '${photo['original_path'] ?? photo['filename'] ?? ''}'
          .replaceAll('\\', '/')
          .toLowerCase();
      final file = byPath[path] ?? byName[path.split('/').last];
      if (file != null)
        result.add((
          file,
          {
            'id': photo['id'],
            'number': photo['number'],
            'original_path': photo['original_path'] ?? _relative(file)
          }
        ));
    }
    return result;
  }

  List<String> get _missing {
    final payload = _payload;
    if (payload == null || _folder == null) return [];
    final found = _uploads.map((u) => '${u.$2['original_path']}').toSet();
    return (payload['photos'] as List)
        .map(_map)
        .map((p) => '${p['original_path'] ?? p['filename']}')
        .where((p) => !found.contains(p))
        .toList();
  }

  int _cents(dynamic value) {
    final match =
        RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch('${value ?? ''}'.trim());
    if (match == null) return 0;
    return int.parse(match.group(1)!) * 100 +
        int.parse((match.group(2) ?? '0').padRight(2, '0'));
  }

  String _money(int cents) =>
      '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')} €';

  Map<String, int> get _summary {
    final orders =
        (_payload?['orders'] as List? ?? const []).map(_map).toList();
    var total = 0,
        received = 0,
        due = 0,
        debts = 0,
        paid = 0,
        pending = 0,
        change = 0,
        emails = 0;
    for (final o in orders) {
      total += _cents(o['total_amount']);
      received += _cents(o['cash_received_amount']);
      final d = _cents(o['cash_due_amount']);
      due += d;
      final c = _cents(o['cash_change_amount']);
      if (c > 0 && o['cash_change_given'] != true) change++;
      final isPaid =
          (o['status'] == 'paid' || o['status'] == 'delivered') && d == 0;
      if (d > 0)
        debts++;
      else if (isPaid)
        paid++;
      else
        pending++;
      if (isPaid &&
          (o['product_type'] == 'digital' || o['product_type'] == 'both') &&
          '${o['customer_email'] ?? ''}'.contains('@')) emails++;
    }
    return {
      'orders': orders.length,
      'total': total,
      'received': received,
      'due': due,
      'debts': debts,
      'paid': paid,
      'pending': pending,
      'change': change,
      'emails': emails,
      'logs': (_payload?['logs'] as List? ?? const []).length
    };
  }

  bool get _canResume =>
      _previous != null &&
      _previous!['payload_hash'] == _payloadHash &&
      _previous!['event_id'] == _eventId &&
      _previous!['imported_at'] == null &&
      (int.tryParse('${_previous!['photo_batches_done']}') ?? 0) > 0;
  bool get _alreadyImported =>
      _previous != null &&
      _previous!['payload_hash'] == _payloadHash &&
      _previous!['event_id'] == _eventId &&
      _previous!['imported_at'] != null;

  Future<void> _saveProgress(Map<String, dynamic> data) async {
    try {
      final file = File('$_folder${_sep()}$_progressFile');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data),
          flush: true);
      _previous = data;
    } catch (_) {}
  }

  Future<void> _import() async {
    final event = _event;
    final payload = _payload;
    if (event == null ||
        payload == null ||
        _folder == null ||
        _jsonFile == null) return;
    final uploads = _uploads;
    final eventDate = _date(event);
    final sourceDate =
        DateTime.tryParse('${_map(payload['event'])['event_date'] ?? ''}');
    final dateWarning = eventDate != null &&
        sourceDate != null &&
        (eventDate.year != sourceDate.year ||
            eventDate.month != sourceDate.month ||
            eventDate.day != sourceDate.day);
    final s = _summary;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Confirmar sincronização'),
              content: Text([
                'Serviço: ${event['name']} (${event['event_date'] ?? ''})',
                '${uploads.length} fotografias e ${s['orders']} pedidos serão enviados.',
                '${s['emails']} clientes com digital pago vão receber o email de download.',
                if (dateWarning)
                  '\nAtenção: a data da sessão offline (${sourceDate.toIso8601String().split('T').first}) é diferente da data do serviço.',
                if (_alreadyImported)
                  '\nEste ficheiro já foi importado para este serviço. Importar de novo pode duplicar dados se o servidor não estiver atualizado.',
              ].join('\n')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: FilledButton.styleFrom(backgroundColor: _rose),
                    child: const Text('Sincronizar')),
              ],
            ));
    if (confirmed != true) return;
    final resumeFrom = _previous != null &&
            _previous!['payload_hash'] == _payloadHash &&
            _previous!['event_id'] == _eventId &&
            _previous!['imported_at'] == null
        ? (int.tryParse('${_previous!['photo_batches_done']}') ?? 0)
        : 0;
    final batches = <List<(File, Map<String, dynamic>)>>[];
    for (var i = 0; i < uploads.length; i += 20) {
      batches.add(uploads.skip(i).take(20).toList());
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _totalBatches = batches.length;
      _doneBatches = resumeFrom;
      _step = 'A enviar fotografias…';
    });
    final progress = <String, dynamic>{
      'event_id': _eventId,
      'event_name': event['name'],
      'payload_hash': _payloadHash,
      'json_file': _jsonFile!.path,
      'photo_batches_total': batches.length,
      'photo_batches_done': resumeFrom,
      'started_at': DateTime.now().toIso8601String(),
      'imported_at': null,
    };
    await _saveProgress(progress);
    final client = http.Client();
    try {
      for (var index = resumeFrom; index < batches.length; index++) {
        final batch = batches[index];
        final request = http.MultipartRequest(
            'POST', Uri.parse('$_base/offline/events/$_eventId/import-photos'));
        request.headers['Accept'] = 'application/json';
        request.headers['Authorization'] = 'Bearer $_token';
        request.fields['photos_meta'] =
            jsonEncode(batch.map((u) => u.$2).toList());
        for (final upload in batch) {
          if (await upload.$1.length() > 50 * 1024 * 1024)
            throw StateError(
                'A fotografia ${upload.$2['original_path']} tem mais de 50 MB.');
          request.files.add(await http.MultipartFile.fromPath(
              'photos[]', upload.$1.path,
              filename: upload.$1.path.split(RegExp(r'[\\/]')).last));
        }
        final response = await http.Response.fromStream(
            await client.send(request).timeout(const Duration(minutes: 10)));
        if (response.statusCode < 200 || response.statusCode >= 300)
          throw StateError(_apiError(response));
        progress['photo_batches_done'] = index + 1;
        await _saveProgress(progress);
        if (mounted) setState(() => _doneBatches = index + 1);
      }
      if (mounted)
        setState(() => _step = 'A sincronizar pedidos, clientes e registos…');
      final request = http.MultipartRequest(
          'POST', Uri.parse('$_base/offline/events/$_eventId/import'));
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $_token';
      request.fields['device_id'] = 'studio59-app-${Platform.operatingSystem}';
      request.files.add(await http.MultipartFile.fromPath(
          'payload', _jsonFile!.path,
          filename: 'studio59_sessao_offline.json'));
      final response = await http.Response.fromStream(
          await client.send(request).timeout(const Duration(minutes: 10)));
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw StateError(_apiError(response));
      final body = _map(jsonDecode(response.body));
      progress['imported_at'] = DateTime.now().toIso8601String();
      progress['server_response'] = body;
      await _saveProgress(progress);
      if (mounted)
        setState(() {
          _result = body;
          _step = '';
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _step = '';
          _error =
              '${e is StateError ? e.message : 'A ligação falhou durante o envio.'}\nO progresso ficou guardado: ao tocar novamente em Sincronizar, continua a partir do lote ${_doneBatches + 1}.';
        });
    } finally {
      client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card(String title, Widget child,
          {String? subtitle, int? step, bool done = false}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: done ? _rose : _line, width: done ? 1.5 : 1)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (step != null)
              Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                      color: done ? _rose : _roseSoft, shape: BoxShape.circle),
                  child: done
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text('$step',
                          style: const TextStyle(
                              color: _rose, fontWeight: FontWeight.w700))),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700))),
          ]),
          if (subtitle != null)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle,
                    style: const TextStyle(color: _muted, fontSize: 13))),
          const SizedBox(height: 14),
          child,
        ]),
      );

  Widget _column(String title, List<(int, String, String)> items, int? selected,
          ValueChanged<int> onTap) =>
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFFFAF9F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Text(title,
                  style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600))),
          SizedBox(
              height: 210,
              child: items.isEmpty
                  ? const Center(
                      child: Text('—', style: TextStyle(color: _muted)))
                  : ListView(children: [
                      for (final item in items)
                        Material(
                            color: item.$1 == selected
                                ? _rose
                                : Colors.transparent,
                            child: InkWell(
                                onTap: _busy ? null : () => onTap(item.$1),
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 9),
                                    child: Row(children: [
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(item.$2,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color: item.$1 == selected
                                                        ? Colors.white
                                                        : _ink,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            if (item.$3.isNotEmpty)
                                              Text(item.$3,
                                                  style: TextStyle(
                                                      color: item.$1 == selected
                                                          ? Colors.white70
                                                          : _muted,
                                                      fontSize: 11)),
                                          ])),
                                      Icon(Icons.chevron_right,
                                          size: 18,
                                          color: item.$1 == selected
                                              ? Colors.white
                                              : _muted),
                                    ]))))
                    ])),
        ]),
      );

  Widget _picker() {
    final dated = _events.where((e) => _date(e) != null).toList();
    final years = dated.map((e) => _date(e)!.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final months = dated
        .where((e) => _date(e)!.year == _year)
        .map((e) => _date(e)!.month)
        .toSet()
        .toList()
      ..sort();
    final days = dated
        .where((e) => _date(e)!.year == _year && _date(e)!.month == _month)
        .map((e) => _date(e)!.day)
        .toSet()
        .toList()
      ..sort();
    final services = dated.where((e) {
      final d = _date(e)!;
      return d.year == _year && d.month == _month && d.day == _day;
    }).toList();
    int count(bool Function(DateTime) test) =>
        dated.where((e) => test(_date(e)!)).length;
    final columns = [
      _column(
          'ANO',
          [
            for (final y in years)
              (y, '$y', '${count((d) => d.year == y)} serviços')
          ],
          _year,
          (v) => setState(() {
                _year = v;
                _month = null;
                _day = null;
                _eventId = null;
              })),
      _column(
          'MÊS',
          [
            for (final m in months)
              (
                m,
                _months[m - 1],
                '${count((d) => d.year == _year && d.month == m)} serviços'
              )
          ],
          _month,
          (v) => setState(() {
                _month = v;
                _day = null;
                _eventId = null;
              })),
      _column(
          'DIA',
          [
            for (final d in days)
              (
                d,
                '$d',
                '${count((x) => x.year == _year && x.month == _month && x.day == d)} serviços'
              )
          ],
          _day,
          (v) => setState(() {
                _day = v;
                _eventId = null;
              })),
      _column(
          'EVENTO',
          [
            for (final e in services)
              (
                int.tryParse('${e['id']}') ?? 0,
                '${e['name'] ?? 'Serviço'}',
                '${e['location'] ?? ''}'
              )
          ],
          _eventId,
          (v) => setState(() {
                _eventId = v;
                _result = null;
              })),
    ];
    return LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 720
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < columns.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: columns[i])
                ],
              ])
            : Column(children: [
                for (final c in columns)
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: c)
              ]));
  }

  Widget _stat(String label, String value, {Color? color}) => Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: color ?? const Color(0xFFFAF9F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: const TextStyle(
                  color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final payload = _payload;
    final session = _map(payload?['session']);
    final missing = _missing;
    final uploads = _uploads;
    final s = _summary;
    final ready = event != null && payload != null && _folder != null && !_busy;
    return SizedBox(
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        child: ColoredBox(
            color: const Color(0xFFFAF9F7),
            child: SafeArea(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _rose))
                    : Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 980),
                            child: ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  Row(children: [
                                    IconButton(
                                        onPressed: _busy
                                            ? null
                                            : () => Navigator.maybePop(context),
                                        icon: const Icon(Icons.arrow_back,
                                            color: _ink)),
                                    const Expanded(
                                        child: Text(
                                            'Sincronizar sessão offline',
                                            style: TextStyle(
                                                color: _ink,
                                                fontSize: 24,
                                                fontWeight: FontWeight.w700))),
                                  ]),
                                  const Padding(
                                      padding: EdgeInsets.fromLTRB(8, 4, 8, 18),
                                      child: Text(
                                          'Envia as fotografias da pasta provas e todos os pedidos, pagamentos e registos da sessão offline para o serviço online, como se tivesse sido tudo feito online.',
                                          style: TextStyle(color: _muted))),
                                  if (_loadError != null)
                                    _card(
                                        'Não foi possível carregar os serviços',
                                        Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(_loadError!,
                                                  style: const TextStyle(
                                                      color: _danger)),
                                              TextButton(
                                                  onPressed: _load,
                                                  child: const Text(
                                                      'Tentar novamente')),
                                            ]))
                                  else if (!_desktop)
                                    _card(
                                        'Disponível no computador',
                                        const Text(
                                            'A sincronização lê a pasta provas do disco, por isso tem de ser feita no Windows ou macOS.',
                                            style: TextStyle(color: _ink)))
                                  else ...[
                                    _card('Serviço online', _picker(),
                                        step: 1,
                                        done: event != null,
                                        subtitle:
                                            '${'${_user['role']}'.toLowerCase() == 'admin' ? 'Todos os serviços' : 'Serviços em que está atribuído'} · escolha Ano › Mês › Dia › Evento'),
                                    _card(
                                        'Pasta provas e ficheiro JSON',
                                        Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              OutlinedButton.icon(
                                                  onPressed: _busy
                                                      ? null
                                                      : _pickFolder,
                                                  icon: const Icon(
                                                      Icons.folder_open),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                          foregroundColor:
                                                              _rose,
                                                          side:
                                                              const BorderSide(
                                                                  color: _rose),
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(14)),
                                                  label: Text(
                                                      _folder ??
                                                          'Selecionar pasta provas',
                                                      overflow: TextOverflow
                                                          .ellipsis)),
                                              if (_folder != null)
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 6),
                                                    child: Text(
                                                        '${_files.length} fotografias JPEG na pasta',
                                                        style: const TextStyle(
                                                            color: _muted))),
                                              const SizedBox(height: 10),
                                              OutlinedButton.icon(
                                                  onPressed:
                                                      _busy ? null : _pickJson,
                                                  icon: const Icon(Icons
                                                      .description_outlined),
                                                  style: OutlinedButton.styleFrom(
                                                      foregroundColor: _rose,
                                                      side: const BorderSide(
                                                          color: _rose),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              14)),
                                                  label: Text(
                                                      _jsonFile?.path
                                                              .split(RegExp(
                                                                  r'[\\/]'))
                                                              .last ??
                                                          'Selecionar ficheiro JSON da sessão',
                                                      overflow: TextOverflow
                                                          .ellipsis)),
                                              if (payload != null)
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 8),
                                                    child: Text(
                                                        'Sessão «${session['name'] ?? _map(payload['event'])['name'] ?? '—'}» · ${_map(payload['event'])['event_date'] ?? session['event_date'] ?? ''}',
                                                        style: const TextStyle(
                                                            color: _ink,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600))),
                                            ]),
                                        step: 2,
                                        done:
                                            _folder != null && payload != null,
                                        subtitle:
                                            'O JSON da sessão é detetado automaticamente se estiver dentro da pasta.'),
                                    if (payload != null && _folder != null)
                                      _card(
                                          'Resumo',
                                          Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    children: [
                                                      _stat(
                                                          'Fotografias a enviar',
                                                          '${uploads.length}'),
                                                      _stat('Pedidos',
                                                          '${s['orders']}'),
                                                      _stat('Pagos',
                                                          '${s['paid']}',
                                                          color: const Color(
                                                              0xFFE8F5E9)),
                                                      _stat('Devem',
                                                          '${s['debts']}',
                                                          color: const Color(
                                                              0xFFFBEAEA)),
                                                      _stat(
                                                          'Troco por entregar',
                                                          '${s['change']}',
                                                          color: const Color(
                                                              0xFFFFF3E0)),
                                                      _stat('Por atender',
                                                          '${s['pending']}'),
                                                      _stat('Total vendido',
                                                          _money(s['total']!)),
                                                      _stat(
                                                          'Recebido',
                                                          _money(
                                                              s['received']!)),
                                                      _stat('Em dívida',
                                                          _money(s['due']!)),
                                                      _stat(
                                                          'Emails de download',
                                                          '${s['emails']}'),
                                                      _stat('Registos (logs)',
                                                          '${s['logs']}'),
                                                    ]),
                                                if (missing.isNotEmpty)
                                                  Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 12),
                                                      child: Text(
                                                          '${missing.length} fotografias do JSON não estão na pasta: ${missing.take(5).join(', ')}${missing.length > 5 ? '…' : ''}. Os pedidos com essas fotografias podem ficar incompletos.',
                                                          style: const TextStyle(
                                                              color: _danger))),
                                                if (_alreadyImported)
                                                  const Padding(
                                                      padding: EdgeInsets.only(
                                                          top: 12),
                                                      child: Text(
                                                          'Este ficheiro já foi sincronizado com este serviço.',
                                                          style: TextStyle(
                                                              color: _danger,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600))),
                                              ]),
                                          step: 3),
                                    if (_busy ||
                                        _doneBatches > 0 &&
                                            _result == null &&
                                            _totalBatches > 0)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Text(
                                                    _step.isEmpty
                                                        ? 'Fotografias: $_doneBatches de $_totalBatches lotes enviados'
                                                        : '$_step  ($_doneBatches/$_totalBatches lotes)',
                                                    style: const TextStyle(
                                                        color: _ink)),
                                                const SizedBox(height: 6),
                                                LinearProgressIndicator(
                                                    value: _totalBatches == 0
                                                        ? null
                                                        : _doneBatches /
                                                            _totalBatches,
                                                    color: _rose,
                                                    backgroundColor: _roseSoft,
                                                    minHeight: 8,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4)),
                                              ])),
                                    if (_error != null)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFBEAEA),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                              child: Text(_error!,
                                                  style: const TextStyle(
                                                      color: _danger)))),
                                    if (_result != null)
                                      _card(
                                          'Sincronização concluída',
                                          Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                for (final entry in {
                                                  'Pedidos criados': _result![
                                                      'orders_created'],
                                                  'Pedidos atualizados':
                                                      _result![
                                                          'orders_updated'],
                                                  'Fotografias associadas':
                                                      _result!['photos_mapped'],
                                                  'Emails enviados':
                                                      _result!['emails_sent'],
                                                  'Registos importados':
                                                      _result!['logs_imported'],
                                                  'Comissões atualizadas':
                                                      _result![
                                                          'commissions_updated'],
                                                  'Referência (sync_id)':
                                                      _result!['sync_id'],
                                                }.entries.where(
                                                    (e) => e.value != null))
                                                  Text(
                                                      '${entry.key}: ${entry.value}',
                                                      style: const TextStyle(
                                                          color: _ink)),
                                                if (_result!['warnings']
                                                        is List &&
                                                    (_result!['warnings']
                                                            as List)
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                      'Avisos do servidor:',
                                                      style: TextStyle(
                                                          color: _danger,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  for (final w
                                                      in (_result!['warnings']
                                                              as List)
                                                          .take(20))
                                                    Text('• $w',
                                                        style: const TextStyle(
                                                            color: _danger,
                                                            fontSize: 12)),
                                                ],
                                                const SizedBox(height: 8),
                                                const Text(
                                                    'Confirme os pedidos no separador Pedidos do serviço. Guarde a pasta provas e o JSON até ter confirmado tudo.',
                                                    style: TextStyle(
                                                        color: _muted)),
                                              ]),
                                          done: true),
                                    FilledButton.icon(
                                        onPressed: ready && _result == null
                                            ? _import
                                            : null,
                                        style: FilledButton.styleFrom(
                                            backgroundColor: _rose,
                                            padding: const EdgeInsets.all(18),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14))),
                                        icon: _busy
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white))
                                            : const Icon(
                                                Icons.cloud_upload_outlined),
                                        label: Text(
                                            _result != null
                                                ? 'Sincronização concluída'
                                                : (_canResume ||
                                                            _doneBatches > 0) &&
                                                        !_busy
                                                    ? 'Continuar sincronização'
                                                    : _alreadyImported
                                                        ? 'Sincronizar novamente'
                                                        : 'Sincronizar',
                                            style:
                                                const TextStyle(fontSize: 16))),
                                  ],
                                ]))))));
  }
}
