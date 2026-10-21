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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Studio59GuestCart extends StatefulWidget {
  const Studio59GuestCart({super.key, this.width, this.height});
  final double? width;
  final double? height;
  @override
  State<Studio59GuestCart> createState() => _Studio59GuestCartState();
}

class _Studio59GuestCartState extends State<Studio59GuestCart> {
  static const _rose = Color(0xFFB77F84);
  int get _unitCents => (FFAppState().guestEvent.pricePerPhoto * 100).round();
  String _money(int cents) =>
      '${cents ~/ 100},${(cents % 100).abs().toString().padLeft(2, '0')} €';
  int get _total => FFAppState()
      .guestCart
      .fold(0, (sum, item) => sum + _unitCents * item.quantity);

  void _quantity(int index, int delta) {
    final current = FFAppState().guestCart[index];
    final next = (current.quantity + delta).clamp(1, 50);
    FFAppState().update(() => FFAppState().updateGuestCartAtIndex(
        index,
        (_) => Studio59CartPhotoStruct(
              photoId: current.photoId,
              filename: current.filename,
              previewUrl: current.previewUrl,
              quantity: next,
            )));
    setState(() {});
    studio59Offline(
        'log',
        jsonEncode({
          'action': 'cart.quantity',
          'message': '${current.filename}: quantidade $next'
        }));
  }

  void _remove(int index) {
    final removed = FFAppState().guestCart[index].filename;
    FFAppState().update(() => FFAppState().removeAtIndexFromGuestCart(index));
    setState(() {});
    studio59Offline(
        'log',
        jsonEncode({
          'action': 'cart.remove',
          'message': 'Removeu $removed do carrinho'
        }));
  }

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
                const SizedBox(height: 8),
                const Text(
                    'Volte à galeria e escolha as fotografias que pretende.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton(
                    onPressed: () => context.pushNamed('GuestGalleryOnline'),
                    style: FilledButton.styleFrom(backgroundColor: _rose),
                    child: const Text('Ver galeria')),
              ])));
    return SizedBox(
        width: widget.width,
        height: widget.height,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(FFAppState().guestEvent.name,
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text('${cart.length} fotografias selecionadas',
              style: const TextStyle(color: Color(0xFF6D625F))),
          const SizedBox(height: 16),
          for (var index = 0; index < cart.length; index++)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFECE7E3))),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final item = cart[index];
                    return Row(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: CachedNetworkImage(
                              imageUrl: item.previewUrl,
                              width: 82,
                              height: 82,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const SizedBox(
                                  width: 82,
                                  height: 82,
                                  child: Icon(Icons.broken_image_outlined)))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(item.filename,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 5),
                            Text('${_money(_unitCents)} cada',
                                style:
                                    const TextStyle(color: Color(0xFF6D625F))),
                            const SizedBox(height: 8),
                            Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  IconButton(
                                      onPressed: () => item.quantity == 1
                                          ? _remove(index)
                                          : _quantity(index, -1),
                                      icon: const Icon(
                                          Icons.remove_circle_outline),
                                      tooltip: 'Diminuir'),
                                  SizedBox(
                                      width: 38,
                                      child: Center(
                                          child: Text('${item.quantity}',
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      FontWeight.w700)))),
                                  IconButton(
                                      onPressed: item.quantity >= 50
                                          ? null
                                          : () => _quantity(index, 1),
                                      icon:
                                          const Icon(Icons.add_circle_outline),
                                      tooltip: 'Aumentar'),
                                ]),
                          ])),
                      const SizedBox(width: 8),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_money(_unitCents * item.quantity),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            IconButton(
                                onPressed: () => _remove(index),
                                tooltip: 'Remover',
                                icon: const Icon(Icons.delete_outline,
                                    color: Color(0xFF9B3D3D))),
                          ]),
                    ]);
                  }),
                )),
          Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: const Color(0xFFF2E5E3),
                  borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                const Expanded(
                    child: Text('Total das fotografias',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600))),
                Text(_money(_total),
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800)),
              ])),
          const SizedBox(height: 18),
          OutlinedButton(
              onPressed: () => context.pushNamed('GuestGalleryOnline'),
              child: const Text('Adicionar mais fotografias')),
          const SizedBox(height: 10),
          FilledButton(
              onPressed: () => context.pushNamed('GuestCheckoutOnline'),
              style: FilledButton.styleFrom(
                  backgroundColor: _rose, padding: const EdgeInsets.all(16)),
              child: const Text('Continuar para checkout')),
        ]));
  }
}
