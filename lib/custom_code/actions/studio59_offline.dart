// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/ff_builtin_enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart' hide RepeatMode;
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/app_state.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:path_provider/path_provider.dart';

/// Sessão offline Studio 59: servidor local de fotos/pedidos, deteção na rede
/// e limpeza de sessões. Comandos: status, prepare, discover, inspect, start,
/// stop, log. Devolve sempre JSON.
Future<String> studio59Offline(String command, String payload) async {
  try {
    final args = payload.trim().isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(payload) as Map);
    switch (command) {
      case 'status':
        return jsonEncode(_S59Host.instance.status());
      case 'prepare':
        return jsonEncode(await _s59Prepare(args['rescan'] == true));
      case 'discover':
        return jsonEncode(await _s59Discover());
      case 'inspect':
        return jsonEncode(
            await _S59Host.instance.inspect('${args['folder'] ?? ''}'));
      case 'start':
        return jsonEncode(await _S59Host.instance.start(args));
      case 'stop':
        return jsonEncode(await _S59Host.instance.stop());
      case 'log':
        await _s59RemoteLog('${args['action'] ?? 'app'}',
            '${args['message'] ?? ''}', args['data']);
        return jsonEncode({'ok': true});
    }
    return jsonEncode(
        {'ok': false, 'message': 'Comando desconhecido: $command'});
  } catch (error) {
    return jsonEncode({'ok': false, 'message': '$error'});
  }
}

const _s59OnlineApi = 'https://studio59.wiredevelop.pt/api';
const _s59Port = 5959;
const _s59SessionFile = 'studio59_sessao_offline.json';
const _s59FilmCents = 3000;
const _s59ShippingCents = 500;
const _s59PreviewWidth = 900;
bool _s59CachesCleared = false;

bool get _s59Desktop =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

String _s59Money(int cents) =>
    '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')} €';

int? _s59Cents(dynamic value) {
  if (value == null) return null;
  if (value is int) return value * 100;
  if (value is double) return (value * 100).round();
  final text = '$value'.trim().replaceAll(',', '.');
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
  if (match == null) return null;
  return int.parse(match.group(1)!) * 100 +
      int.parse((match.group(2) ?? '0').padRight(2, '0'));
}

num _s59Euros(int cents) => cents % 100 == 0 ? cents ~/ 100 : cents / 100;

Future<bool> _s59IsOnline() async {
  try {
    final response = await http.get(Uri.parse('$_s59OnlineApi/auth/me'),
        headers: {
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 5));
    return response.statusCode > 0;
  } catch (_) {
    return false;
  }
}

Future<void> _s59ClearCaches() async {
  try {
    await const FlutterSecureStorage().delete(key: 'studio59_staff_token');
  } catch (_) {}
  FFAppState().update(() {
    FFAppState().guestSessionToken = '';
    FFAppState().guestEvent = Studio59EventInfoStruct();
    FFAppState().guestCart = [];
    FFAppState().lastGuestOrder = Studio59OrderReceiptStruct();
    FFAppState().offlineApiBase = '';
  });
}

Future<Map<String, dynamic>> _s59Probe(String base) async {
  try {
    final response = await http.get(Uri.parse('$base/offline/discover'),
        headers: {
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 3));
    final body = jsonDecode(response.body);
    if (response.statusCode == 200 &&
        body is Map &&
        body['studio59_offline'] == true) {
      return {...Map<String, dynamic>.from(body), 'base': base};
    }
  } catch (_) {}
  return {};
}

Future<Map<String, dynamic>> _s59Prepare(bool rescan) async {
  final host = _S59Host.instance;
  if (host.running) {
    FFAppState().update(
        () => FFAppState().offlineApiBase = 'http://127.0.0.1:$_s59Port/api');
    return {'mode': 'host', 'desktop': _s59Desktop, ...host.status()};
  }
  final current = FFAppState().offlineApiBase;
  if (!rescan && current.isNotEmpty) {
    final found = await _s59Probe(current);
    if (found.isNotEmpty)
      return {'mode': 'client', 'desktop': _s59Desktop, ...found};
  }
  final online = await _s59IsOnline();
  // Com internet, o computador guarda os modelos do reconhecimento facial para as sessões offline.
  if (online && _s59Desktop) unawaited(_S59FaceIndex.ensureModels());
  if (online && !rescan) {
    FFAppState().update(() => FFAppState().offlineApiBase = '');
    return {'mode': 'online', 'desktop': _s59Desktop};
  }
  if (!online && _s59Desktop && !_s59CachesCleared) {
    _s59CachesCleared = true;
    await _s59ClearCaches();
  }
  final found = await _s59Discover();
  if (found['base'] is String) {
    FFAppState()
        .update(() => FFAppState().offlineApiBase = found['base'] as String);
    return {'mode': 'client', 'desktop': _s59Desktop, ...found};
  }
  FFAppState().update(() => FFAppState().offlineApiBase = '');
  return {'mode': online ? 'online' : 'offline', 'desktop': _s59Desktop};
}

Future<List<String>> _s59LocalIps() async {
  if (kIsWeb) return [];
  final result = <String>[];
  try {
    final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    for (final iface in interfaces) {
      for (final address in iface.addresses) {
        final ip = address.address;
        if (ip.startsWith('169.254.')) continue;
        result.add(ip);
      }
    }
  } catch (_) {}
  int rank(String ip) => ip.startsWith('192.168.')
      ? 0
      : ip.startsWith('10.')
          ? 1
          : ip.startsWith('172.')
              ? 2
              : 3;
  result.sort((a, b) => rank(a).compareTo(rank(b)));
  return result;
}

/// Procura um computador com sessão offline na rede local (porta 5959).
Future<Map<String, dynamic>> _s59Discover() async {
  if (kIsWeb) return {};
  final local = await _s59Probe('http://127.0.0.1:$_s59Port/api');
  if (local.isNotEmpty) return local;
  final ips = await _s59LocalIps();
  final prefixes = <String>[];
  for (final ip in ips) {
    final parts = ip.split('.');
    if (parts.length != 4) continue;
    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
    if (!prefixes.contains(prefix)) prefixes.add(prefix);
  }
  for (final prefix in prefixes.take(4)) {
    final candidates = [for (var i = 1; i < 255; i++) '$prefix.$i'];
    for (var start = 0; start < candidates.length; start += 64) {
      final batch =
          candidates.sublist(start, min(start + 64, candidates.length));
      final open = await Future.wait(batch.map((ip) async {
        try {
          final socket = await Socket.connect(ip, _s59Port,
              timeout: const Duration(milliseconds: 450));
          socket.destroy();
          return ip;
        } catch (_) {
          return null;
        }
      }));
      for (final ip in open.whereType<String>()) {
        final found = await _s59Probe('http://$ip:$_s59Port/api');
        if (found.isNotEmpty) return found;
      }
    }
  }
  return {};
}

/// Regista um movimento do dispositivo na sessão offline (apenas em modo offline).
Future<void> _s59RemoteLog(String action, String message, dynamic data) async {
  final base = FFAppState().offlineApiBase;
  if (base.isEmpty) return;
  final host = _S59Host.instance;
  if (host.running && base.contains('127.0.0.1')) {
    host.log('device', 'este computador', action, message, data);
    return;
  }
  try {
    await http
        .post(Uri.parse('$base/public/logs'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              if (FFAppState().guestSessionToken.isNotEmpty)
                'Authorization': 'Bearer ${FFAppState().guestSessionToken}',
            },
            body: jsonEncode(
                {'action': action, 'message': message, 'context': data}))
        .timeout(const Duration(seconds: 5));
  } catch (_) {}
}

