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

/// Calcula troco ou dívida em cêntimos sem aritmética de ponto flutuante.
String? studio59CashDifference(
  String? received,
  dynamic total,
  bool? changeMode,
) {
  int? cents(dynamic input) {
    if (input == null) return null;
    var value = input?.toString().trim() ?? '0';
    if (value.contains(',') && value.contains('.')) {
      value = value.lastIndexOf(',') > value.lastIndexOf('.')
          ? value.replaceAll('.', '').replaceAll(',', '.')
          : value.replaceAll(',', '');
    } else {
      value = value.replaceAll(',', '.');
    }
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) return null;
    final parts = value.split('.');
    final euros = int.tryParse(parts.first);
    if (euros == null) return null;
    final fraction =
        parts.length > 1 ? int.tryParse(parts[1].padRight(2, '0')) : 0;
    if (fraction == null) return null;
    return euros * 100 + fraction;
  }

  if (received == null ||
      received.trim().isEmpty ||
      total == null ||
      changeMode == null) return '';
  final amount = cents(received);
  final due = cents(total);
  if (amount == null || due == null) return '';
  final difference = changeMode ? amount - due : due - amount;
  final safe = difference > 0 ? difference : 0;
  return '${safe ~/ 100}.${(safe % 100).toString().padLeft(2, '0')}';
}
