import 'package:flutter/material.dart'
    show ChangeNotifier, Color, Colors, VoidCallback;
import '/backend/schema/structs/index.dart';
import '/backend/api_requests/api_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {}

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  /// Token da sessão pública do evento.
  String _guestSessionToken = '';
  String get guestSessionToken => _guestSessionToken;
  set guestSessionToken(String value) {
    _guestSessionToken = value;
  }

  /// Evento autenticado pelo convidado.
  Studio59EventInfoStruct _guestEvent = Studio59EventInfoStruct();
  Studio59EventInfoStruct get guestEvent => _guestEvent;
  set guestEvent(Studio59EventInfoStruct value) {
    _guestEvent = value;
  }

  void updateGuestEventStruct(Function(Studio59EventInfoStruct) updateFn) {
    updateFn(_guestEvent);
  }

  /// Seleção local de fotografias do evento.
  List<Studio59CartPhotoStruct> _guestCart = [];
  List<Studio59CartPhotoStruct> get guestCart => _guestCart;
  set guestCart(List<Studio59CartPhotoStruct> value) {
    _guestCart = value;
  }

  void addToGuestCart(Studio59CartPhotoStruct value) {
    guestCart.add(value);
  }

  void removeFromGuestCart(Studio59CartPhotoStruct value) {
    guestCart.remove(value);
  }

  void removeAtIndexFromGuestCart(int index) {
    guestCart.removeAt(index);
  }

  void updateGuestCartAtIndex(
    int index,
    Studio59CartPhotoStruct Function(Studio59CartPhotoStruct) updateFn,
  ) {
    guestCart[index] = updateFn(_guestCart[index]);
  }

  void insertAtIndexInGuestCart(int index, Studio59CartPhotoStruct value) {
    guestCart.insert(index, value);
  }

  /// Resposta do último pedido presencial.
  Studio59OrderReceiptStruct _lastGuestOrder = Studio59OrderReceiptStruct();
  Studio59OrderReceiptStruct get lastGuestOrder => _lastGuestOrder;
  set lastGuestOrder(Studio59OrderReceiptStruct value) {
    _lastGuestOrder = value;
  }

  void updateLastGuestOrderStruct(
      Function(Studio59OrderReceiptStruct) updateFn) {
    updateFn(_lastGuestOrder);
  }

  /// Endereço da API da sessão offline ativa (vazio = online).
  String _offlineApiBase = '';
  String get offlineApiBase => _offlineApiBase;
  set offlineApiBase(String value) {
    _offlineApiBase = value;
  }
}
