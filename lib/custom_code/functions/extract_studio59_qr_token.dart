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

/// Extrai o token QR de um URL ou aceita um token em bruto.
String? extractStudio59QrToken(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  final scanned = value.trim();
  final uri = Uri.tryParse(scanned);
  if (uri != null) {
    final segments = uri.pathSegments;
    final qrIndex = segments.lastIndexOf('qr');
    if (qrIndex >= 0 && qrIndex + 1 < segments.length) {
      return segments[qrIndex + 1];
    }
  }
  return scanned;
}