class _S59Host {
  static final _S59Host instance = _S59Host();

  HttpServer? _server;
  Directory? _folder;
  Map<String, dynamic> _session = {};
  List<Map<String, dynamic>> _photos = [];
  final Map<int, String> _photoPaths = {};
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _logs = [];
  final Map<String, String> _guestTokens = {};
  final Map<String, String> _staffTokens = {};
  final Map<String, Future<Uint8List?>> _previewJobs = {};
  final _random = Random.secure();
  String _ip = '127.0.0.1';
  Future<void> _saving = Future.value();
  int _previewSlots = 2;
  final List<Completer<void>> _previewQueue = [];
  final _faces = _S59FaceIndex();

  bool get running => _server != null;
  String get _qr =>
      'S59OFF_${_ip.replaceAll('.', '-')}_${_s59Port}_${_session['qr_secret'] ?? ''}';
  File _sessionFile(Directory folder) =>
      File('${folder.path}${Platform.pathSeparator}$_s59SessionFile');

  String _randomString(int length,
          [String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789']) =>
      List.generate(length, (_) => alphabet[_random.nextInt(alphabet.length)])
          .join();

  String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt::$password')).toString();

  Map<String, dynamic> get _event => {
        'id': 1,
        'name': _session['name'] ?? 'Sessão offline',
        'event_date': _session['event_date'] ?? '',
        'event_time': '',
        'location': 'Sessão offline',
        'price_per_photo': _session['price_per_photo'] ?? 0,
        'offline': true,
      };

  int get _unitCents => _s59Cents(_session['price_per_photo']) ?? 0;

  Map<String, dynamic> status() {
    if (!running) return {'ok': true, 'running': false, 'desktop': _s59Desktop};
    int count(bool Function(Map<String, dynamic>) test) =>
        _orders.where(test).length;
    int sum(String key, [bool Function(Map<String, dynamic>)? test]) => _orders
        .where((o) => test == null || test(o))
        .fold<int>(0, (total, o) => total + (_s59Cents(o[key]) ?? 0));
    return {
      'ok': true,
      'running': true,
      'desktop': _s59Desktop,
      'folder': _folder?.path,
      'file': _folder == null ? null : _sessionFile(_folder!).path,
      'name': _session['name'],
      'event_date': _session['event_date'],
      'price_per_photo': _session['price_per_photo'],
      'pin': _session['pin'],
      'qr': _qr,
      'ip': _ip,
      'port': _s59Port,
      'staff_username': _session['staff_username'],
      'photos': _photos.length,
      'orders': _orders.length,
      'pending': count((o) => o['status'] == 'pending'),
      'paid': count((o) => o['status'] == 'paid' || o['status'] == 'delivered'),
      'debts': count((o) => (_s59Cents(o['cash_due_amount']) ?? 0) > 0),
      'change_owed': count((o) =>
          (_s59Cents(o['cash_change_amount']) ?? 0) > 0 &&
          o['cash_change_given'] != true),
      'total_sold': _s59Money(sum('total_amount')),
      'total_received': _s59Money(sum('cash_received_amount')),
      'devices': _guestTokens.values.toSet().length,
    };
  }

  Future<List<File>> _imageFiles(Directory folder) async {
    final files = <File>[];
    await for (final entity
        in folder.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = entity.path.substring(folder.path.length + 1);
      if (relative.split(RegExp(r'[\\/]')).any((part) => part.startsWith('.')))
        continue;
      final lower = relative.toLowerCase();
      if (lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return files;
  }

  Future<Map<String, dynamic>> inspect(String path) async {
    final folder = Directory(path);
    if (path.isEmpty || !await folder.exists()) {
      return {'ok': false, 'message': 'A pasta selecionada não existe.'};
    }
    final files = await _imageFiles(folder);
    Map<String, dynamic>? existing;
    final file = _sessionFile(folder);
    if (await file.exists()) {
      try {
        final data = Map<String, dynamic>.from(
            jsonDecode(await file.readAsString()) as Map);
        final session =
            Map<String, dynamic>.from(data['session'] as Map? ?? {});
        existing = {
          'name': session['name'],
          'event_date': session['event_date'],
          'price_per_photo': session['price_per_photo'],
          'pin': session['pin'],
          'staff_username': session['staff_username'],
          'orders': (data['orders'] as List? ?? const []).length,
          'closed_at': session['closed_at'],
        };
      } catch (_) {
        existing = {'invalid': true};
      }
    }
    return {'ok': true, 'photos': files.length, 'existing': existing};
  }

  Future<Map<String, dynamic>> start(Map<String, dynamic> args) async {
    if (!_s59Desktop) {
      return {
        'ok': false,
        'message': 'A sessão offline só pode ser criada no Windows ou macOS.'
      };
    }
    if (running) return status();
    final folder = Directory('${args['folder'] ?? ''}');
    if (!await folder.exists())
      return {'ok': false, 'message': 'Selecione a pasta provas.'};
    final resume = args['resume'] == true;
    final file = _sessionFile(folder);
    final password = '${args['staff_password'] ?? ''}';
    Map<String, dynamic> data = {};
    if (resume) {
      if (!await file.exists())
        return {
          'ok': false,
          'message': 'Não existe sessão para retomar nesta pasta.'
        };
      data = Map<String, dynamic>.from(
          jsonDecode(await file.readAsString()) as Map);
      final session = Map<String, dynamic>.from(data['session'] as Map? ?? {});
      if (_hash('${session['staff_salt']}', password) !=
          session['staff_hash']) {
        return {
          'ok': false,
          'message': 'A palavra-passe da equipa não corresponde à da sessão.'
        };
      }
      _session = session..remove('closed_at');
    } else {
      final name = '${args['name'] ?? ''}'.trim();
      final pin = '${args['pin'] ?? ''}'.trim();
      final username = '${args['staff_username'] ?? ''}'.trim();
      final price = _s59Cents(args['price_per_photo']);
      if (name.isEmpty)
        return {'ok': false, 'message': 'Indique o nome da sessão.'};
      if (!RegExp(r'^\d{4}$').hasMatch(pin))
        return {'ok': false, 'message': 'O PIN tem de ter 4 dígitos.'};
      if (price == null || price <= 0)
        return {
          'ok': false,
          'message': 'Indique um preço por fotografia válido.'
        };
      if (username.isEmpty || password.length < 4) {
        return {
          'ok': false,
          'message':
              'Defina o utilizador e uma palavra-passe (mínimo 4 caracteres) para a equipa.'
        };
      }
      if (await file.exists()) {
        final stamp = DateTime.now()
            .toIso8601String()
            .replaceAll(RegExp(r'[^0-9]'), '')
            .substring(0, 14);
        await file.rename(
            '${folder.path}${Platform.pathSeparator}studio59_sessao_offline_$stamp.json');
      }
      final salt = _randomString(16);
      _session = {
        'id': '${DateTime.now().millisecondsSinceEpoch}-${_randomString(6)}',
        'name': name,
        'event_date': '${args['event_date'] ?? ''}',
        'price_per_photo': _s59Euros(price),
        'pin': pin,
        'qr_secret': _randomString(10),
        'staff_username': username,
        'staff_salt': salt,
        'staff_hash': _hash(salt, password),
        'created_at': DateTime.now().toIso8601String(),
        'host_platform': Platform.operatingSystem,
      };
    }
    _folder = folder;
    _orders = (data['orders'] as List? ?? const [])
        .whereType<Map>()
        .map((o) => Map<String, dynamic>.from(o))
        .toList();
    _logs = (data['logs'] as List? ?? const [])
        .whereType<Map>()
        .map((l) => Map<String, dynamic>.from(l))
        .toList();
    _photos = (data['photos'] as List? ?? const [])
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
    await _syncPhotos();
    final ips = await _s59LocalIps();
    _ip = ips.isEmpty ? '127.0.0.1' : ips.first;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _s59Port,
          shared: true);
    } on SocketException catch (error) {
      _folder = null;
      return {
        'ok': false,
        'message':
            'Não foi possível abrir a porta $_s59Port (${error.message}). Feche outra sessão aberta e tente de novo.'
      };
    }
    _server!.listen((request) => _handle(request), onError: (_) {});
    FFAppState().update(
        () => FFAppState().offlineApiBase = 'http://127.0.0.1:$_s59Port/api');
    log(
        'host',
        'este computador',
        resume ? 'session.resume' : 'session.start',
        '${resume ? 'Sessão retomada' : 'Sessão criada'}: ${_session['name']} (${_photos.length} fotografias, IP $_ip)',
        null);
    await _save();
    unawaited(_warmPreviews());
    unawaited(_faces.start(folder, () => _photos, _photoPaths));
    return status();
  }

  Future<Map<String, dynamic>> stop() async {
    if (!running) return status();
    _session['closed_at'] = DateTime.now().toIso8601String();
    log('host', 'este computador', 'session.stop', 'Sessão offline terminada',
        null);
    await _save();
    await _faces.stop();
    await _server?.close(force: true);
    _server = null;
    _guestTokens.clear();
    _staffTokens.clear();
    _previewJobs.clear();
    FFAppState().update(() => FFAppState().offlineApiBase = '');
    return status();
  }

  Future<void> _syncPhotos() async {
    final folder = _folder!;
    final files = await _imageFiles(folder);
    final byPath = {for (final p in _photos) '${p['original_path']}': p};
    var nextId = _photos.fold<int>(
            0, (m, p) => max(m, int.tryParse('${p['id']}') ?? 0)) +
        1;
    _photoPaths.clear();
    for (final file in files) {
      final relative =
          file.path.substring(folder.path.length + 1).replaceAll('\\', '/');
      var photo = byPath[relative];
      if (photo == null) {
        final name = relative.split('/').last;
        final dot = name.lastIndexOf('.');
        photo = {
          'id': nextId++,
          'number': dot > 0 ? name.substring(0, dot) : name,
          'filename': name,
          'original_path': relative,
        };
        _photos.add(photo);
      }
      _photoPaths[int.parse('${photo['id']}')] = file.path;
    }
  }

  void log(String actor, String device, String action, String message,
      dynamic data) {
    _logs.add({
      'id': _logs.length + 1,
      'at': DateTime.now().toIso8601String(),
      'actor': actor,
      'device': device,
      'action': action,
      'message': message,
      if (data != null) 'data': data,
    });
  }

  Map<String, dynamic> exportData() {
    final clients = <String, Map<String, dynamic>>{};
    for (final order in _orders) {
      final key =
          '${order['customer_email'] ?? ''}|${order['customer_phone'] ?? ''}'
              .toLowerCase();
      clients[key] = {
        'name': order['customer_name'],
        'email': order['customer_email'],
        'phone': order['customer_phone'],
      };
    }
    return {
      'format': 'studio59-offline-v1',
      'exported_at': DateTime.now().toIso8601String(),
      'session': _session,
      'event': {'name': _session['name'], 'event_date': _session['event_date']},
      'photos': _photos,
      'orders': _orders,
      'clients': clients.values.toList(),
      'selections': const [],
      'order_updates': const [],
      'logs': _logs,
    };
  }

  Future<void> _save() {
    final folder = _folder;
    if (folder == null) return _saving;
    final text = const JsonEncoder.withIndent('  ').convert(exportData());
    _saving = _saving.then((_) async {
      final target = _sessionFile(folder);
      final temp = File('${target.path}.tmp');
      await temp.writeAsString(text, flush: true);
      await temp.rename(target.path);
    }).catchError((_) {});
    return _saving;
  }

  String _device(HttpRequest request) {
    final ip = request.connectionInfo?.remoteAddress.address ?? '?';
    final agent = request.headers.value('user-agent') ?? '';
    final kind = agent.contains('iPad')
        ? 'iPad'
        : agent.contains('iPhone')
            ? 'iPhone'
            : agent.contains('Android')
                ? 'Android'
                : agent.contains('Windows')
                    ? 'Windows'
                    : agent.contains('Mac')
                        ? 'Mac'
                        : 'Dispositivo';
    return ip == '127.0.0.1' ? 'este computador' : '$kind $ip';
  }

  String? _bearer(HttpRequest request) {
    final value = request.headers.value('authorization') ?? '';
    return value.toLowerCase().startsWith('bearer ')
        ? value.substring(7).trim()
        : null;
  }

  Future<void> _json(HttpResponse response, int code, Object body) async {
    response.statusCode = code;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    final text = await utf8.decoder.bind(request).join();
    if (text.trim().isEmpty) return {};
    final decoded = jsonDecode(text);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }

  Map<String, dynamic> _guestSession() => {
        'event_session_token': '',
        'event': _event,
        'offline_mode': true,
      };

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set(
          'Access-Control-Allow-Headers', 'Authorization, Content-Type, Accept')
      ..set('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS');
    try {
      if (request.method == 'OPTIONS') {
        response.statusCode = 204;
        await response.close();
        return;
      }
      final segments =
          request.uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length == 3 &&
          segments[0] == 'offline' &&
          segments[1] == 'previews') {
        return _servePreview(request, int.tryParse(segments[2]) ?? 0);
      }
      if (segments.isEmpty || segments[0] != 'api') {
        return _json(response, 404, {'message': 'Não encontrado.'});
      }
      final api = segments.sublist(1);
      final method = request.method;
      // Pesquisa facial: o corpo é multipart (selfie), por isso é tratada antes da leitura JSON.
      if (method == 'POST' &&
          api.length == 4 &&
          api[0] == 'public' &&
          api[1] == 'events' &&
          api[3] == 'face-search') {
        final guestToken = _bearer(request);
        if (guestToken == null || !_guestTokens.containsKey(guestToken)) {
          return _json(
              response, 401, {'message': 'Sessão do evento inválida.'});
        }
        return _faceSearch(request, response, _device(request));
      }
      final body = method == 'POST' || method == 'PUT'
          ? await _readJson(request)
          : <String, dynamic>{};
      final device = _device(request);
      final token = _bearer(request);
      bool route(String m, List<String> pattern) {
        if (m != method || pattern.length != api.length) return false;
        for (var i = 0; i < pattern.length; i++) {
          if (pattern[i] != '*' && pattern[i] != api[i]) return false;
        }
        return true;
      }

      // Deteção e entrada de convidados.
      if (route('GET', ['offline', 'discover'])) {
        return _json(response, 200, {
          'studio59_offline': true,
          'session_name': _session['name'],
          'event_date': _session['event_date'],
          'host': _ip,
          'port': _s59Port,
        });
      }
      if (route('GET', ['public', 'events', 'today'])) {
        return _json(response, 200, {
          'data': [_event],
          'offline_mode': true
        });
      }
      if (route('POST', ['public', 'events', 'pin']) ||
          route('POST', ['public', 'events', '*', 'enter'])) {
        final pin = '${body['pin'] ?? body['password'] ?? ''}'.trim();
        if (pin != _session['pin']) {
          log('guest', device, 'guest.enter_failed', 'PIN incorreto',
              {'pin': pin});
          await _save();
          return _json(response, 404,
              {'message': 'PIN não encontrado nesta sessão offline.'});
        }
        return _enterGuest(response, device, 'PIN');
      }
      if (route('GET', ['public', 'events', 'qr', '*'])) {
        final secret = api[3].split('_').last;
        if (secret != _session['qr_secret']) {
          log('guest', device, 'guest.enter_failed', 'QR inválido', null);
          await _save();
          return _json(response, 404,
              {'message': 'QR não pertence a esta sessão offline.'});
        }
        return _enterGuest(response, device, 'QR');
      }

      // Catálogo e pedidos do convidado.
      final guest = token != null && _guestTokens.containsKey(token);
      if (route('GET', ['public', 'events', '*', 'photos'])) {
        if (!guest)
          return _json(
              response, 401, {'message': 'Sessão do evento inválida.'});
        return _photosPage(request, response, device);
      }
      if (route('POST', ['public', 'logs'])) {
        log(
            guest ? 'guest' : 'device',
            device,
            '${body['action'] ?? 'app.log'}',
            '${body['message'] ?? ''}',
            body['context']);
        await _save();
        return _json(response, 200, {'ok': true});
      }
      if (route('POST', ['public', 'orders'])) {
        if (!guest)
          return _json(
              response, 401, {'message': 'Sessão do evento inválida.'});
        return _createOrder(response, body, device);
      }
      if (route('GET', ['public', 'orders', '*'])) {
        final order =
            _orders.where((o) => o['order_code'] == api[2]).firstOrNull;
        if (order == null)
          return _json(response, 404, {'message': 'Pedido não encontrado.'});
        return _json(response, 200, {
          'order_code': order['order_code'],
          'status': order['status'],
          'total_amount': order['total_amount'],
          'shipping_fee': order['shipping_fee'],
          'delivery_type': order['delivery_type'],
          'delivery_address': order['delivery_address'],
        });
      }

      // Equipa.
      if (route('POST', ['auth', 'login'])) {
        final login =
            '${body['login'] ?? body['email'] ?? body['username'] ?? ''}'
                .trim()
                .toLowerCase();
        final password = '${body['password'] ?? ''}';
        if (login != '${_session['staff_username']}'.toLowerCase() ||
            _hash('${_session['staff_salt']}', password) !=
                _session['staff_hash']) {
          log('staff', device, 'staff.login_failed',
              'Credenciais inválidas para «$login»', null);
          await _save();
          return _json(response, 422,
              {'message': 'Credenciais inválidas para esta sessão offline.'});
        }
        final staffToken =
            _randomString(40, 'abcdefghijklmnopqrstuvwxyz0123456789');
        _staffTokens[staffToken] = device;
        log('staff', device, 'staff.login', 'Entrada da equipa', null);
        await _save();
        return _json(response, 200,
            {'token': staffToken, 'user': _staffUser, 'offline_mode': true});
      }
      final staff = token != null && _staffTokens.containsKey(token);
      if (!staff)
        return _json(response, 401, {'message': 'Sessão da equipa inválida.'});
      if (route('GET', ['auth', 'me'])) {
        return _json(response, 200, {'user': _staffUser, 'offline_mode': true});
      }
      if (route('POST', ['auth', 'logout'])) {
        _staffTokens.remove(token);
        log('staff', device, 'staff.logout', 'Saída da equipa', null);
        await _save();
        return _json(response, 200, {'message': 'Logged out'});
      }
      if (route('GET', ['events']))
        return _json(response, 200, _page([_event]));
      if (route('GET', ['events', '*']))
        return _json(response, 200, {'data': _event});
      if (route('GET', ['events', '*', 'staff']))
        return _json(response, 200, {'data': []});
      if (route('GET', ['orders']) || route('GET', ['events', '*', 'orders'])) {
        final status = request.uri.queryParameters['status'];
        final query = (request.uri.queryParameters['q'] ?? '').toLowerCase();
        final rows = _orders.reversed
            .where((o) =>
                status == null || status.isEmpty || o['status'] == status)
            .where((o) =>
                query.isEmpty || jsonEncode(o).toLowerCase().contains(query))
            .map(_orderRow)
            .toList();
        return _json(response, 200, _page(rows));
      }
      if (route('GET', ['offline', 'events', '*', 'export'])) {
        return _json(response, 200, exportData());
      }
      final orderId =
          api.length >= 2 && api[0] == 'orders' ? int.tryParse(api[1]) : null;
      final order = orderId == null
          ? null
          : _orders.where((o) => o['id'] == orderId).firstOrNull;
      if (orderId != null && order == null)
        return _json(response, 404, {'message': 'Pedido não encontrado.'});
      if (order != null && route('GET', ['orders', '*'])) {
        log('staff', device, 'order.view',
            'Consultou o pedido ${order['order_code']}', null);
        return _json(response, 200, {'data': _orderRow(order)});
      }
      if (order != null && route('POST', ['orders', '*', 'mark-paid'])) {
        return _markPaid(response, order, body, device);
      }
      if (order != null && route('PUT', ['orders', '*'])) {
        return _updateOrder(response, order, body, device);
      }
      if (route('POST', ['orders', '*', 'send-download-link'])) {
        return _json(response, 200, {
          'sent': false,
          'message': 'O envio será feito após a sincronização.'
        });
      }
      return _json(response, 404,
          {'message': 'Operação indisponível na sessão offline.'});
    } catch (error) {
      try {
        await _json(
            response, 500, {'message': 'Erro na sessão offline: $error'});
      } catch (_) {}
    }
  }

