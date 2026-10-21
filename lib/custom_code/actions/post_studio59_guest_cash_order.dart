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

Future<Studio59CashOrderResultStruct> postStudio59GuestCashOrder(
  int eventId,
  String token,
  String customerName,
  String customerPhone,
  String customerEmail,
  String productType,
  dynamic photoItems,
  bool wantsFilm,
) async {
  try {
    final response = await http.post(
      Uri.parse('https://studio59.wiredevelop.pt/api/public/orders'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'event_id': eventId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_email': customerEmail,
        'payment_method': 'cash',
        'product_type': productType,
        'photo_items': photoItems,
        'wants_film': wantsFilm,
      }),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded is Map) {
      final payload = decoded['order'] ?? decoded['data'] ?? decoded;
      if (payload is Map && payload['order_code'] != null) {
        return Studio59CashOrderResultStruct(
          success: true,
          order: Studio59OrderReceiptStruct.fromMap(
              Map<String, dynamic>.from(payload)),
        );
      }
    }
  } catch (_) {}
  return Studio59CashOrderResultStruct(success: false);
}
