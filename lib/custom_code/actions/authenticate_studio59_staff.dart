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

import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Studio59StaffAuthResultStruct> authenticateStudio59Staff(
  String username,
  String password,
  String token,
) async {
  final client = http.Client();
  try {
    var authToken = token.trim();
    if (authToken.isEmpty) {
      final loginResponse = await client
          .post(
            Uri.parse('https://studio59.wiredevelop.pt/api/auth/login'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json'
            },
            body: jsonEncode({'login': username.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 20));
      dynamic loginBody;
      try {
        loginBody = jsonDecode(loginResponse.body);
      } catch (_) {}
      if (loginResponse.statusCode < 200 ||
          loginResponse.statusCode >= 300 ||
          loginBody is! Map) {
        final message = loginBody is Map && loginBody['message'] is String
            ? loginBody['message'] as String
            : 'NÃ£o foi possÃ­vel iniciar sessÃ£o (${loginResponse.statusCode}).';
        return Studio59StaffAuthResultStruct(
            success: false,
            statusCode: loginResponse.statusCode,
            message: message);
      }
      final loginData =
          loginBody['data'] is Map ? loginBody['data'] as Map : loginBody;
      authToken =
          (loginData['token'] ?? loginData['access_token'] ?? '').toString();
      if (authToken.isEmpty) {
        return Studio59StaffAuthResultStruct(
            success: false,
            statusCode: loginResponse.statusCode,
            message: 'A API nÃ£o devolveu um token de sessÃ£o.');
      }
    }

    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $authToken'
    };
    final meResponse = await client
        .get(
          Uri.parse('https://studio59.wiredevelop.pt/api/auth/me'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 20));
    dynamic meBody;
    try {
      meBody = jsonDecode(meResponse.body);
    } catch (_) {}
    if (meResponse.statusCode < 200 ||
        meResponse.statusCode >= 300 ||
        meBody is! Map) {
      final message = meBody is Map && meBody['message'] is String
          ? meBody['message'] as String
          : 'A sessÃ£o nÃ£o foi confirmada (${meResponse.statusCode}).';
      return Studio59StaffAuthResultStruct(
          success: false, statusCode: meResponse.statusCode, message: message);
    }
    final meData = meBody['data'] is Map ? meBody['data'] as Map : meBody;
    final user = meData['user'] is Map ? meData['user'] as Map : meData;
    final userName = (user['name'] ?? user['username'] ?? username).toString();

    final events = <Studio59StaffEventStruct>[];
    var page = 1;
    var lastPage = 1;
    do {
      final eventsResponse = await client
          .get(
            Uri.https('studio59.wiredevelop.pt', '/api/events',
                {'page': '$page', 'per_page': '100'}),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));
      dynamic eventsBody;
      try {
        eventsBody = jsonDecode(eventsResponse.body);
      } catch (_) {}
      if (eventsResponse.statusCode < 200 ||
          eventsResponse.statusCode >= 300 ||
          eventsBody is! Map) {
        final message = eventsBody is Map && eventsBody['message'] is String
            ? eventsBody['message'] as String
            : 'NÃ£o foi possÃ­vel carregar os eventos permitidos (${eventsResponse.statusCode}).';
        return Studio59StaffAuthResultStruct(
            success: false,
            statusCode: eventsResponse.statusCode,
            message: message);
      }
      final eventsData =
          eventsBody['data'] is Map ? eventsBody['data'] as Map : eventsBody;
      final rawEvents = eventsData['data'] is List
          ? eventsData['data'] as List
          : (eventsBody['data'] is List
              ? eventsBody['data'] as List
              : <dynamic>[]);
      for (final rawEvent in rawEvents.whereType<Map>()) {
        final event = Studio59StaffEventStruct.maybeFromMap(rawEvent);
        if (event != null) events.add(event);
      }
      lastPage = int.tryParse(
              '${eventsData['last_page'] ?? eventsBody['last_page'] ?? 1}') ??
          1;
      page++;
    } while (page <= lastPage && page <= 100);

    return Studio59StaffAuthResultStruct(
      success: true,
      statusCode: 200,
      message: '',
      token: authToken,
      userName: userName,
      events: events,
    );
  } catch (_) {
    return Studio59StaffAuthResultStruct(
        success: false,
        statusCode: 0,
        message:
            'NÃ£o foi possÃ­vel contactar o servidor. Verifique a ligaÃ§Ã£o e tente novamente.');
  } finally {
    client.close();
  }
}
