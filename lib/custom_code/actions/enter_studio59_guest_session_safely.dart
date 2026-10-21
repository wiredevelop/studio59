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
  final value = credential.trim();
  if (value.isEmpty) {
    return Studio59GuestSessionResultStruct(
      success: false,
      statusCode: 422,
      message: 'Introduza um PIN ou leia um QR válido.',
    );
  }
  var base = (FFAppState().offlineApiBase.isNotEmpty
      ? FFAppState().offlineApiBase
      : 'https://studio59.wiredevelop.pt/api');
  var offlineQr = false;
  if (isQr && value.startsWith('S59OFF_')) {
    // QR de uma sessão offline: S59OFF_<ip com hífenes>_<porta>_<segredo>.
    final parts = value.split('_');
    if (parts.length >= 4) {
      base = 'http://${parts[1].replaceAll('-', '.')}:${parts[2]}/api';
      offlineQr = true;
    }
  }
  final uri = isQr
      ? Uri.parse('$base/public/events/qr/${Uri.encodeComponent(value)}')
      : Uri.parse('$base/public/events/pin');
  try {
    final response = (isQr
            ? http.get(uri, headers: {'Accept': 'application/json'})
            : http.post(
                uri,
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json'
                },
                body: jsonEncode({'pin': value}),
              ))
        .timeout(const Duration(seconds: 15));
    final result = await response;
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
      if (offlineQr) FFAppState().offlineApiBase = base;
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
      message:
          'Não foi possível contactar o servidor. Verifique a ligação e tente novamente.',
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
