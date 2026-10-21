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

Future<Studio59MarkPaidResultStruct> postStudio59MarkPaidWithCash(
  int orderId,
  String token,
  String cashReceived,
  String cashChange,
  String cashDue,
  bool cashChangeGiven,
  String notes,
) async {
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(cashReceived)) {
    return Studio59MarkPaidResultStruct(
      success: false,
      statusCode: 422,
      message: 'Introduza um montante recebido válido.',
    );
  }
  try {
    final response = await http.post(
      Uri.parse(
          'https://studio59.wiredevelop.pt/api/orders/$orderId/mark-paid'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'cash_received_amount': cashReceived,
        'cash_change_amount': cashChange,
        'cash_due_amount': cashDue,
        'cash_change_given': cashChangeGiven,
        'notes': notes,
      }),
    );
    var message = '';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) message = (decoded['message'] ?? '').toString();
    } catch (_) {}
    return Studio59MarkPaidResultStruct(
      success: response.statusCode >= 200 && response.statusCode < 300,
      statusCode: response.statusCode,
      message: message,
    );
  } catch (_) {
    return Studio59MarkPaidResultStruct(
        success: false, statusCode: 0, message: 'network');
  }
}
