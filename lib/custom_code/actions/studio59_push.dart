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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Notificações push da equipa (Firebase studio59-1c255).
/// command: 'register' (depois do login) ou 'unregister' (antes do logout).
/// Só Android e iOS; noutros sistemas não faz nada. Devolve uma descrição do resultado.
Future<String> studio59Push(String command) async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return 'unsupported';
  try {
    await _s59PushInit();
    final messaging = FirebaseMessaging.instance;
    if (command == 'unregister') {
      final token = await messaging.getToken();
      if (token != null) await _s59PushSend('DELETE', token);
      return 'unregistered';
    }
    final settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied)
      return 'denied';
    if (Platform.isIOS) {
      await messaging.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true);
      // No iOS o token FCM só existe depois de o APNs responder.
      for (var i = 0; i < 10 && await messaging.getAPNSToken() == null; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    final token = await messaging.getToken();
    if (token == null || token.isEmpty) return 'no-token';
    final ok = await _s59PushSend('POST', token);
    _s59PushRefresh ??=
        messaging.onTokenRefresh.listen((t) => _s59PushSend('POST', t));
    return ok ? 'registered' : 'server-error';
  } catch (error) {
    return 'error: $error';
  }
}

StreamSubscription<String>? _s59PushRefresh;

Future<void> _s59PushInit() async {
  if (Firebase.apps.isNotEmpty) return;
  // Configuração do cliente (a mesma das versões anteriores da app); dispensa google-services.json/plist.
  await Firebase.initializeApp(
    options: Platform.isIOS
        ? const FirebaseOptions(
            apiKey: 'AIzaSyDyUDC-aVU-uXZKbF-Ed0FjMz3mzH1MpCo',
            appId: '1:1008888117512:ios:ca76b142099281703fd4bd',
            messagingSenderId: '1008888117512',
            projectId: 'studio59-1c255',
            iosBundleId: 'pt.studio59.app',
          )
        : const FirebaseOptions(
            apiKey: 'AIzaSyDbugocofs97izc8p5PVkN0ibYZ2K28Psw',
            appId: '1:1008888117512:android:0815269d4a402b5d3fd4bd',
            messagingSenderId: '1008888117512',
            projectId: 'studio59-1c255',
          ),
  );
}

Future<bool> _s59PushSend(String method, String token) async {
  final staffToken =
      (await const FlutterSecureStorage().read(key: 'studio59_staff_token') ??
              '')
          .trim();
  if (staffToken.isEmpty) return false;
  final request = http.Request(
      method, Uri.parse('https://studio59.wiredevelop.pt/api/device-tokens'))
    ..headers.addAll({
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $staffToken',
    })
    ..body = jsonEncode({
      'token': token,
      if (method == 'POST') 'platform': Platform.isIOS ? 'ios' : 'android'
    });
  try {
    final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 15)));
    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (_) {
    return false;
  }
}
