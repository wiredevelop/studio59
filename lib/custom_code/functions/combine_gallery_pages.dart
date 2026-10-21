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

/// Acrescenta uma página de fotografias à galeria já carregada.
List<Studio59GalleryPhotoStruct>? combineGalleryPages(
  List<Studio59GalleryPhotoStruct>? existing,
  List<Studio59GalleryPhotoStruct>? incoming,
) {
  if (existing == null) return incoming ?? <Studio59GalleryPhotoStruct>[];
  if (incoming == null) return existing;
  return [...existing, ...incoming];
}
