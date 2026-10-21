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

/// Assinala a divergência entre delivered e uma dívida ainda positiva.
String? studio59CashResultStatus(
  String? status,
  dynamic amountDue,
) {
  final raw = amountDue?.toString().trim() ?? '0';
  final normalized = raw.replaceAll(',', '.');
  final parts = normalized.split('.');
  final euros = int.tryParse(parts.first) ?? 0;
  final cents = parts.length > 1
      ? int.tryParse(parts[1].padRight(2, '0').substring(0, 2)) ?? 0
      : 0;
  final dueCents = euros * 100 + cents;
  if (status == 'delivered' && dueCents > 0)
    return 'Estado do servidor: delivered, mas continua em dívida.';
  if (status == 'delivered' && dueCents == 0)
    return 'Pagamento registado pelo servidor.';
  return 'Estado do servidor: $status';
}
