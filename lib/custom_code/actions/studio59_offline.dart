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
    return status();
  }

  Future<Map<String, dynamic>> stop() async {
    if (!running) return status();
    _session['closed_at'] = DateTime.now().toIso8601String();
    log('host', 'este computador', 'session.stop', 'Sessão offline terminada',
        null);
    await _save();
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
