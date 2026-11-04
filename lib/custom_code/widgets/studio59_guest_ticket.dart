// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/ff_builtin_enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart' hide RepeatMode;
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/app_state.dart';
import '/custom_code/widgets/studio59_language.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Página depois do checkout: código do pedido, mesa e o que fazer a seguir
/// (ir ao fotógrafo, passar o iPad à próxima pessoa da mesa). Online e offline.
class Studio59GuestTicket extends StatefulWidget {
  const Studio59GuestTicket({super.key, this.width, this.height});
  final double? width;
  final double? height;
  @override
  State<Studio59GuestTicket> createState() => _Studio59GuestTicketState();
}

class _Studio59GuestTicketState extends State<Studio59GuestTicket> {
  static const _rose = Color(0xFFB77F84);
  static const _roseSoft = Color(0xFFF6ECEC);
  static const _ink = Color(0xFF292624);

  void _onLanguage() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    s59Language.addListener(_onLanguage);
  }

  @override
  void dispose() {
    s59Language.removeListener(_onLanguage);
    super.dispose();
  }

  Future<void> _backToCatalogue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('studio59_table_label');
      await prefs.remove('studio59_last_name');
    } catch (_) {}
    FFAppState().update(() {
      FFAppState().guestCart = [];
      FFAppState().lastGuestOrder = Studio59OrderReceiptStruct();
    });
    if (mounted) context.goNamed('GuestGalleryOnline');
  }

  Widget _step(int number, IconData icon, String title) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFECE7E3))),
        child: Row(children: [
          Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration:
                  const BoxDecoration(color: _roseSoft, shape: BoxShape.circle),
              child: Text('$number',
                  style: const TextStyle(
                      color: _rose,
                      fontSize: 22,
                      fontWeight: FontWeight.w800))),
          const SizedBox(width: 16),
          Icon(icon, color: _rose, size: 24),
          const SizedBox(width: 8),
          Expanded(
              child: Text(s59tr(title),
                  style: const TextStyle(
                      color: _ink, fontSize: 20, fontWeight: FontWeight.w700))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xFFFAF9F7),
        child: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: Studio59Language())),
                      Text(s59tr('E agora?'),
                          style: const TextStyle(
                              color: _ink,
                              fontSize: 26,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 14),
                      _step(1, Icons.photo_camera_outlined,
                          'Dirija-se ao fotógrafo'),
                      _step(2, Icons.tablet_mac_outlined,
                          'Passe o iPad à próxima pessoa'),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                          onPressed: _backToCatalogue,
                          style: FilledButton.styleFrom(
                              backgroundColor: _rose,
                              padding: const EdgeInsets.all(22),
                              textStyle: const TextStyle(
                                  fontSize: 21, fontWeight: FontWeight.w800),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16))),
                          icon: const Icon(Icons.photo_library_outlined,
                              size: 26),
                          label: Text(s59tr('Voltar ao catálogo'))),
                    ]))));
  }
}
