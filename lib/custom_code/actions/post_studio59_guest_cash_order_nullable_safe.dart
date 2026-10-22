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
import 'package:shared_preferences/shared_preferences.dart';

Future<Studio59GuestCashSubmitResultStruct>
    postStudio59GuestCashOrderNullableSafe(
  dynamic rawEventId,
  dynamic rawToken,
  dynamic rawCustomerName,
  dynamic rawCustomerPhone,
  dynamic rawCustomerEmail,
  dynamic rawProductType,
  dynamic photoItems,
  dynamic rawWantsFilm,
  dynamic rawDeliveryType,
  dynamic rawDeliveryAddress,
) async {
  final eventId = rawEventId is int
      ? rawEventId
      : int.tryParse(rawEventId?.toString() ?? '');
  final token = rawToken is String ? rawToken : '';
  final customerName = rawCustomerName is String ? rawCustomerName.trim() : '';
  final customerPhone =
      rawCustomerPhone is String ? rawCustomerPhone.trim() : '';
  final customerEmail =
      rawCustomerEmail is String ? rawCustomerEmail.trim() : '';
  final productType = rawProductType is String ? rawProductType : '';
  final deliveryType = rawDeliveryType is String ? rawDeliveryType : '';
  final deliveryAddress =
      rawDeliveryAddress is String ? rawDeliveryAddress.trim() : '';
  final wantsFilm = rawWantsFilm == true;
  if (eventId == null || eventId <= 0 || token.trim().isEmpty) {
    return Studio59GuestCashSubmitResultStruct(
        success: false,
        statusCode: 401,
        uncertain: false,
        message: 'Sessão do evento inválida.');
  }
  String? validation;
  if (customerName.isEmpty) validation = 'Introduza o nome.';
  // Email obrigatório só com fotografias digitais (formato digital ou ambos).
  if ((productType == 'digital' || productType == 'both') &&
      customerEmail.isEmpty)
    validation = 'Para fotografias digitais indique o email.';
  if (customerEmail.isNotEmpty && !customerEmail.contains('@'))
    validation = 'Introduza um email válido.';
  if (!['paper', 'digital', 'both'].contains(productType))
    validation = 'Escolha o formato das fotografias.';
  final items = <Map<String, dynamic>>[];
  if (photoItems is List && photoItems.isNotEmpty) {
    for (final item in photoItems) {
      if (item is! Map ||
          item['photo_id'] is! int ||
          item['photo_id'] <= 0 ||
          item['quantity'] is! int ||
          item['quantity'] < 1 ||
          item['quantity'] > 50) {
        validation = 'A seleção de fotografias é inválida.';
        break;
      }
      items.add({'photo_id': item['photo_id'], 'quantity': item['quantity']});
    }
  } else {
    validation = 'Selecione pelo menos uma fotografia.';
  }
  if (productType != 'digital' &&
      !['couple', 'pickup', 'store_pickup', 'shipping']
          .contains(deliveryType)) {
    validation = 'Escolha como quer receber as fotografias.';
  }
  if (productType != 'digital' &&
      deliveryType == 'shipping' &&
      deliveryAddress.isEmpty) {
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
  // Mesa indicada no checkout (guardada pelo widget de checkout).
  var tableLabel = '';
  try {
    tableLabel = (await SharedPreferences.getInstance())
            .getString('studio59_table_label')
            ?.trim() ??
        '';
  } catch (_) {}
  try {
    final response = await http.post(
      Uri.parse(
          '${(FFAppState().offlineApiBase.isNotEmpty ? FFAppState().offlineApiBase : 'https://studio59.wiredevelop.pt/api')}/public/orders'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'event_id': eventId,
        'customer_name': customerName,
        if (tableLabel.isNotEmpty) 'table_label': tableLabel,
        if (customerPhone.isNotEmpty) 'customer_phone': customerPhone,
        if (customerEmail.isNotEmpty) 'customer_email': customerEmail,
        'payment_method': 'cash',
        'product_type': productType,
        'photo_items': items,
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
