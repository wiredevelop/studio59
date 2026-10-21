// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59PublicOrderDetails
class Studio59PublicOrderDetailsStruct extends BaseStruct {
  Studio59PublicOrderDetailsStruct({
    /// Studio59PublicOrderDetails.order_code
    String? orderCode,

    /// Studio59PublicOrderDetails.status
    String? status,

    /// Studio59PublicOrderDetails.total_amount
    dynamic totalAmount,

    /// Studio59PublicOrderDetails.shipping_fee
    dynamic shippingFee,

    /// Studio59PublicOrderDetails.delivery_type
    String? deliveryType,

    /// Studio59PublicOrderDetails.delivery_address
    String? deliveryAddress,
  })  : _orderCode = orderCode,
        _status = status,
        _totalAmount = totalAmount,
        _shippingFee = shippingFee,
        _deliveryType = deliveryType,
        _deliveryAddress = deliveryAddress;

  // "order_code" field.
  String? _orderCode;
  String get orderCode => _orderCode ?? '';
  set orderCode(String? val) => _orderCode = val;

  bool hasOrderCode() => _orderCode != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  set status(String? val) => _status = val;

  bool hasStatus() => _status != null;

  // "total_amount" field.
  dynamic? _totalAmount;
  dynamic? get totalAmount => _totalAmount;
  set totalAmount(dynamic? val) => _totalAmount = val;

  bool hasTotalAmount() => _totalAmount != null;

  // "shipping_fee" field.
  dynamic? _shippingFee;
  dynamic? get shippingFee => _shippingFee;
  set shippingFee(dynamic? val) => _shippingFee = val;

  bool hasShippingFee() => _shippingFee != null;

  // "delivery_type" field.
  String? _deliveryType;
  String get deliveryType => _deliveryType ?? '';
  set deliveryType(String? val) => _deliveryType = val;

  bool hasDeliveryType() => _deliveryType != null;

  // "delivery_address" field.
  String? _deliveryAddress;
  String get deliveryAddress => _deliveryAddress ?? '';
  set deliveryAddress(String? val) => _deliveryAddress = val;

  bool hasDeliveryAddress() => _deliveryAddress != null;

  static Studio59PublicOrderDetailsStruct fromMap(Map<String, dynamic> data) =>
      Studio59PublicOrderDetailsStruct(
        orderCode: data['order_code'] as String?,
        status: data['status'] as String?,
        totalAmount: data['total_amount'] as dynamic?,
        shippingFee: data['shipping_fee'] as dynamic?,
        deliveryType: data['delivery_type'] as String?,
        deliveryAddress: data['delivery_address'] as String?,
      );

  static Studio59PublicOrderDetailsStruct? maybeFromMap(dynamic data) => data
          is Map
      ? Studio59PublicOrderDetailsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'order_code': _orderCode,
        'status': _status,
        'total_amount': _totalAmount,
        'shipping_fee': _shippingFee,
        'delivery_type': _deliveryType,
        'delivery_address': _deliveryAddress,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'order_code': serializeParam(
          _orderCode,
          ParamType.String,
        ),
        'status': serializeParam(
          _status,
          ParamType.String,
        ),
        'total_amount': serializeParam(
          _totalAmount,
          ParamType.JSON,
        ),
        'shipping_fee': serializeParam(
          _shippingFee,
          ParamType.JSON,
        ),
        'delivery_type': serializeParam(
          _deliveryType,
          ParamType.String,
        ),
        'delivery_address': serializeParam(
          _deliveryAddress,
          ParamType.String,
        ),
      }.withoutNulls;

  static Studio59PublicOrderDetailsStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59PublicOrderDetailsStruct(
        orderCode: deserializeParam(
          data['order_code'],
          ParamType.String,
          false,
        ),
        status: deserializeParam(
          data['status'],
          ParamType.String,
          false,
        ),
        totalAmount: deserializeParam(
          data['total_amount'],
          ParamType.JSON,
          false,
        ),
        shippingFee: deserializeParam(
          data['shipping_fee'],
          ParamType.JSON,
          false,
        ),
        deliveryType: deserializeParam(
          data['delivery_type'],
          ParamType.String,
          false,
        ),
        deliveryAddress: deserializeParam(
          data['delivery_address'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'Studio59PublicOrderDetailsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59PublicOrderDetailsStruct &&
        orderCode == other.orderCode &&
        status == other.status &&
        totalAmount == other.totalAmount &&
        shippingFee == other.shippingFee &&
        deliveryType == other.deliveryType &&
        deliveryAddress == other.deliveryAddress;
  }

  @override
  int get hashCode => const ListEquality().hash([
        orderCode,
        status,
        totalAmount,
        shippingFee,
        deliveryType,
        deliveryAddress
      ]);
}

Studio59PublicOrderDetailsStruct createStudio59PublicOrderDetailsStruct({
  String? orderCode,
  String? status,
  dynamic? totalAmount,
  dynamic? shippingFee,
  String? deliveryType,
  String? deliveryAddress,
}) =>
    Studio59PublicOrderDetailsStruct(
      orderCode: orderCode,
      status: status,
      totalAmount: totalAmount,
      shippingFee: shippingFee,
      deliveryType: deliveryType,
      deliveryAddress: deliveryAddress,
    );
