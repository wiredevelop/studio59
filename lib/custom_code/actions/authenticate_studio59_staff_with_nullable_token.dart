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

Future<Studio59StaffAuthResultStruct>
    authenticateStudio59StaffWithNullableToken(
  String username,
  String password,
  dynamic token,
) async {
  final base = (FFAppState().offlineApiBase.isNotEmpty
      ? FFAppState().offlineApiBase
      : 'https://studio59.wiredevelop.pt/api');
  final client = http.Client();
  try {
    var authToken = (token ?? '').toString().trim();
    if (authToken.isEmpty) {
      final loginResponse = await client
          .post(
            Uri.parse('$base/auth/login'),
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
            : 'Não foi possível iniciar sessão (${loginResponse.statusCode}).';
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
            message: 'A API não devolveu um token de sessão.');
      }
    }

    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $authToken'
    };
    final meResponse = await client
        .get(
          Uri.parse('$base/auth/me'),
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
          : 'A sessão não foi confirmada (${meResponse.statusCode}).';
      return Studio59StaffAuthResultStruct(
          success: false, statusCode: meResponse.statusCode, message: message);
    }
    final meData = meBody['data'] is Map ? meBody['data'] as Map : meBody;
    final user = meData['user'] is Map ? meData['user'] as Map : meData;
    final userName = (user['name'] ?? user['username'] ?? username).toString();
    final userRole =
        (user['role'] ?? user['user_type'] ?? '').toString().toLowerCase();
    final isAdmin = userRole == 'admin' || userRole == 'administrator';

    return Studio59StaffAuthResultStruct(
      success: true,
      statusCode: 200,
      message: isAdmin ? 'admin' : '',
      token: authToken,
      userName: userName,
      events: const <Studio59StaffEventStruct>[],
    );
  } catch (error) {
    return Studio59StaffAuthResultStruct(
        success: false,
        statusCode: 0,
        message:
            'Não foi possível contactar o servidor: ${error.runtimeType}. Verifique a ligação e tente novamente.');
  } finally {
    client.close();
  }
}