  Map<String, dynamic> get _staffUser => {
        'id': 1,
        'name': _session['staff_username'],
        'username': _session['staff_username'],
        'email': '',
        'role': 'staff',
        'permissions': const [
          'dashboard.view',
          'events.list',
          'events.view',
          'orders.list',
          'orders.view',
          'orders.update'
        ],
        'offline_mode': true,
      };

  Map<String, dynamic> _page(List<Map<String, dynamic>> rows) => {
        'current_page': 1,
        'last_page': 1,
        'per_page': rows.length,
        'total': rows.length,
        'data': rows,
        'offline_mode': true,
      };

  Map<String, dynamic> _orderRow(Map<String, dynamic> order) => {
        ...order,
        'event_id': 1,
        'event': {
          'id': 1,
          'name': _session['name'],
          'event_date': _session['event_date']
        },
        'photos': [
          for (final item
              in (order['items'] as List? ?? const []).whereType<Map>())
            {
              'id': item['photo_id'],
              'number': item['photo_number'],
              'quantity': item['quantity']
            },
        ],
      };

  Future<void> _enterGuest(
      HttpResponse response, String device, String via) async {
    final guestToken =
        _randomString(40, 'abcdefghijklmnopqrstuvwxyz0123456789');
    _guestTokens[guestToken] = device;
    log('guest', device, 'guest.enter', 'Entrou no catálogo por $via', null);
    await _save();
    return _json(
        response, 200, {..._guestSession(), 'event_session_token': guestToken});
  }

