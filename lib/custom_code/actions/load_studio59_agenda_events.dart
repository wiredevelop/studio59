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

Future<String> loadStudio59AgendaEvents(String? token) async {
  final authToken = (token ?? '').trim();
  if (authToken.isEmpty) {
    return jsonEncode(
        {'error': 'Sessão da equipa indisponível. Volte a iniciar sessão.'});
  }
  final client = http.Client();
  try {
    final events = <dynamic>[];
    var page = 1;
    var lastPage = 1;
    do {
      final response = await client.get(
        Uri.https('studio59.wiredevelop.pt', '/api/events',
            {'page': '$page', 'per_page': '100'}),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken'
        },
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
            'A API recusou o carregamento da agenda (${response.statusCode}).');
      }
      final body = jsonDecode(response.body);
      if (body is! Map)
        throw const FormatException('Resposta inválida da agenda.');
      final data = body['data'];
      final rows = data is List
          ? data
          : (data is Map && data['data'] is List
              ? data['data'] as List
              : <dynamic>[]);
      events.addAll(
          rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)));
      final meta = data is Map ? data : body;
      lastPage =
          int.tryParse('${meta['last_page'] ?? body['last_page'] ?? 1}') ?? 1;
      page++;
    } while (page <= lastPage && page <= 100);
    return jsonEncode(events);
  } finally {
    client.close();
  }
}
