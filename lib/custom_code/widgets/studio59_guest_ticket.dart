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
  static const _muted = Color(0xFF6D625F);

  String _table = '';
  String _name = '';
  String? _shipping;

  String get _base => FFAppState().offlineApiBase.isNotEmpty
      ? FFAppState().offlineApiBase
      : 'https://studio59.wiredevelop.pt/api';

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final table = prefs.getString('studio59_table_label') ?? '';
      final name = prefs.getString('studio59_last_name') ?? '';
      if (mounted)
        setState(() {
          _table = table;
          _name = name;
        });
    } catch (_) {}
    final code = FFAppState().lastGuestOrder.orderCode;
    if (code.isEmpty) return;
    try {
      final response = await http.get(
          Uri.parse('$_base/public/orders/${Uri.encodeComponent(code)}'),
          headers: {
            'Accept': 'application/json'
          }).timeout(const Duration(seconds: 12));
      final body = jsonDecode(response.body);
      final data =
          body is Map && body['data'] is Map ? body['data'] as Map : body;
      if (data is Map &&
          data['delivery_type'] == 'shipping' &&
          data['shipping_fee'] != null) {
        if (mounted) setState(() => _shipping = '${data['shipping_fee']}');
      }
    } catch (_) {}
  }

  String _money(dynamic value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return '';
    final number = double.tryParse(text.replaceAll(',', '.'));
    if (number == null) return text;
    return '${number.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  Future<void> _nextPerson() async {
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

  Widget _step(int number, IconData icon, String title, String text) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFECE7E3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Icon(icon, color: _rose, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              color: _ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 6),
                Text(text,
                    style: const TextStyle(
                        color: _ink, fontSize: 17, height: 1.35)),
              ])),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final order = FFAppState().lastGuestOrder;
    final code = order.orderCode;
    final total = _money(order.totalAmount);
    final tableText = _table.isEmpty ? 'da sua mesa' : 'da mesa $_table';
    return Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xFFFAF9F7),
        child: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  const SizedBox(height: 8),
                  const Center(
                      child: Icon(Icons.check_circle,
                          color: Color(0xFF4E8A5B), size: 76)),
                  const SizedBox(height: 10),
                  const Text('Pedido registado!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _ink,
                          fontSize: 30,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: _roseSoft,
                          borderRadius: BorderRadius.circular(22)),
                      child: Column(children: [
                        const Text('Pedido em nome de',
                            style: TextStyle(color: _muted, fontSize: 17)),
                        const SizedBox(height: 4),
                        Text(_name.isEmpty ? '—' : _name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: _ink,
                                fontSize: 34,
                                fontWeight: FontWeight.w800)),
                        if (code.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Pedido $code',
                                  style: const TextStyle(
                                      color: _muted, fontSize: 14))),
                        if (_table.isNotEmpty || total.isNotEmpty)
                          const SizedBox(height: 10),
                        Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 22,
                            runSpacing: 6,
                            children: [
                              if (_table.isNotEmpty)
                                Text('Mesa: $_table',
                                    style: const TextStyle(
                                        color: _ink,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700)),
                              if (total.isNotEmpty)
                                Text('Total: $total',
                                    style: const TextStyle(
                                        color: _ink,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700)),
                            ]),
                        if (_shipping != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('Inclui envio: ${_money(_shipping)}',
                                  style: const TextStyle(
                                      color: _muted, fontSize: 15))),
                      ])),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                      onPressed: _nextPerson,
                      style: FilledButton.styleFrom(
                          backgroundColor: _rose,
                          padding: const EdgeInsets.all(20),
                          textStyle: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      icon: const Icon(Icons.people_alt_outlined),
                      label: const Text('Próxima pessoa: abrir o catálogo')),
                  const SizedBox(height: 22),
                  const Text('E agora?',
                      style: TextStyle(
                          color: _ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _step(
                      1,
                      Icons.photo_camera_outlined,
                      'Dirija-se ao fotógrafo',
                      'Diga o seu nome ao fotógrafo: ele encontra o seu pedido, mostra-lhe as fotografias escolhidas e regista o pagamento. Se preferir, aguarde na sua mesa: o fotógrafo passa por lá.'),
                  _step(
                      2,
                      Icons.tablet_mac_outlined,
                      'Passe o iPad à próxima pessoa',
                      'Entregue o iPad à próxima pessoa ou casal $tableText. Por favor, não o leve para outras mesas.'),
                  const SizedBox(height: 24),
                ]))));
  }
}