  Future<void> _photosPage(
      HttpRequest request, HttpResponse response, String device) async {
    final query = request.uri.queryParameters;
    final perPage = (int.tryParse(query['per_page'] ?? '') ?? 50).clamp(1, 200);
    final search = (query['search'] ?? '').trim().toLowerCase();
    final rows = search.isEmpty
        ? _photos
        : _photos
            .where((p) => '${p['number']}'.toLowerCase().contains(search))
            .toList();
    final lastPage = max(1, (rows.length / perPage).ceil());
    final page = (int.tryParse(query['page'] ?? '') ?? 1).clamp(1, lastPage);
    final host = request.headers.host ?? _ip;
    final port = request.headers.port ?? _s59Port;
    final slice = rows.skip((page - 1) * perPage).take(perPage).map((p) => {
          'id': p['id'],
          'number': p['number'],
          'filename': p['filename'],
          'preview_url':
              'http://$host:$port/offline/previews/${p['id']}?w=$_s59PreviewWidth',
        });
    if (page == 1) {
      log('guest', device, 'gallery.open',
          'Abriu o catálogo (${rows.length} fotografias)', null);
      await _save();
    }
    return _json(response, 200, {
      'current_page': page,
      'last_page': lastPage,
      'per_page': perPage,
      'total': rows.length,
      'data': slice.toList(),
    });
  }

