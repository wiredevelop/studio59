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

/// Evita linhas duplicadas para a mesma fotografia no carrinho.
bool? isPhotoInCart(
  List<Studio59CartPhotoStruct>? items,
  int? photoId,
) {
  if (items == null || photoId == null) return false;
  return items.any((item) => item.photoId == photoId);
}
