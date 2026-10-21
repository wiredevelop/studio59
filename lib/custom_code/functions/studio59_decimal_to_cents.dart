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

/// Converte EUR para cêntimos sem aritmética de vírgula flutuante.
int? studio59DecimalToCents(dynamic amount) {
  final raw = amount?.toString().trim() ?? '';
  final cleaned = raw.replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (cleaned.isEmpty) return -1;
  var normalized = cleaned;
  if (normalized.contains(',') && normalized.contains('.')) {
    if (normalized.lastIndexOf(',') > normalized.lastIndexOf('.')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else {
      normalized = normalized.replaceAll(',', '');
    }
  } else {
    normalized = normalized.replaceAll(',', '.');
  }
  final parts = normalized.split('.');
  if (parts.length > 2 || (parts.length == 2 && parts[1].length > 2)) return -1;
  final euros = int.tryParse(parts[0]);
  if (euros == null || euros < 0) return -1;
  final cents = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
  return euros * 100 + cents;
}