  Future<void> _createOrder(
      HttpResponse response, Map<String, dynamic> body, String device) async {
    final name = '${body['customer_name'] ?? ''}'.trim();
    final phone = '${body['customer_phone'] ?? ''}'.trim();
    final email = '${body['customer_email'] ?? ''}'.trim();
    final productType = '${body['product_type'] ?? ''}';
    final deliveryType = '${body['delivery_type'] ?? ''}';
    final address = '${body['delivery_address'] ?? ''}'.trim();
    final wantsFilm =
        body['wants_film'] == true || body['wants_film'] == 'true';
    String? problem;
    if (name.isEmpty) problem = 'O nome é obrigatório.';
    if (phone.isEmpty) problem = 'O telefone é obrigatório.';
    if (!email.contains('@')) problem = 'O email é obrigatório.';
    if (!const ['paper', 'digital', 'both'].contains(productType))
      problem = 'Formato inválido.';
    if (productType != 'digital' &&
        !const ['pickup', 'store_pickup', 'shipping'].contains(deliveryType)) {
      problem = 'Escolha levantamento ou envio.';
    }
    if (productType != 'digital' &&
        deliveryType == 'shipping' &&
        address.isEmpty) {
      problem = 'Indique a morada de envio.';
    }
    final items = <Map<String, dynamic>>[];
    for (final raw
        in (body['photo_items'] as List? ?? const []).whereType<Map>()) {
      final id = int.tryParse('${raw['photo_id']}');
      final quantity = int.tryParse('${raw['quantity']}') ?? 0;
      final photo = _photos.where((p) => p['id'] == id).firstOrNull;
      if (photo == null || quantity < 1 || quantity > 50) {
        problem = 'A seleção de fotografias é inválida.';
        break;
      }
      items.add({
        'photo_id': photo['id'],
        'photo_number': photo['number'],
        'original_path': photo['original_path'],
        'price': _s59Euros(_unitCents),
        'quantity': quantity,
      });
    }
    if (items.isEmpty) problem ??= 'Selecione pelo menos uma fotografia.';
    if (problem != null) return _json(response, 422, {'message': problem});
    final itemsCents =
        items.fold<int>(0, (s, i) => s + _unitCents * (i['quantity'] as int));
    final filmCents = wantsFilm ? _s59FilmCents : 0;
    final shippingCents = productType != 'digital' && deliveryType == 'shipping'
        ? _s59ShippingCents
        : 0;
    final totalCents = itemsCents + filmCents + shippingCents;
    var code = '';
    do {
      code = 'S59-OFF-${_randomString(6)}';
    } while (_orders.any((o) => o['order_code'] == code));
    final now = DateTime.now().toIso8601String();
    final order = <String, dynamic>{
      'id': _orders.fold<int>(0, (m, o) => max(m, o['id'] as int? ?? 0)) + 1,
      'order_code': code,
      'customer_name': name,
      'table_label': '${body['table_label'] ?? ''}'.trim().isEmpty
          ? null
          : '${body['table_label']}'.trim(),
      'customer_phone': phone,
      'customer_email': email,
      'product_type': productType,
      'delivery_type': productType == 'digital' ? null : deliveryType,
      'delivery_address': shippingCents > 0 ? address : null,
      'wants_film': wantsFilm,
      'payment_method': 'cash',
      'status': 'pending',
      'items_total': _s59Euros(itemsCents),
      'film_fee': _s59Euros(filmCents),
      'extras_total': _s59Euros(filmCents),
      'shipping_fee': _s59Euros(shippingCents),
      'total_amount': _s59Euros(totalCents),
      'cash_received_amount': null,
      'cash_change_amount': null,
      'cash_due_amount': null,
      'cash_change_given': false,
      'notes': '',
      'device': device,
      'created_at': now,
      'updated_at': now,
      'items': items,
      'payments': <Map<String, dynamic>>[],
    };
    _orders.add(order);
    log(
        'guest',
        device,
        'order.create',
        'Pedido $code criado: ${items.length} fotografias, total ${_s59Money(totalCents)}',
        {'order_code': code});
    await _save();
    final receipt = {
      'order_code': code,
      'status': 'pending',
      'total_amount': order['total_amount'],
      'shipping_fee': order['shipping_fee'],
      'delivery_type': order['delivery_type'],
    };
    return _json(response, 201,
        {'order': receipt, 'data': receipt, 'offline_mode': true});
  }

  Future<void> _markPaid(HttpResponse response, Map<String, dynamic> order,
      Map<String, dynamic> body, String device) async {
    final received = _s59Cents(body['cash_received_amount']);
    final change = _s59Cents(body['cash_change_amount']) ?? 0;
    final due = _s59Cents(body['cash_due_amount']) ?? 0;
    if (received == null)
      return _json(response, 422, {'message': 'Valor recebido inválido.'});
    final now = DateTime.now().toIso8601String();
    order
      ..['cash_received_amount'] = _s59Euros(received)
      ..['cash_change_amount'] = _s59Euros(change)
      ..['cash_due_amount'] = _s59Euros(due)
      ..['cash_change_given'] = change > 0 && body['cash_change_given'] == true
      ..['notes'] = '${body['notes'] ?? order['notes'] ?? ''}'
      ..['status'] = due > 0 ? 'pending' : 'paid'
      ..['paid_at'] = due > 0 ? order['paid_at'] : now
      ..['attended_by'] = _session['staff_username']
      ..['updated_at'] = now;
    (order['payments'] as List? ??
            (order['payments'] = <Map<String, dynamic>>[]) as List)
        .add({
      'at': now,
      'device': device,
      'received_total': _s59Euros(received),
      'change': _s59Euros(change),
      'due': _s59Euros(due),
      'change_given': order['cash_change_given'],
    });
    log(
        'staff',
        device,
        'order.payment',
        'Pagamento em ${order['order_code']}: recebido ${_s59Money(received)}, troco ${_s59Money(change)}, em dívida ${_s59Money(due)}',
        {'order_code': order['order_code']});
    await _save();
    return _json(response, 200, {
      'message': 'Order marked paid',
      'download_link_emailed': false,
      'data': _orderRow(order)
    });
  }

  Future<void> _updateOrder(HttpResponse response, Map<String, dynamic> order,
      Map<String, dynamic> body, String device) async {
    final before = Map<String, dynamic>.from(order)
      ..remove('items')
      ..remove('payments');
    for (final key in const [
      'customer_name',
      'customer_email',
      'customer_phone',
      'notes'
    ]) {
      if (body.containsKey(key)) order[key] = '${body[key] ?? ''}';
    }
    if (const ['pending', 'paid', 'delivered', 'cancelled']
        .contains(body['status'])) {
      order['status'] = body['status'];
    }
    for (final key in const [
      'cash_received_amount',
      'cash_change_amount',
      'cash_due_amount'
    ]) {
      if (body.containsKey(key)) {
        final cents = _s59Cents(body[key]);
        if (cents != null) order[key] = _s59Euros(cents);
      }
    }
    if (body['cash_change_given'] is bool)
      order['cash_change_given'] = body['cash_change_given'];
    order['updated_at'] = DateTime.now().toIso8601String();
    final changes = <String, dynamic>{};
    for (final entry in before.entries) {
      if ('${order[entry.key]}' != '${entry.value}') {
        changes[entry.key] = {'de': entry.value, 'para': order[entry.key]};
      }
    }
    log(
        'staff',
        device,
        'order.update',
        'Alterou o pedido ${order['order_code']}',
        {'order_code': order['order_code'], 'changes': changes});
    await _save();
    return _json(response, 200, {'data': _orderRow(order)});
  }

