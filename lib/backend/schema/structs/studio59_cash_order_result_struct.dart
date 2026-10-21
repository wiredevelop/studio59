// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59CashOrderResult
class Studio59CashOrderResultStruct extends BaseStruct {
  Studio59CashOrderResultStruct({
    /// Studio59CashOrderResult.success
    bool? success,

    /// Studio59CashOrderResult.order
    Studio59OrderReceiptStruct? order,
  })  : _success = success,
        _order = order;

  // "success" field.
  bool? _success;
  bool get success => _success ?? false;
  set success(bool? val) => _success = val;

  bool hasSuccess() => _success != null;

  // "order" field.
  Studio59OrderReceiptStruct? _order;
  Studio59OrderReceiptStruct get order =>
      _order ?? Studio59OrderReceiptStruct();
  set order(Studio59OrderReceiptStruct? val) => _order = val;

  void updateOrder(Function(Studio59OrderReceiptStruct) updateFn) {
    updateFn(_order ??= Studio59OrderReceiptStruct());
  }

  bool hasOrder() => _order != null;

  static Studio59CashOrderResultStruct fromMap(Map<String, dynamic> data) =>
      Studio59CashOrderResultStruct(
        success: data['success'] as bool?,
        order: data['order'] is Studio59OrderReceiptStruct
            ? data['order']
            : Studio59OrderReceiptStruct.maybeFromMap(data['order']),
      );

  static Studio59CashOrderResultStruct? maybeFromMap(dynamic data) =>
      data is Map
          ? Studio59CashOrderResultStruct.fromMap(data.cast<String, dynamic>())
          : null;

  Map<String, dynamic> toMap() => {
        'success': _success,
        'order': _order?.toMap(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'success': serializeParam(
          _success,
          ParamType.bool,
        ),
        'order': serializeParam(
          _order,
          ParamType.DataStruct,
        ),
      }.withoutNulls;

  static Studio59CashOrderResultStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59CashOrderResultStruct(
        success: deserializeParam(
          data['success'],
          ParamType.bool,
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
  String toString() => 'Studio59CashOrderResultStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59CashOrderResultStruct &&
        success == other.success &&
        order == other.order;
  }

  @override
  int get hashCode => const ListEquality().hash([success, order]);
}

Studio59CashOrderResultStruct createStudio59CashOrderResultStruct({
  bool? success,
  Studio59OrderReceiptStruct? order,
}) =>
    Studio59CashOrderResultStruct(
      success: success,
      order: order ?? Studio59OrderReceiptStruct(),
    );
