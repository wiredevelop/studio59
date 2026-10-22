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
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Studio59GuestSessionResultStruct> enterStudio59GuestSessionSafely(
  String credential,
  bool isQr,
) async {
  var value = credential.trim();
  // Link completo do QR online (…/public/events/qr/<token>): usa só o token.
  if (isQr && !value.startsWith('S59OFF_') && value.contains('/qr/')) {
    final segments = Uri.tryParse(value)?.pathSegments ?? const <String>[];
    final i = segments.lastIndexOf('qr');
    if (i >= 0 && i + 1 < segments.length) value = segments[i + 1];
  }
  if (value.isEmpty) {
    return Studio59GuestSessionResultStruct(
      success: false,
      statusCode: 422,
      message: 'Introduza um PIN ou leia um QR válido.',
    );
  }
  const onlineBase = 'https://studio59.wiredevelop.pt/api';
  // PIN: sessão offline se o tablet estiver ligado a uma; senão o servidor online.
  // QR: o QR de um evento online vai SEMPRE para o servidor online (mesmo que o tablet
  // tenha ficado ligado a uma sessão offline antiga); só o QR «S59OFF_» vai para o computador.
  var base = isQr
      ? onlineBase
      : (FFAppState().offlineApiBase.isNotEmpty
          ? FFAppState().offlineApiBase
          : onlineBase);
  var offlineQr = false;
  if (isQr && value.startsWith('S59OFF_')) {
    // QR de uma sessão offline: S59OFF_<ip com hífenes>_<porta>_<segredo>.
    final parts = value.split('_');
    if (parts.length >= 4) {
      base = 'http://${parts[1].replaceAll('-', '.')}:${parts[2]}/api';
      offlineQr = true;
    }
  }
  Future<http.Response> send(String b) {
    final uri = isQr
        ? Uri.parse('$b/public/events/qr/${Uri.encodeComponent(value)}')
        : Uri.parse('$b/public/events/pin');
    return (isQr
            ? http.get(uri, headers: {'Accept': 'application/json'})
            : http.post(
                uri,
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json'
                },
                body: jsonEncode({'pin': value}),
              ))
        .timeout(const Duration(seconds: 12));
  }

  try {
    http.Response result;
    try {
      result = await send(base);
    } catch (_) {
      if (!offlineQr) rethrow;
      // O endereço do QR não respondeu (ex.: placa de rede virtual no computador): procura a sessão na rede.
      final found = jsonDecode(await studio59Offline('discover', '{}'));
      if (found is! Map || found['base'] is! String) rethrow;
      base = found['base'] as String;
      result = await send(base);
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(result.body);
    } catch (_) {}
    final payload =
        decoded is Map && decoded['data'] is Map ? decoded['data'] : decoded;
    if (result.statusCode >= 200 &&
        result.statusCode < 300 &&
        payload is Map &&
        payload['event_session_token'] is String &&
        (payload['event_session_token'] as String).isNotEmpty &&
        payload['event'] is Map) {
      if (offlineQr) {
        FFAppState().offlineApiBase = base;
      } else if (isQr) {
        FFAppState().offlineApiBase = ''; // catálogo online
      }
      return Studio59GuestSessionResultStruct(
        success: true,
        statusCode: result.statusCode,
        message: '',
        eventSessionToken: payload['event_session_token'] as String,
        event: _studio59EventFromApi(payload['event']),
      );
    }
    final message = decoded is Map && decoded['message'] is String
        ? decoded['message'] as String
        : 'A API rejeitou a entrada (${result.statusCode}).';
    return Studio59GuestSessionResultStruct(
      success: false,
      statusCode: result.statusCode,
      message: message,
    );
  } catch (error) {
    return Studio59GuestSessionResultStruct(
      success: false,
      statusCode: 0,
      message: offlineQr || (!isQr && base != onlineBase)
          ? 'Não foi possível contactar o computador da sessão offline. Confirme que está ligado à mesma rede Wi-Fi.'
          : 'Não foi possível contactar o servidor. Verifique a internet e tente novamente.',
    );
  }
}

Studio59EventInfoStruct? _studio59EventFromApi(dynamic value) {
  if (value is! Map) return null;
  final event = Map<String, dynamic>.from(value);
  final price = event['price_per_photo'];
  if (price is String) {
    event['price_per_photo'] = double.tryParse(price);
  }
  return Studio59EventInfoStruct.maybeFromMap(event);
}