  Future<void> _faceSearch(
      HttpRequest request, HttpResponse response, String device) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
      if (builder.length > 12 * 1024 * 1024)
        return _json(
            response, 413, {'message': 'A selfie é demasiado grande.'});
    }
    final selfie = _s59MultipartFile(builder.takeBytes(),
        request.headers.value('content-type') ?? '', 'selfie');
    if (selfie == null || selfie.isEmpty)
      return _json(response, 422, {'message': 'Envie uma selfie.'});
    final result = await _faces.search(selfie, _photos);
    final status = result['status'] as int;
    if (status != 200)
      return _json(response, status, {'message': result['message']});
    final host = request.headers.host ?? _ip;
    final port = request.headers.port ?? _s59Port;
    final suggested = [
      for (final match
          in (result['matches'] as List).cast<Map<String, dynamic>>())
        {
          'id': match['photo']['id'],
          'number': match['photo']['number'],
          'filename': match['photo']['filename'],
          'preview_url':
              'http://$host:$port/offline/previews/${match['photo']['id']}?w=$_s59PreviewWidth',
          'score': match['score'],
        },
    ];
    log('guest', device, 'face.search',
        'Pesquisa facial: ${suggested.length} fotografias sugeridas', null);
    await _save();
    return _json(
        response, 200, {'suggested': suggested, 'pending': result['pending']});
  }

  Future<void> _servePreview(HttpRequest request, int id) async {
    final response = request.response;
    final path = _photoPaths[id];
    if (path == null)
      return _json(response, 404, {'message': 'Fotografia não encontrada.'});
    final width = (int.tryParse(request.uri.queryParameters['w'] ?? '') ??
            _s59PreviewWidth)
        .clamp(200, 1600);
    final bytes = await _preview(id, path, width);
    if (bytes == null)
      return _json(response, 500,
          {'message': 'Não foi possível gerar a pré-visualização.'});
    response.headers
      ..contentType = ContentType('image', 'jpeg')
      ..set('Cache-Control', 'public, max-age=86400');
    response.add(bytes);
    await response.close();
  }

  Future<Uint8List?> _preview(int id, String path, int width) {
    final key = '$id-$width';
    return _previewJobs[key] ??= _buildPreview(id, path, width).then((value) {
      if (value == null) _previewJobs.remove(key);
      return value;
    });
  }

  Future<Uint8List?> _buildPreview(int id, String path, int width) async {
    final folder = _folder;
    if (folder == null) return null;
    final cacheDir =
        Directory('${folder.path}${Platform.pathSeparator}.studio59_previews');
    final cache =
        File('${cacheDir.path}${Platform.pathSeparator}${id}_$width.jpg');
    if (await cache.exists()) return cache.readAsBytes();
    if (_previewSlots <= 0) {
      final waiter = Completer<void>();
      _previewQueue.add(waiter);
      await waiter.future;
    }
    _previewSlots--;
    try {
      final source = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(source, targetWidth: width);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = image.width;
      final h = image.height;
      image.dispose();
      codec.dispose();
      if (raw == null) return null;
      final picture = img.Image.fromBytes(
          width: w,
          height: h,
          bytes: raw.buffer,
          numChannels: 4,
          order: img.ChannelOrder.rgba);
      final jpg = img.encodeJpg(picture, quality: 80);
      try {
        await cacheDir.create(recursive: true);
        await cache.writeAsBytes(jpg, flush: true);
      } catch (_) {}
      return jpg;
    } catch (_) {
      return null;
    } finally {
      _previewSlots++;
      if (_previewQueue.isNotEmpty) _previewQueue.removeAt(0).complete();
    }
  }

  Future<void> _warmPreviews() async {
    for (final entry in Map<int, String>.from(_photoPaths).entries) {
      if (!running) return;
      await _preview(entry.key, entry.value, _s59PreviewWidth);
    }
  }
}

// ---- Reconhecimento facial offline (SCRFD det_10g + ArcFace w600k_mbf, ONNX) ----
// Mesmo algoritmo do InsightFace (validado contra ele: semelhança 0,9999 nos embeddings).

class _S59Face {
  _S59Face(this.box, this.score, this.kps);
  final List<double> box; // x1, y1, x2, y2 (píxeis da imagem descodificada)
  final double score;
  final List<double> kps; // 5 pontos (x, y)
  double get area => max(0, box[2] - box[0]) * max(0, box[3] - box[1]);
}

