import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '/flutter_flow/custom_functions.dart';
import '/flutter_flow/lat_lng.dart';
import '/flutter_flow/place.dart';
import '/flutter_flow/uploaded_file.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/ff_builtin_enums.dart';

/// Exige morada apenas quando a opção de envio está selecionada.
bool? studio59HasDeliveryAddress(
  String? deliveryType,
  String? address,
) {
  if (deliveryType == null) return false;
  if (deliveryType == 'shipping') return address?.trim().isNotEmpty == true;
  return deliveryType == 'pickup' || deliveryType == 'store_pickup';
}
