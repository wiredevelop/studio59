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

/// Remove metadados de apresentação e prepara apenas IDs e quantidades para o
/// pedido.
dynamic toOrderPhotoItems(List<Studio59CartPhotoStruct>? items) {
  if (items == null || items.isEmpty) return <Map<String, dynamic>>[];
  final result = <Map<String, dynamic>>[];
  for (final item in items) {
    final id = item.photoId;
    final quantity = item.quantity;
    if (id == null ||
        id <= 0 ||
        quantity == null ||
        quantity < 1 ||
        quantity > 50) {
      return <Map<String, dynamic>>[];
    }
    result.add({'photo_id': id, 'quantity': quantity});
  }
  return result;
}
