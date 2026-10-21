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

Future<Studio59MarkPaidResultStruct> postStudio59MarkPaidWithCashNullableSafe(
  dynamic rawOrderId,
  dynamic rawToken,
  dynamic rawCashReceived,
  dynamic rawCashChange,
  dynamic rawCashDue,
  dynamic rawCashChangeGiven,
  dynamic rawNotes,
) async {
  final orderId = rawOrderId is int
      ? rawOrderId
      : int.tryParse(rawOrderId?.toString() ?? '');
  final token = rawToken is String ? rawToken : '';
  final cashReceived = rawCashReceived is String ? rawCashReceived.trim() : '';
  final cashChange = rawCashChange is String ? rawCashChange.trim() : '';
  final cashDue = rawCashDue is String ? rawCashDue.trim() : '';
  final cashChangeGiven = rawCashChangeGiven == true;
  final notes = rawNotes is String ? rawNotes : '';
  if (orderId == null || orderId <= 0 || token.trim().isEmpty) {
    return Studio59MarkPaidResultStruct(
        success: false, statusCode: 401, message: 'Sessão da equipa inválida.');
  }
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(cashReceived)) {
    return Studio59MarkPaidResultStruct(
      success: false,
      statusCode: 422,
      message: 'Introduza um montante recebido válido.',
    );
  }
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(cashChange) ||
      !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(cashDue)) {
    return Studio59MarkPaidResultStruct(
        success: false, statusCode: 422, message: 'Troco ou dívida inválidos.');
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