class _S59Rgba {
  _S59Rgba(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

class _S59FaceEngine {
  _S59FaceEngine(this._det, this._rec);
  final OrtSession _det;
  final OrtSession _rec;

  static const detSize = 640;
  static const _arcDst = [
    38.2946,
    51.6963,
    73.5318,
    51.5014,
    56.0252,
    71.7366,
    41.5493,
    92.3655,
    70.7299,
    92.2041,
  ];

  static bool _envReady = false;

  static Future<_S59FaceEngine> open(String detPath, String recPath) async {
    if (!_envReady) {
      OrtEnv.instance.init();
      _envReady = true;
    }
    final options = OrtSessionOptions();
    // fromBuffer: o fromFile do plugin falha com caminhos no Windows (codificação do caminho).
    final det =
        OrtSession.fromBuffer(await File(detPath).readAsBytes(), options);
    final rec =
        OrtSession.fromBuffer(await File(recPath).readAsBytes(), options);
    return _S59FaceEngine(det, rec);
  }

  Future<void> close() async {
    await _det.release();
    await _rec.release();
  }

  /// Corre o modelo numa isolate própria (não bloqueia o ecrã) e devolve as saídas achatadas.
  static Future<List<List<double>>> _run(
      OrtSession session, Float32List data, List<int> shape) async {
    final input = OrtValueTensor.createTensorWithDataList(data, shape);
    final runOptions = OrtRunOptions();
    try {
      final outputs = await session.runAsyncWithTimeout(runOptions,
              {session.inputNames.first: input}, const Duration(seconds: 60)) ??
          const <OrtValue?>[];
      final result = <List<double>>[];
      for (final value in outputs) {
        final flat = <double>[];
        void walk(dynamic v) {
          if (v is num) {
            flat.add(v.toDouble());
          } else if (v is List) {
            for (final e in v) {
              walk(e);
            }
          }
        }

        walk(value?.value);
        result.add(flat);
        value?.release();
      }
      return result;
    } finally {
      input.release();
      runOptions.release();
    }
  }

  /// Descodifica JPEG/PNG com o descodificador nativo, limitando o lado maior.
  static Future<_S59Rgba?> decode(Uint8List encoded,
      {int maxSide = 1280}) async {
    final probe = await ui.ImmutableBuffer.fromUint8List(encoded);
    final descriptor = await ui.ImageDescriptor.encoded(probe);
    final w0 = descriptor.width, h0 = descriptor.height;
    final scale = max(w0, h0) > maxSide ? maxSide / max(w0, h0) : 1.0;
    final codec = await descriptor.instantiateCodec(
        targetWidth: max(1, (w0 * scale).round()),
        targetHeight: max(1, (h0 * scale).round()));
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final result = raw == null
        ? null
        : _S59Rgba(raw.buffer.asUint8List(), image.width, image.height);
    image.dispose();
    codec.dispose();
    descriptor.dispose();
    probe.dispose();
    return result;
  }

  /// Entrada do detetor: 640x640, RGB, (v-127.5)/128, imagem no canto superior esquerdo.
  static (Float32List, double) _detBlob(_S59Rgba img) {
    final w = img.width, h = img.height;
    int nw, nh;
    if (h / w > 1) {
      nh = detSize;
      nw = (nh / (h / w)).floor();
    } else {
      nw = detSize;
      nh = (nw * (h / w)).floor();
    }
    final scale = nh / h;
    final plane = detSize * detSize;
    final out = Float32List(3 * plane)
      ..fillRange(0, 3 * plane, (0 - 127.5) / 128.0);
    final sx = w / nw, sy = h / nh;
    final src = img.bytes;
    for (var y = 0; y < nh; y++) {
      var fy = (y + 0.5) * sy - 0.5;
      if (fy < 0) fy = 0;
      var y0 = fy.floor();
      if (y0 > h - 1) y0 = h - 1;
      final y1 = y0 + 1 < h ? y0 + 1 : h - 1;
      final wy = fy - y0;
      for (var x = 0; x < nw; x++) {
        var fx = (x + 0.5) * sx - 0.5;
        if (fx < 0) fx = 0;
        var x0 = fx.floor();
        if (x0 > w - 1) x0 = w - 1;
        final x1 = x0 + 1 < w ? x0 + 1 : w - 1;
        final wx = fx - x0;
        final i00 = (y0 * w + x0) * 4, i01 = (y0 * w + x1) * 4;
        final i10 = (y1 * w + x0) * 4, i11 = (y1 * w + x1) * 4;
        final o = y * detSize + x;
        for (var c = 0; c < 3; c++) {
          final top = src[i00 + c] * (1 - wx) + src[i01 + c] * wx;
          final bottom = src[i10 + c] * (1 - wx) + src[i11 + c] * wx;
          out[c * plane + o] = ((top * (1 - wy) + bottom * wy) - 127.5) / 128.0;
        }
      }
    }
    return (out, scale);
  }

  Future<List<_S59Face>> detect(_S59Rgba img,
      {double threshold = 0.5, double nms = 0.4}) async {
    final (blob, scale) = _detBlob(img);
    final values = await _run(_det, blob, [1, 3, detSize, detSize]);
    if (values.length < 9) return const [];
    final faces = <_S59Face>[];
    const strides = [8, 16, 32];
    for (var i = 0; i < 3; i++) {
      final stride = strides[i];
      final scores = values[i], boxes = values[i + 3], kps = values[i + 6];
      final fw = detSize ~/ stride;
      for (var j = 0; j < scores.length; j++) {
        if (scores[j] < threshold) continue;
        final cell = j ~/ 2; // 2 âncoras por posição
        final cx = (cell % fw) * stride.toDouble();
        final cy = (cell ~/ fw) * stride.toDouble();
        final b = j * 4, k = j * 10;
        faces.add(_S59Face(
            [
              (cx - boxes[b] * stride) / scale,
              (cy - boxes[b + 1] * stride) / scale,
              (cx + boxes[b + 2] * stride) / scale,
              (cy + boxes[b + 3] * stride) / scale,
            ],
            scores[j],
            [
              for (var t = 0; t < 5; t++) ...[
                (cx + kps[k + 2 * t] * stride) / scale,
                (cy + kps[k + 2 * t + 1] * stride) / scale,
              ],
            ]));
      }
    }
    faces.sort((a, b) => b.score.compareTo(a.score));
    final kept = <_S59Face>[];
    double area(List<double> r) => (r[2] - r[0] + 1) * (r[3] - r[1] + 1);
    for (final f in faces) {
      var keep = true;
      for (final k in kept) {
        final iw = min(f.box[2], k.box[2]) - max(f.box[0], k.box[0]) + 1;
        final ih = min(f.box[3], k.box[3]) - max(f.box[1], k.box[1]) + 1;
        final inter = max(0.0, iw) * max(0.0, ih);
        if (inter / (area(f.box) + area(k.box) - inter) > nms) {
          keep = false;
          break;
        }
      }
      if (keep) kept.add(f);
    }
    return kept;
  }

  /// Alinha o rosto a 112x112 (semelhança pelos 5 pontos) e devolve o embedding normalizado.
  Future<Float32List> embed(_S59Rgba img, _S59Face face) async {
    // Transformação de semelhança src(kps) -> dst(template ArcFace), mínimos quadrados.
    var mx = 0.0, my = 0.0, mu = 0.0, mv = 0.0;
    for (var t = 0; t < 5; t++) {
      mx += face.kps[2 * t];
      my += face.kps[2 * t + 1];
      mu += _arcDst[2 * t];
      mv += _arcDst[2 * t + 1];
    }
    mx /= 5;
    my /= 5;
    mu /= 5;
    mv /= 5;
    var num1 = 0.0, num2 = 0.0, den = 0.0;
    for (var t = 0; t < 5; t++) {
      final x = face.kps[2 * t] - mx, y = face.kps[2 * t + 1] - my;
      final u = _arcDst[2 * t] - mu, v = _arcDst[2 * t + 1] - mv;
      num1 += x * u + y * v;
      num2 += x * v - y * u;
      den += x * x + y * y;
    }
    final a = num1 / den, b = num2 / den;
    final tx = mu - (a * mx - b * my), ty = mv - (b * mx + a * my);
    // Inversa: src = A^-1 (dst - t), com A = [[a,-b],[b,a]].
    final det = a * a + b * b;
    final ia = a / det, ib = b / det;
    const size = 112, plane = size * size;
    final out = Float32List(3 * plane);
    final w = img.width, h = img.height, src = img.bytes;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final dx = x - tx, dy = y - ty;
        final sx = ia * dx + ib * dy;
        final sy = -ib * dx + ia * dy;
        final x0 = sx.floor(), y0 = sy.floor();
        final fx = sx - x0, fy = sy - y0;
        final o = y * size + x;
        for (var c = 0; c < 3; c++) {
          var acc = 0.0;
          for (var oy = 0; oy < 2; oy++) {
            final yy = y0 + oy;
            if (yy < 0 || yy >= h) continue;
            final wy = oy == 0 ? 1 - fy : fy;
            for (var ox = 0; ox < 2; ox++) {
              final xx = x0 + ox;
              if (xx < 0 || xx >= w) continue;
              final wx = ox == 0 ? 1 - fx : fx;
              acc += src[(yy * w + xx) * 4 + c] * wx * wy;
            }
          }
          out[c * plane + o] = (acc - 127.5) / 127.5;
        }
      }
    }
    final raw = (await _run(_rec, out, [1, 3, size, size])).first;
    var norm = 0.0;
    for (final e in raw) {
      norm += e * e;
    }
    norm = sqrt(norm);
    return Float32List.fromList(
        [for (final e in raw) norm == 0 ? 0 : e / norm]);
  }

  /// Todos os rostos de uma imagem (embeddings normalizados).
  Future<List<Float32List>> faces(Uint8List encoded,
      {bool foregroundOnly = false}) async {
    final img = await decode(encoded);
    if (img == null) return const [];
    var found = await detect(img);
    if (foregroundOnly && found.isNotEmpty) {
      final largest = found.map((f) => f.area).reduce(max);
      found = found
          .where((f) => f.area >= largest * 0.25 && f.score >= 0.6)
          .toList();
    }
    return [for (final f in found) await embed(img, f)];
  }

  static double similarity(List<double> a, List<double> b) {
    var s = 0.0;
    for (var i = 0; i < a.length && i < b.length; i++) {
      s += a[i] * b[i];
    }
    return s;
  }
}

