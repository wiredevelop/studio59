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

/// Combina os quatro dígitos introduzidos no ecrã público.
String? joinPinDigits(
  String? digit1,
  String? digit2,
  String? digit3,
  String? digit4,
) {
  bool isPinDigit(String? value) =>
      value != null && RegExp(r'^\d$').hasMatch(value);
  final digits = [digit1, digit2, digit3, digit4];
  if (!digits.every(isPinDigit)) return '';
  return digits.join();
}
