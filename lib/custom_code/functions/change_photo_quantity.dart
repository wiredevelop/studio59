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

/// Mantém a quantidade de fotografias entre 1 e 50.
int? changePhotoQuantity(
  int? quantity,
  int? delta,
) {
  if (quantity == null || delta == null) return null;
  final value = quantity + delta;
  return value < 1 ? 1 : (value > 50 ? 50 : value);
}
