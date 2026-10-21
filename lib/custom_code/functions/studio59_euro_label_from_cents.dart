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

/// Formata cêntimos como valor legível em EUR.
String? studio59EuroLabelFromCents(int? cents) {
  if (cents == null || cents < 0) return null;
  final safe = cents;
  final euros = safe ~/ 100;
  final centsPart = (safe % 100).toString().padLeft(2, '0');
  return '$euros,$centsPart €';
}
