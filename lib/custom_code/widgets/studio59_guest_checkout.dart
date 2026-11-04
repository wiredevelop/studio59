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
  static final _rose = Color(0xFFB77F84);
  static final _roseSoft = Color(0xFFF2E5E3);
  static final _ink = Color(0xFF292624);
  static final _muted = Color(0xFF6D625F);
  static final _line = Color(0xFFECE7E3);
  static final _filmCents = 3000;
  static final _shippingCents = 500;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _table = TextEditingController();
  // Mesa: só letras (com acentos) e espaços, ou só números inteiros (1, 2, 3…).
  static final _tableRule = RegExp(r'^(?:[\p{L}\p{M} ]+|\d+)$', unicode: true);
  // Todas as encomendas são em papel e digital; o formato deixou de ser uma escolha.
  static final _productType = 'both';
  String _deliveryType = 'couple'; // «Noivos entregam» por defeito
  bool _wantsFilm = false;
  bool _submitting = false;
  bool _uncertain = false;
  String? _error;

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
  bool get _offline => FFAppState().offlineApiBase.isNotEmpty;
  bool get _needsEmail => _deliveryType == 'shipping';
  // Online as fotografias digitais são entregues por QR; o email só serve para o envio por correio.
  bool get _showsEmail => _offline || _needsEmail;
  int get _deliveryCents => _deliveryType == 'shipping' ? _shippingCents : 0;
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
    else if (_needsEmail && _email.text.trim().isEmpty)
      problem = 'Para o envio por correio indique o email.';
    else if (_showsEmail &&
        _email.text.trim().isNotEmpty &&
        !_email.text.trim().contains('@'))
      problem = 'Introduza um email válido.';
    else if (_deliveryType == 'shipping' && _address.text.trim().isEmpty)
      problem = 'Indique a morada de envio.';
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    // Sessão offline: o link das fotografias digitais só pode seguir por email, por isso pedimo-lo ao terminar.
    if (_offline && _email.text.trim().isEmpty && !await _askEmail()) return;
    if (!mounted) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Lida pela ação que envia o pedido e pela página do ticket.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('studio59_table_label', table);
      await prefs.setString('studio59_last_name', _name.text.trim());
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
      _showsEmail ? _email.text : '',
      _productType,
      items,
      _wantsFilm,
      _deliveryType,
      _deliveryType == 'shipping' ? _address.text : '',
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
        margin: EdgeInsets.only(bottom: 14),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s59tr(title),
              style: TextStyle(
                  color: _ink, fontSize: 17, fontWeight: FontWeight.w700)),
          if (subtitle != null)
            Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text(s59tr(subtitle),
                    style: TextStyle(color: _muted, fontSize: 13))),
          SizedBox(height: 14),
          child,
        ]),
      );

  Widget _field(TextEditingController controller, String label, IconData icon,
          {TextInputType? keyboard,
          int maxLines = 1,
          String? hint,
          List<TextInputFormatter>? formatters}) =>
      Padding(
        padding: EdgeInsets.only(bottom: 10),
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
            labelText: s59tr(label),
            hintText: hint == null ? null : s59tr(hint),
            prefixIcon: Icon(icon, color: _muted, size: 20),
            filled: true,
            fillColor: Color(0xFFFAF9F7),
            labelStyle: TextStyle(color: _muted),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _rose, width: 1.6)),
          ),
        ),
      );

  /// Devolve false se o convidado quiser voltar ao formulário.
  Future<bool> _askEmail() async {
    final input = TextEditingController();
    String? problem;
    final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, update) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: Text(s59tr('Receber as fotografias digitais')),
                  content: SizedBox(
                      width: 440,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                                s59tr(
                                    'Para receber as fotografias digitais, insira o seu email. Enviamos-lhe o link depois do pagamento.'),
                                style: const TextStyle(
                                    fontSize: 17, height: 1.35)),
                            const SizedBox(height: 12),
                            TextField(
                                controller: input,
                                autofocus: true,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                    labelText: s59tr('Email'),
                                    errorText: problem == null
                                        ? null
                                        : s59tr(problem!),
                                    border: const OutlineInputBorder())),
                          ])),
                  actionsOverflowButtonSpacing: 4,
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(s59tr('Voltar'),
                            style: TextStyle(color: _muted))),
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, ''),
                        child: Text(s59tr('Continuar sem email'),
                            style: TextStyle(color: _muted))),
                    FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: _rose),
                        onPressed: () {
                          final value = input.text.trim();
                          if (!value.contains('@')) {
                            update(
                                () => problem = 'Introduza um email válido.');
                            return;
                          }
                          Navigator.pop(dialogContext, value);
                        },
                        child: Text(s59tr('Confirmar email'))),
                  ],
                )));
    if (result == null) return false;
    if (result.isNotEmpty) _email.text = result;
    return true;
  }

  Future<void> _optionInfo(String title, String text) => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(s59tr(title)),
            content:
                Text(s59tr(text), style: TextStyle(fontSize: 17, height: 1.35)),
            actions: [
              FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _rose),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(s59tr('Percebi')))
            ],
          ));

  Widget _option(
          {required bool active,
          required IconData icon,
          required String title,
          String? detail,
          required VoidCallback onTap,
          String? info}) =>
      Stack(children: [
        Material(
          color: active ? _roseSoft : Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: _submitting ? null : onTap,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: active ? _rose : _line, width: active ? 2 : 1)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: active ? _rose : _muted, size: 26),
                SizedBox(height: 8),
                Text(s59tr(title),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _ink,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500)),
                if (detail != null)
                  Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Text(s59tr(detail),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: active ? _rose : _muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600))),
              ]),
            ),
          ),
        ),
        if (info != null)
          Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: s59tr('Ajuda'),
                  onPressed: () => _optionInfo(title, info),
                  icon: Icon(Icons.info_outline, size: 20, color: _rose))),
      ]);

  Widget _options(List<Widget> children) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: 10),
          Expanded(child: children[i])
        ],
      ]);

  Widget _summaryRow(String label, String value, {bool strong = false}) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
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
              padding: EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(CupertinoIcons.cart, size: 52, color: Color(0xFFB9AEAA)),
                SizedBox(height: 16),
                Text(s59tr('O carrinho está vazio.'),
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                SizedBox(height: 18),
                FilledButton(
                    onPressed: () => context.goNamed('GuestGalleryOnline'),
                    style: FilledButton.styleFrom(backgroundColor: _rose),
                    child: Text(s59tr('Ver galeria'))),
              ])));
    return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
            child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 760),
          child: ListView(padding: EdgeInsets.all(16), children: [
            Align(
                alignment: Alignment.centerRight,
                child: Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Studio59Language())),
            Text(FFAppState().guestEvent.name,
                style: TextStyle(
                    color: _ink, fontSize: 19, fontWeight: FontWeight.w700)),
            SizedBox(height: 5),
            Text(
                s59tr('{a} fotografias · {b} unidades',
                    {'a': cart.length, 'b': _photoCount}),
                style: TextStyle(color: _muted)),
            SizedBox(height: 16),
            _section(
                'Os seus dados',
                Column(children: [
                  _field(_table, 'Qual é a sua mesa? *',
                      Icons.table_restaurant_outlined,
                      hint: 'Ex.: 12 ou Noivos',
                      maxLines: 1,
                      formatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[\p{L}\p{M} 0-9]', unicode: true)),
                        LengthLimitingTextInputFormatter(40)
                      ]),
                  _field(_name, 'Nome *', Icons.person_outline),
                  _field(_phone, 'Telefone (opcional)', Icons.phone_outlined,
                      keyboard: TextInputType.phone),
                  if (_showsEmail)
                    _field(_email, _needsEmail ? 'Email *' : 'Email (opcional)',
                        Icons.mail_outline,
                        keyboard: TextInputType.emailAddress),
                  if (_showsEmail)
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            s59tr(_needsEmail
                                ? 'O email é obrigatório porque escolheu o envio para a morada.'
                                : 'Se indicar o email, enviamos para lá o link das fotografias digitais.'),
                            style: TextStyle(color: _muted, fontSize: 12))),
                ]),
                subtitle: 'Todos os campos com * são obrigatórios.'),
            _section(
                'Entrega',
                Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _options([
                        _option(
                            active: _deliveryType == 'couple',
                            icon: Icons.favorite_border,
                            title: 'Noivos entregam',
                            detail: 'Grátis',
                            onTap: () =>
                                setState(() => _deliveryType = 'couple'),
                            info:
                                'Os noivos recebem as suas fotografias impressas e entregam-lhas depois. Não tem custos.'),
                        _option(
                            active: _deliveryType == 'pickup',
                            icon: Icons.storefront_outlined,
                            title: 'Levantamento',
                            detail: 'Grátis',
                            onTap: () =>
                                setState(() => _deliveryType = 'pickup'),
                            info:
                                'Levanta as fotografias impressas na loja Studio 59, quando estiverem prontas. Não tem custos.'),
                        _option(
                            active: _deliveryType == 'shipping',
                            icon: Icons.local_shipping_outlined,
                            title: 'Envio',
                            detail: '+ ${_money(_shippingCents)}',
                            onTap: () =>
                                setState(() => _deliveryType = 'shipping'),
                            info:
                                'Enviamos as fotografias impressas por correio para a sua morada. Tem de indicar a morada e o email.'),
                      ]),
                      if (_deliveryType == 'shipping') ...[
                        SizedBox(height: 12),
                        _field(
                            _address, 'Morada de envio *', Icons.home_outlined,
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
                      ? s59tr(
                          'Adicionado · {m}', {'m': '+ ${_money(_filmCents)}'})
                      : '+ ${_money(_filmCents)}',
                  onTap: () => setState(() => _wantsFilm = !_wantsFilm),
                ),
                subtitle: 'Toque para adicionar ou remover.'),
            Container(
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: _roseSoft, borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                _summaryRow(
                    s59tr('Fotografias ({a} × {b})',
                        {'a': _photoCount, 'b': _money(_unitCents)}),
                    _money(_photosCents)),
                if (_wantsFilm)
                  _summaryRow(s59tr('Filme do evento'), _money(_filmCents)),
                _summaryRow(
                    s59tr(_deliveryType == 'shipping'
                        ? 'Envio'
                        : _deliveryType == 'couple'
                            ? 'Noivos entregam'
                            : 'Levantamento'),
                    _deliveryCents == 0
                        ? s59tr('Grátis')
                        : _money(_deliveryCents)),
                Divider(height: 18, color: Color(0xFFE3D2CF)),
                _summaryRow(s59tr('Total'), _money(_totalCents), strong: true),
              ]),
            ),
            if (_error != null)
              Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Color(0xFFFBEAEA),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(
                        s59tr(_uncertain
                            ? 'O resultado do pedido é incerto. Contacte a equipa antes de tentar novamente.'
                            : _error!),
                        style: TextStyle(color: Color(0xFF9B3D3D))),
                  )),
            SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting || _uncertain ? null : _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: _rose,
                  padding: EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: _submitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      s59tr(
                          'Registar pedido · {m}', {'m': _money(_totalCents)}),
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            SizedBox(height: 10),
            OutlinedButton(
              onPressed: _submitting ? null : () => context.safePop(),
              style: OutlinedButton.styleFrom(
                  foregroundColor: _rose,
                  side: BorderSide(color: _rose),
                  padding: EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: Text(s59tr('Voltar ao carrinho')),
            ),
            SizedBox(height: 24),
          ]),
        )));
  }
}
