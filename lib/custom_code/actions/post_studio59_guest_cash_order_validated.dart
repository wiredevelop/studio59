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

Future<Studio59GuestCashSubmitResultStruct> postStudio59GuestCashOrderValidated(
  int eventId,
  String token,
  String customerName,
  String customerPhone,
  String customerEmail,
  String productType,
  dynamic photoItems,
  bool wantsFilm,
  String deliveryType,
  String deliveryAddress,
) async {
  String? validation;
  if (customerName.trim().isEmpty) validation = 'Introduza o nome.';
  if (customerPhone.trim().isEmpty) validation = 'Introduza o telefone.';
  if (customerEmail.trim().isEmpty || !customerEmail.contains('@'))
    validation = 'Introduza um email válido.';
  if (productType != 'digital' &&
      !['pickup', 'store_pickup', 'shipping'].contains(deliveryType)) {
    validation = 'Escolha levantamento ou envio.';
  }
  if (productType != 'digital' &&
      deliveryType == 'shipping' &&
      deliveryAddress.trim().isEmpty) {
    validation = 'Indique a morada de envio.';
  }
  if (validation != null) {
    return Studio59GuestCashSubmitResultStruct(
      success: false,
      statusCode: 422,
      uncertain: false,
      message: validation,
    );
  }
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
        if (productType != 'digital') 'delivery_type': deliveryType,
        if (productType != 'digital' && deliveryType == 'shipping')
          'delivery_address': deliveryAddress,
      }),
    );
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {}
    final payload = decoded is Map
        ? (decoded['order'] ?? decoded['data'] ?? decoded)
        : null;
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        payload is Map &&
        payload['order_code'] != null) {
      return Studio59GuestCashSubmitResultStruct(
        success: true,
        statusCode: response.statusCode,
        uncertain: false,
        message: '',
        order: Studio59OrderReceiptStruct.fromMap(
            Map<String, dynamic>.from(payload)),
      );
    }
    final message = decoded is Map && decoded['message'] != null
        ? decoded['message'].toString()
        : 'O servidor rejeitou o pedido (${response.statusCode}).';
    return Studio59GuestCashSubmitResultStruct(
      success: false,
      statusCode: response.statusCode,
      uncertain: response.statusCode >= 500,
      message: message,
    );
  } catch (_) {
    return Studio59GuestCashSubmitResultStruct(
      success: false,
      statusCode: 0,
      uncertain: true,
      message:
          'A resposta do pedido é incerta. Contacte a equipa antes de tentar novamente.',
    );
  }
}