// ---- Índice de rostos da sessão offline (no computador anfitrião) ----

const _s59FaceModelsUrl = 'https://studio59.wiredevelop.pt/face-models';
const _s59FaceModelFiles = {
  'det_10g.onnx': 16923827,
  'w600k_mbf.onnx': 13616099
};
const _s59FaceThreshold = 0.52;
const _s59FaceIndexFile = '.studio59_rostos.json';

class _S59FaceIndex {
  _S59FaceEngine? _engine;
  Future<void> _lock = Future.value();
  bool _running = false;
  bool _stopping = false;
  String? _problem;
  Directory? _folder;
  // id da fotografia -> {mtime, e: [[512 valores], ...]}
  Map<String, dynamic> _index = {};

  static Future<Directory> _modelsDir() async {
    final base = await getApplicationSupportDirectory();
    return Directory(
        '${base.path}${Platform.pathSeparator}studio59_face_models');
  }

  /// Descarrega os modelos (só com internet; ficam guardados para as sessões offline).
  static Future<bool> ensureModels() async {
    if (!_s59Desktop) return false;
    try {
      final dir = await _modelsDir();
      await dir.create(recursive: true);
      for (final entry in _s59FaceModelFiles.entries) {
        final file = File('${dir.path}${Platform.pathSeparator}${entry.key}');
        if (await file.exists() && await file.length() == entry.value) continue;
        final response = await http
            .get(Uri.parse('$_s59FaceModelsUrl/${entry.key}'))
            .timeout(const Duration(minutes: 5));
        if (response.statusCode != 200 ||
            response.bodyBytes.length != entry.value) return false;
        final temp = File('${file.path}.tmp');
        await temp.writeAsBytes(response.bodyBytes, flush: true);
        await temp.rename(file.path);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> modelsReady() async {
    try {
      final dir = await _modelsDir();
      for (final entry in _s59FaceModelFiles.entries) {
        final file = File('${dir.path}${Platform.pathSeparator}${entry.key}');
        if (!await file.exists() || await file.length() != entry.value)
          return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<T> _exclusive<T>(Future<T> Function() task) {
    final previous = _lock;
    final done = Completer<void>();
    _lock = done.future;
    return previous.then((_) => task()).whenComplete(done.complete);
  }

  Future<_S59FaceEngine?> _openEngine() async {
    if (_engine != null) return _engine;
    if (!await modelsReady() && !await ensureModels()) {
      _problem =
          'O reconhecimento facial offline ainda não foi preparado: abra a app neste computador com internet uma vez para descarregar os modelos.';
      return null;
    }
    final dir = await _modelsDir();
    final sep = Platform.pathSeparator;
    _engine = await _S59FaceEngine.open(
        '${dir.path}${sep}det_10g.onnx', '${dir.path}${sep}w600k_mbf.onnx');
    _problem = null;
    return _engine;
  }

  File _indexFile(Directory folder) =>
      File('${folder.path}${Platform.pathSeparator}$_s59FaceIndexFile');

  Future<void> start(
      Directory folder,
      List<Map<String, dynamic>> Function() photos,
      Map<int, String> paths) async {
    _folder = folder;
    _stopping = false;
    try {
      final file = _indexFile(folder);
      if (await file.exists()) {
        _index = Map<String, dynamic>.from(
            jsonDecode(await file.readAsString()) as Map);
      }
    } catch (_) {
      _index = {};
    }
    if (_running) return;
    _running = true;
    try {
      while (!_stopping) {
        final engine = await _openEngine();
        if (engine == null) {
          await Future.delayed(const Duration(minutes: 1));
          continue;
        }
        var changed = 0;
        for (final photo in List<Map<String, dynamic>>.from(photos())) {
          if (_stopping) break;
          final id = int.tryParse('${photo['id']}') ?? 0;
          final path = paths[id];
          if (path == null) continue;
          final file = File(path);
          int mtime;
          try {
            mtime = (await file.lastModified()).millisecondsSinceEpoch;
          } catch (_) {
            continue;
          }
          final entry = _index['$id'];
          if (entry is Map && entry['mtime'] == mtime) continue;
          try {
            final bytes = await file.readAsBytes();
            final faces = await _exclusive(() => engine.faces(bytes));
            _index['$id'] = {
              'mtime': mtime,
              'e': [
                for (final f in faces)
                  [for (final v in f) double.parse(v.toStringAsFixed(5))]
              ],
            };
          } catch (_) {
            _index['$id'] = {'mtime': mtime, 'e': const []};
          }
          if (++changed % 20 == 0) await _saveIndex();
        }
        if (changed > 0) await _saveIndex();
        // Volta a verificar fotografias novas de minuto a minuto.
        for (var i = 0; i < 60 && !_stopping; i++) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _saveIndex() async {
    final folder = _folder;
    if (folder == null) return;
    try {
      final file = _indexFile(folder);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(_index), flush: true);
      await temp.rename(file.path);
    } catch (_) {}
  }

  Future<void> stop() async {
    _stopping = true;
    await _saveIndex();
  }

  int pending(List<Map<String, dynamic>> photos) =>
      photos.where((p) => !_index.containsKey('${p['id']}')).length;

  /// Pesquisa por selfie: junta as fotografias de todas as pessoas em primeiro plano.
  Future<Map<String, dynamic>> search(
      Uint8List selfie, List<Map<String, dynamic>> photos) async {
    final engine = await _openEngine();
    if (engine == null) return {'status': 503, 'message': _problem};
    final query =
        await _exclusive(() => engine.faces(selfie, foregroundOnly: true));
    if (query.isEmpty)
      return {'status': 422, 'message': 'Nenhum rosto detetado.'};
    final scored = <Map<String, dynamic>>[];
    for (final photo in photos) {
      final entry = _index['${photo['id']}'];
      if (entry is! Map) continue;
      var best = 0.0;
      for (final e in (entry['e'] as List? ?? const [])) {
        final vector =
            (e as List).cast<num>().map((v) => v.toDouble()).toList();
        for (final q in query) {
          best = max(best, _S59FaceEngine.similarity(q, vector));
        }
      }
      if (best >= _s59FaceThreshold)
        scored.add({'photo': photo, 'score': best});
    }
    scored
        .sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return {
      'status': 200,
      'matches': scored.take(200).toList(),
      'pending': pending(photos)
    };
  }
}

/// Lê o ficheiro de um campo multipart/form-data (sem dependências externas).
Uint8List? _s59MultipartFile(Uint8List body, String contentType, String field) {
  final match =
      RegExp(r'boundary=(?:"([^"]+)"|([^;]+))').firstMatch(contentType);
  if (match == null) return null;
  final boundary =
      utf8.encode('--${(match.group(1) ?? match.group(2))!.trim()}');
  int indexOf(List<int> pattern, int from) {
    outer:
    for (var i = from; i <= body.length - pattern.length; i++) {
      for (var j = 0; j < pattern.length; j++) {
        if (body[i + j] != pattern[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  const headerEnd = [13, 10, 13, 10];
  var start = indexOf(boundary, 0);
  while (start >= 0) {
    final headersStart = start + boundary.length + 2;
    final headersStop = indexOf(headerEnd, headersStart);
    if (headersStop < 0) return null;
    final headers = latin1.decode(body.sublist(headersStart, headersStop));
    final next = indexOf(boundary, headersStop + 4);
    if (next < 0) return null;
    if (RegExp('name="${RegExp.escape(field)}"').hasMatch(headers)) {
      var end = next - 2; // \r\n antes da fronteira
      if (end < headersStop + 4) end = headersStop + 4;
      return Uint8List.sublistView(body, headersStop + 4, end);
    }
    start = next;
  }
  return null;
}
