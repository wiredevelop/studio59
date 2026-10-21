// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59GuestCashSubmitResult
class Studio59GuestCashSubmitResultStruct extends BaseStruct {
  Studio59GuestCashSubmitResultStruct({
    /// Studio59GuestCashSubmitResult.success
    bool? success,

    /// Studio59GuestCashSubmitResult.statusCode
    int? statusCode,

    /// Studio59GuestCashSubmitResult.uncertain
    bool? uncertain,

    /// Studio59GuestCashSubmitResult.message
    String? message,

    /// Studio59GuestCashSubmitResult.order
    Studio59OrderReceiptStruct? order,
  })  : _success = success,
        _statusCode = statusCode,
        _uncertain = uncertain,
        _message = message,
        _order = order;

  // "success" field.
  bool? _success;
  bool get success => _success ?? false;
  set success(bool? val) => _success = val;

  bool hasSuccess() => _success != null;

  // "statusCode" field.
  int? _statusCode;
  int get statusCode => _statusCode ?? 0;
  set statusCode(int? val) => _statusCode = val;

  void incrementStatusCode(int amount) => statusCode = statusCode + amount;

  bool hasStatusCode() => _statusCode != null;

  // "uncertain" field.
  bool? _uncertain;
  bool get uncertain => _uncertain ?? false;
  set uncertain(bool? val) => _uncertain = val;

  bool hasUncertain() => _uncertain != null;

  // "message" field.
  String? _message;
  String get message => _message ?? '';
  set message(String? val) => _message = val;

  bool hasMessage() => _message != null;

  // "order" field.
  Studio59OrderReceiptStruct? _order;
  Studio59OrderReceiptStruct get order =>
      _order ?? Studio59OrderReceiptStruct();
  set order(Studio59OrderReceiptStruct? val) => _order = val;

  void updateOrder(Function(Studio59OrderReceiptStruct) updateFn) {
    updateFn(_order ??= Studio59OrderReceiptStruct());
  }

  bool hasOrder() => _order != null;

  static Studio59GuestCashSubmitResultStruct fromMap(
          Map<String, dynamic> data) =>
      Studio59GuestCashSubmitResultStruct(
        success: data['success'] as bool?,
        statusCode: castToType<int>(data['statusCode']),
        uncertain: data['uncertain'] as bool?,
        message: data['message'] as String?,
        order: data['order'] is Studio59OrderReceiptStruct
            ? data['order']
            : Studio59OrderReceiptStruct.maybeFromMap(data['order']),
      );

  static Studio59GuestCashSubmitResultStruct? maybeFromMap(dynamic data) =>
      data is Map
          ? Studio59GuestCashSubmitResultStruct.fromMap(
              data.cast<String, dynamic>())
          : null;

  Map<String, dynamic> toMap() => {
        'success': _success,
        'statusCode': _statusCode,
        'uncertain': _uncertain,
        'message': _message,
        'order': _order?.toMap(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'success': serializeParam(
          _success,
          ParamType.bool,
        ),
        'statusCode': serializeParam(
          _statusCode,
          ParamType.int,
        ),
        'uncertain': serializeParam(
          _uncertain,
          ParamType.bool,
        ),
        'message': serializeParam(
          _message,
          ParamType.String,
        ),
        'order': serializeParam(
          _order,
          ParamType.DataStruct,
        ),
      }.withoutNulls;

  static Studio59GuestCashSubmitResultStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59GuestCashSubmitResultStruct(
        success: deserializeParam(
          data['success'],
          ParamType.bool,
          false,
        ),
        statusCode: deserializeParam(
          data['statusCode'],
          ParamType.int,
          false,
        ),
        uncertain: deserializeParam(
          data['uncertain'],
          ParamType.bool,
          false,
        ),
        message: deserializeParam(
          data['message'],
          ParamType.String,
          false,
        ),
        order: deserializeStructParam(
          data['order'],
          ParamType.DataStruct,
          false,
          structBuilder: Studio59OrderReceiptStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'Studio59GuestCashSubmitResultStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59GuestCashSubmitResultStruct &&
        success == other.success &&
        statusCode == other.statusCode &&
        uncertain == other.uncertain &&
        message == other.message &&
        order == other.order;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([success, statusCode, uncertain, message, order]);
}

Studio59GuestCashSubmitResultStruct createStudio59GuestCashSubmitResultStruct({
  bool? success,
  int? statusCode,
  bool? uncertain,
  String? message,
  Studio59OrderReceiptStruct? order,
}) =>
    Studio59GuestCashSubmitResultStruct(
      success: success,
      statusCode: statusCode,
      uncertain: uncertain,
      message: message,
      order: order ?? Studio59OrderReceiptStruct(),
    );
