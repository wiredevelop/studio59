// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59StaffOrder
class Studio59StaffOrderStruct extends BaseStruct {
  Studio59StaffOrderStruct({
    /// Studio59StaffOrder.id
    int? id,

    /// Studio59StaffOrder.order_code
    String? orderCode,

    /// Studio59StaffOrder.status
    String? status,

    /// Studio59StaffOrder.customer_name
    String? customerName,

    /// Studio59StaffOrder.total_amount
    dynamic totalAmount,

    /// Studio59StaffOrder.amount_received
    dynamic amountReceived,

    /// Studio59StaffOrder.change_due
    dynamic changeDue,

    /// Studio59StaffOrder.amount_due
    dynamic amountDue,
  })  : _id = id,
        _orderCode = orderCode,
        _status = status,
        _customerName = customerName,
        _totalAmount = totalAmount,
        _amountReceived = amountReceived,
        _changeDue = changeDue,
        _amountDue = amountDue;

  // "id" field.
  int? _id;
  int get id => _id ?? 0;
  set id(int? val) => _id = val;

  void incrementId(int amount) => id = id + amount;

  bool hasId() => _id != null;

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

  // "customer_name" field.
  String? _customerName;
  String get customerName => _customerName ?? '';
  set customerName(String? val) => _customerName = val;

  bool hasCustomerName() => _customerName != null;

  // "total_amount" field.
  dynamic? _totalAmount;
  dynamic? get totalAmount => _totalAmount;
  set totalAmount(dynamic? val) => _totalAmount = val;

  bool hasTotalAmount() => _totalAmount != null;

  // "amount_received" field.
  dynamic? _amountReceived;
  dynamic? get amountReceived => _amountReceived;
  set amountReceived(dynamic? val) => _amountReceived = val;

  bool hasAmountReceived() => _amountReceived != null;

  // "change_due" field.
  dynamic? _changeDue;
  dynamic? get changeDue => _changeDue;
  set changeDue(dynamic? val) => _changeDue = val;

  bool hasChangeDue() => _changeDue != null;

  // "amount_due" field.
  dynamic? _amountDue;
  dynamic? get amountDue => _amountDue;
  set amountDue(dynamic? val) => _amountDue = val;

  bool hasAmountDue() => _amountDue != null;

  static Studio59StaffOrderStruct fromMap(Map<String, dynamic> data) =>
      Studio59StaffOrderStruct(
        id: castToType<int>(data['id']),
        orderCode: data['order_code'] as String?,
        status: data['status'] as String?,
        customerName: data['customer_name'] as String?,
        totalAmount: data['total_amount'] as dynamic?,
        amountReceived: data['amount_received'] as dynamic?,
        changeDue: data['change_due'] as dynamic?,
        amountDue: data['amount_due'] as dynamic?,
      );

  static Studio59StaffOrderStruct? maybeFromMap(dynamic data) => data is Map
      ? Studio59StaffOrderStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'order_code': _orderCode,
        'status': _status,
        'customer_name': _customerName,
        'total_amount': _totalAmount,
        'amount_received': _amountReceived,
        'change_due': _changeDue,
        'amount_due': _amountDue,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id': serializeParam(
          _id,
          ParamType.int,
        ),
        'order_code': serializeParam(
          _orderCode,
          ParamType.String,
        ),
        'status': serializeParam(
          _status,
          ParamType.String,
        ),
        'customer_name': serializeParam(
          _customerName,
          ParamType.String,
        ),
        'total_amount': serializeParam(
          _totalAmount,
          ParamType.JSON,
        ),
        'amount_received': serializeParam(
          _amountReceived,
          ParamType.JSON,
        ),
        'change_due': serializeParam(
          _changeDue,
          ParamType.JSON,
        ),
        'amount_due': serializeParam(
          _amountDue,
          ParamType.JSON,
        ),
      }.withoutNulls;

  static Studio59StaffOrderStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59StaffOrderStruct(
        id: deserializeParam(
          data['id'],
          ParamType.int,
          false,
        ),
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
        customerName: deserializeParam(
          data['customer_name'],
          ParamType.String,
          false,
        ),
        totalAmount: deserializeParam(
          data['total_amount'],
          ParamType.JSON,
          false,
        ),
        amountReceived: deserializeParam(
          data['amount_received'],
          ParamType.JSON,
          false,
        ),
        changeDue: deserializeParam(
          data['change_due'],
          ParamType.JSON,
          false,
        ),
        amountDue: deserializeParam(
          data['amount_due'],
          ParamType.JSON,
          false,
        ),
      );

  @override
  String toString() => 'Studio59StaffOrderStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59StaffOrderStruct &&
        id == other.id &&
        orderCode == other.orderCode &&
        status == other.status &&
        customerName == other.customerName &&
        totalAmount == other.totalAmount &&
        amountReceived == other.amountReceived &&
        changeDue == other.changeDue &&
        amountDue == other.amountDue;
  }

  @override
  int get hashCode => const ListEquality().hash([
        id,
        orderCode,
        status,
        customerName,
        totalAmount,
        amountReceived,
        changeDue,
        amountDue
      ]);
}

Studio59StaffOrderStruct createStudio59StaffOrderStruct({
  int? id,
  String? orderCode,
  String? status,
  String? customerName,
  dynamic? totalAmount,
  dynamic? amountReceived,
  dynamic? changeDue,
  dynamic? amountDue,
}) =>
    Studio59StaffOrderStruct(
      id: id,
      orderCode: orderCode,
      status: status,
      customerName: customerName,
      totalAmount: totalAmount,
      amountReceived: amountReceived,
      changeDue: changeDue,
      amountDue: amountDue,
    );
