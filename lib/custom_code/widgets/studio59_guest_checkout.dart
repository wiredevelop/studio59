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
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Studio59GuestCheckout extends StatefulWidget {
  const Studio59GuestCheckout({super.key, this.width, this.height});
  final double? width;
  final double? height;
  @override
  State<Studio59GuestCheckout> createState() => _Studio59GuestCheckoutState();
}

class _Studio59GuestCheckoutState extends State<Studio59GuestCheckout> {
  static const _rose = Color(0xFFB77F84);
  static const _roseSoft = Color(0xFFF2E5E3);
  static const _ink = Color(0xFF292624);
  static const _muted = Color(0xFF6D625F);
  static const _line = Color(0xFFECE7E3);
  static const _filmCents = 3000;
  static const _shippingCents = 500;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _table = TextEditingController();
  // Mesa: só letras (com acentos) e espaços, ou só números inteiros (1, 2, 3…).
  static final _tableRule = RegExp(r'^(?:[\p{L}\p{M} ]+|\d+)$', unicode: true);
  String _productType = 'paper';
  String _deliveryType = 'pickup';
  bool _wantsFilm = false;
  bool _submitting = false;
  bool _uncertain = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _table.dispose();
    super.dispose();
  }

  int get _unitCents => (FFAppState().guestEvent.pricePerPhoto * 100).round();
  int get _photoCount =>
      FFAppState().guestCart.fold(0, (sum, item) => sum + item.quantity);
  int get _photosCents => _unitCents * _photoCount;
  bool get _needsDelivery => _productType != 'digital';
  int get _deliveryCents =>
      _needsDelivery && _deliveryType == 'shipping' ? _shippingCents : 0;
  int get _totalCents =>
      _photosCents + (_wantsFilm ? _filmCents : 0) + _deliveryCents;
  String _money(int cents) =>
      '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')} €';

  Future<void> _submit() async {
    if (_submitting || _uncertain) return;
    String? problem;
    final table = _table.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (table.isEmpty)
      problem = 'Indique qual é a sua mesa.';
    else if (!_tableRule.hasMatch(table))
      problem = 'Na mesa use só letras (ex.: Noivos) ou só números (ex.: 12).';
    else if (_name.text.trim().isEmpty)
      problem = 'Introduza o nome.';
    else if (_phone.text.trim().isEmpty)
      problem = 'Introduza o telefone.';
    else if (!_email.text.trim().contains('@'))
      problem = 'Introduza um email válido.';
    else if (_needsDelivery &&
        _deliveryType == 'shipping' &&
        _address.text.trim().isEmpty) problem = 'Indique a morada de envio.';
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Lida pela ação que envia o pedido e pela página do ticket.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('studio59_table_label', table);
    } catch (_) {}
    final items = FFAppState()
        .guestCart
        .map((item) => {'photo_id': item.photoId, 'quantity': item.quantity})
        .toList();
    final result = await postStudio59GuestCashOrderNullableSafe(
      FFAppState().guestEvent.id,
      FFAppState().guestSessionToken,
      _name.text,
      _phone.text,
      _email.text,
      _productType,
      items,
      _wantsFilm,
      _needsDelivery ? _deliveryType : '',
      _needsDelivery && _deliveryType == 'shipping' ? _address.text : '',
    );
    if (!mounted) return;
    if (result.success) {
      FFAppState().update(() => FFAppState().lastGuestOrder = result.order);
      context.goNamed('GuestTicketOnline');
      return;
    }
    setState(() {
      _submitting = false;
      _uncertain = result.uncertain;
      _error = result.message;
    });
  }

  Widget _section(String title, Widget child, {String? subtitle}) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title,
              style: const TextStyle(
                  color: _ink, fontSize: 17, fontWeight: FontWeight.w700)),
          if (subtitle != null)
            Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(subtitle,
                    style: const TextStyle(color: _muted, fontSize: 13))),
          const SizedBox(height: 14),
          child,
        ]),
      );

  Widget _field(TextEditingController controller, String label, IconData icon,
          {TextInputType? keyboard,
          int maxLines = 1,
          String? hint,
          List<TextInputFormatter>? formatters}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: maxLines,
          inputFormatters: formatters,
          textCapitalization: formatters != null
              ? TextCapitalization.words
              : TextCapitalization.none,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: _muted, size: 20),
            filled: true,
            fillColor: const Color(0xFFFAF9F7),
            labelStyle: const TextStyle(color: _muted),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _rose, width: 1.6)),
          ),
        ),
      );

  Widget _option(
          {required bool active,
          required IconData icon,
          required String title,
          String? detail,
          required VoidCallback onTap}) =>
      Material(
        color: active ? _roseSoft : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _submitting ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: active ? _rose : _line, width: active ? 2 : 1)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: active ? _rose : _muted, size: 26),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _ink,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
              if (detail != null)
                Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(detail,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: active ? _rose : _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
      );

  Widget _options(List<Widget> children) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: children[i])
        ],
      ]);

  Widget _summaryRow(String label, String value, {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: strong ? _ink : _muted,
                      fontSize: strong ? 17 : 14,
                      fontWeight: strong ? FontWeight.w700 : FontWeight.w500))),
          Text(value,
              style: TextStyle(
                  color: _ink,
                  fontSize: strong ? 22 : 14,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final cart = FFAppState().guestCart;
    if (cart.isEmpty)
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(CupertinoIcons.cart,
                    size: 52, color: Color(0xFFB9AEAA)),
                const SizedBox(height: 16),
                const Text('O carrinho está vazio.',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                FilledButton(
                    onPressed: () => context.goNamed('GuestGalleryOnline'),
                    style: FilledButton.styleFrom(backgroundColor: _rose),
                    child: const Text('Ver galeria')),
              ])));
    return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text(FFAppState().guestEvent.name,
                style: const TextStyle(
                    color: _ink, fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text('${cart.length} fotografias · $_photoCount unidades',
                style: const TextStyle(color: _muted)),
            const SizedBox(height: 16),
            _section(
                'Os seus dados',
                Column(children: [
                  _field(_table, 'Qual é a sua mesa?',
                      Icons.table_restaurant_outlined,
                      hint: 'Ex.: 12 ou Noivos',
                      maxLines: 1,
                      formatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[\p{L}\p{M} 0-9]', unicode: true)),
                        LengthLimitingTextInputFormatter(40)
                      ]),
                  _field(_name, 'Nome', Icons.person_outline),
                  _field(_phone, 'Telefone', Icons.phone_outlined,
                      keyboard: TextInputType.phone),
                  _field(_email, 'Email', Icons.mail_outline,
                      keyboard: TextInputType.emailAddress),
                ]),
                subtitle: 'O email é obrigatório para registar o pedido.'),
            _section(
                'Formato',
                _options([
                  _option(
                      active: _productType == 'paper',
                      icon: Icons.photo_outlined,
                      title: 'Papel',
                      onTap: () => setState(() => _productType = 'paper')),
                  _option(
                      active: _productType == 'digital',
                      icon: Icons.cloud_download_outlined,
                      title: 'Digital',
                      onTap: () => setState(() => _productType = 'digital')),
                  _option(
                      active: _productType == 'both',
                      icon: Icons.collections_outlined,
                      title: 'Ambos',
                      onTap: () => setState(() => _productType = 'both')),
                ])),
            if (_needsDelivery)
              _section(
                  'Entrega',
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _options([
                          _option(
                              active: _deliveryType == 'pickup',
                              icon: Icons.storefront_outlined,
                              title: 'Levantamento',
                              detail: 'Grátis',
                              onTap: () =>
                                  setState(() => _deliveryType = 'pickup')),
                          _option(
                              active: _deliveryType == 'shipping',
                              icon: Icons.local_shipping_outlined,
                              title: 'Envio',
                              detail: '+ ${_money(_shippingCents)}',
                              onTap: () =>
                                  setState(() => _deliveryType = 'shipping')),
                        ]),
                        if (_deliveryType == 'shipping') ...[
                          const SizedBox(height: 12),
                          _field(
                              _address, 'Morada de envio', Icons.home_outlined,
                              maxLines: 2)
                        ],
                      ])),
            _section(
                'Extras',
                _option(
                  active: _wantsFilm,
                  icon: Icons.movie_outlined,
                  title: 'Filme do evento',
                  detail: _wantsFilm
                      ? 'Adicionado · + ${_money(_filmCents)}'
                      : '+ ${_money(_filmCents)}',
                  onTap: () => setState(() => _wantsFilm = !_wantsFilm),
                ),
                subtitle: 'Toque para adicionar ou remover.'),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: _roseSoft, borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                _summaryRow(
                    'Fotografias ($_photoCount × ${_money(_unitCents)})',
                    _money(_photosCents)),
                if (_wantsFilm)
                  _summaryRow('Filme do evento', _money(_filmCents)),
                if (_needsDelivery)
                  _summaryRow(
                      _deliveryType == 'shipping' ? 'Envio' : 'Levantamento',
                      _deliveryCents == 0 ? 'Grátis' : _money(_deliveryCents)),
                const Divider(height: 18, color: Color(0xFFE3D2CF)),
                _summaryRow('Total', _money(_totalCents), strong: true),
              ]),
            ),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFBEAEA),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(
                        _uncertain
                            ? 'O resultado do pedido é incerto. Contacte a equipa antes de tentar novamente.'
                            : _error!,
                        style: const TextStyle(color: Color(0xFF9B3D3D))),
                  )),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting || _uncertain ? null : _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: _rose,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Registar pedido · ${_money(_totalCents)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _submitting ? null : () => context.safePop(),
              style: OutlinedButton.styleFrom(
                  foregroundColor: _rose,
                  side: const BorderSide(color: _rose),
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: const Text('Voltar ao carrinho'),
            ),
            const SizedBox(height: 24),
          ]),
        )));
  }
}
