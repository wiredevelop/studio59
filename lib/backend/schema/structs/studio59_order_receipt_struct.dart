// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59OrderReceipt
class Studio59OrderReceiptStruct extends BaseStruct {
  Studio59OrderReceiptStruct({
    /// Studio59OrderReceipt.order_code
    String? orderCode,

    /// Studio59OrderReceipt.status
    String? status,

    /// Studio59OrderReceipt.total_amount
    dynamic totalAmount,
  })  : _orderCode = orderCode,
        _status = status,
        _totalAmount = totalAmount;

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

  static Studio59OrderReceiptStruct fromMap(Map<String, dynamic> data) =>
      Studio59OrderReceiptStruct(
        orderCode: data['order_code'] as String?,
        status: data['status'] as String?,
        totalAmount: data['total_amount'] as dynamic?,
      );

  static Studio59OrderReceiptStruct? maybeFromMap(dynamic data) => data is Map
      ? Studio59OrderReceiptStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'order_code': _orderCode,
        'status': _status,
        'total_amount': _totalAmount,
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
      }.withoutNulls;

  static Studio59OrderReceiptStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59OrderReceiptStruct(
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
      );

  @override
  String toString() => 'Studio59OrderReceiptStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59OrderReceiptStruct &&
        orderCode == other.orderCode &&
        status == other.status &&
        totalAmount == other.totalAmount;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([orderCode, status, totalAmount]);
}

Studio59OrderReceiptStruct createStudio59OrderReceiptStruct({
  String? orderCode,
  String? status,
  dynamic? totalAmount,
}) =>
    Studio59OrderReceiptStruct(
      orderCode: orderCode,
      status: status,
      totalAmount: totalAmount,
    );
