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

/// Formata o montante recebido para o payload em EUR.
String? studio59FormatReceivedEur(String? received) {
  var value = received?.trim() ?? '';
  if (value.isEmpty) return '';
  if (value.contains(',') && value.contains('.')) {
    value = value.lastIndexOf(',') > value.lastIndexOf('.')
        ? value.replaceAll('.', '').replaceAll(',', '.')
        : value.replaceAll(',', '');
  } else {
    value = value.replaceAll(',', '.');
  }
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) return '';
  final parts = value.split('.');
  final euros = int.parse(parts.first);
  final cents = parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0;
  return '$euros.${cents.toString().padLeft(2, '0')}';
}
