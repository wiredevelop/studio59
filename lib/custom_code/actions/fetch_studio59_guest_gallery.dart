// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/ff_builtin_enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart' hide RepeatMode;
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Studio59GalleryFetchResultStruct> fetchStudio59GuestGallery(
  int eventId,
  String token,
  int page,
) async {
  if (eventId <= 0 || token.trim().isEmpty || page < 1) {
    return Studio59GalleryFetchResultStruct(
      success: false,
      statusCode: 0,
      message: 'SessÃ£o do evento invÃ¡lida.',
    );
  }
  try {
    final uri = Uri.https(
      'studio59.wiredevelop.pt',
      '/api/public/events/$eventId/photos',
      {'page': '$page', 'per_page': '50'},
    );
    final response = await http.get(uri, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
    }).timeout(const Duration(seconds: 20));
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {}
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map) {
      final message = decoded is Map && decoded['message'] is String
          ? decoded['message'] as String
          : 'NÃ£o foi possÃ­vel carregar a galeria (${response.statusCode}).';
      return Studio59GalleryFetchResultStruct(
        success: false,
        statusCode: response.statusCode,
        message: message,
      );
    }
    final rawPhotos = decoded['data'];
    final photos = rawPhotos is List
        ? rawPhotos
            .whereType<Map>()
            .map((photo) => Studio59GalleryPhotoStruct.maybeFromMap(photo))
            .whereType<Studio59GalleryPhotoStruct>()
            .toList()
        : <Studio59GalleryPhotoStruct>[];
    return Studio59GalleryFetchResultStruct(
      success: true,
      statusCode: response.statusCode,
      message: '',
      currentPage: int.tryParse('${decoded['current_page']}') ?? page,
      lastPage: int.tryParse('${decoded['last_page']}') ?? page,
      total: int.tryParse('${decoded['total']}') ?? photos.length,
      data: photos,
    );
  } catch (_) {
    return Studio59GalleryFetchResultStruct(
      success: false,
      statusCode: 0,
      message:
          'NÃ£o foi possÃ­vel contactar o servidor. Verifique a ligaÃ§Ã£o e tente novamente.',
    );
  }
}
