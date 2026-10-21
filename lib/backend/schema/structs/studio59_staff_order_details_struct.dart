// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59StaffOrderDetails
class Studio59StaffOrderDetailsStruct extends BaseStruct {
  Studio59StaffOrderDetailsStruct({
    /// Studio59StaffOrderDetails.id
    int? id,

    /// Studio59StaffOrderDetails.order_code
    String? orderCode,

    /// Studio59StaffOrderDetails.customer_name
    String? customerName,

    /// Studio59StaffOrderDetails.customer_email
    String? customerEmail,

    /// Studio59StaffOrderDetails.customer_phone
    String? customerPhone,

    /// Studio59StaffOrderDetails.payment_method
    String? paymentMethod,

    /// Studio59StaffOrderDetails.cash_received_amount
    dynamic cashReceivedAmount,

    /// Studio59StaffOrderDetails.cash_change_amount
    dynamic cashChangeAmount,

    /// Studio59StaffOrderDetails.cash_change_given
    bool? cashChangeGiven,

    /// Studio59StaffOrderDetails.cash_due_amount
    dynamic cashDueAmount,

    /// Studio59StaffOrderDetails.status
    String? status,

    /// Studio59StaffOrderDetails.total_amount
    dynamic totalAmount,

    /// Studio59StaffOrderDetails.product_type
    String? productType,

    /// Studio59StaffOrderDetails.delivery_type
    String? deliveryType,

    /// Studio59StaffOrderDetails.delivery_address
    String? deliveryAddress,

    /// Studio59StaffOrderDetails.notes
    String? notes,
  })  : _id = id,
        _orderCode = orderCode,
        _customerName = customerName,
        _customerEmail = customerEmail,
        _customerPhone = customerPhone,
        _paymentMethod = paymentMethod,
        _cashReceivedAmount = cashReceivedAmount,
        _cashChangeAmount = cashChangeAmount,
        _cashChangeGiven = cashChangeGiven,
        _cashDueAmount = cashDueAmount,
        _status = status,
        _totalAmount = totalAmount,
        _productType = productType,
        _deliveryType = deliveryType,
        _deliveryAddress = deliveryAddress,
        _notes = notes;

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

  // "customer_name" field.
  String? _customerName;
  String get customerName => _customerName ?? '';
  set customerName(String? val) => _customerName = val;

  bool hasCustomerName() => _customerName != null;

  // "customer_email" field.
  String? _customerEmail;
  String get customerEmail => _customerEmail ?? '';
  set customerEmail(String? val) => _customerEmail = val;

  bool hasCustomerEmail() => _customerEmail != null;

  // "customer_phone" field.
  String? _customerPhone;
  String get customerPhone => _customerPhone ?? '';
  set customerPhone(String? val) => _customerPhone = val;

  bool hasCustomerPhone() => _customerPhone != null;

  // "payment_method" field.
  String? _paymentMethod;
  String get paymentMethod => _paymentMethod ?? '';
  set paymentMethod(String? val) => _paymentMethod = val;

  bool hasPaymentMethod() => _paymentMethod != null;

  // "cash_received_amount" field.
  dynamic? _cashReceivedAmount;
  dynamic? get cashReceivedAmount => _cashReceivedAmount;
  set cashReceivedAmount(dynamic? val) => _cashReceivedAmount = val;

  bool hasCashReceivedAmount() => _cashReceivedAmount != null;

  // "cash_change_amount" field.
  dynamic? _cashChangeAmount;
  dynamic? get cashChangeAmount => _cashChangeAmount;
  set cashChangeAmount(dynamic? val) => _cashChangeAmount = val;

  bool hasCashChangeAmount() => _cashChangeAmount != null;

  // "cash_change_given" field.
  bool? _cashChangeGiven;
  bool get cashChangeGiven => _cashChangeGiven ?? false;
  set cashChangeGiven(bool? val) => _cashChangeGiven = val;

  bool hasCashChangeGiven() => _cashChangeGiven != null;

  // "cash_due_amount" field.
  dynamic? _cashDueAmount;
  dynamic? get cashDueAmount => _cashDueAmount;
  set cashDueAmount(dynamic? val) => _cashDueAmount = val;

  bool hasCashDueAmount() => _cashDueAmount != null;

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

  // "product_type" field.
  String? _productType;
  String get productType => _productType ?? '';
  set productType(String? val) => _productType = val;

  bool hasProductType() => _productType != null;

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

  // "notes" field.
  String? _notes;
  String get notes => _notes ?? '';
  set notes(String? val) => _notes = val;

  bool hasNotes() => _notes != null;

  static Studio59StaffOrderDetailsStruct fromMap(Map<String, dynamic> data) =>
      Studio59StaffOrderDetailsStruct(
        id: castToType<int>(data['id']),
        orderCode: data['order_code'] as String?,
        customerName: data['customer_name'] as String?,
        customerEmail: data['customer_email'] as String?,
        customerPhone: data['customer_phone'] as String?,
        paymentMethod: data['payment_method'] as String?,
        cashReceivedAmount: data['cash_received_amount'] as dynamic?,
        cashChangeAmount: data['cash_change_amount'] as dynamic?,
        cashChangeGiven: data['cash_change_given'] as bool?,
        cashDueAmount: data['cash_due_amount'] as dynamic?,
        status: data['status'] as String?,
        totalAmount: data['total_amount'] as dynamic?,
        productType: data['product_type'] as String?,
        deliveryType: data['delivery_type'] as String?,
        deliveryAddress: data['delivery_address'] as String?,
        notes: data['notes'] as String?,
      );

  static Studio59StaffOrderDetailsStruct? maybeFromMap(dynamic data) => data
          is Map
      ? Studio59StaffOrderDetailsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'order_code': _orderCode,
        'customer_name': _customerName,
        'customer_email': _customerEmail,
        'customer_phone': _customerPhone,
        'payment_method': _paymentMethod,
        'cash_received_amount': _cashReceivedAmount,
        'cash_change_amount': _cashChangeAmount,
        'cash_change_given': _cashChangeGiven,
        'cash_due_amount': _cashDueAmount,
        'status': _status,
        'total_amount': _totalAmount,
        'product_type': _productType,
        'delivery_type': _deliveryType,
        'delivery_address': _deliveryAddress,
        'notes': _notes,
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
        'customer_name': serializeParam(
          _customerName,
          ParamType.String,
        ),
        'customer_email': serializeParam(
          _customerEmail,
          ParamType.String,
        ),
        'customer_phone': serializeParam(
          _customerPhone,
          ParamType.String,
        ),
        'payment_method': serializeParam(
          _paymentMethod,
          ParamType.String,
        ),
        'cash_received_amount': serializeParam(
          _cashReceivedAmount,
          ParamType.JSON,
        ),
        'cash_change_amount': serializeParam(
          _cashChangeAmount,
          ParamType.JSON,
        ),
        'cash_change_given': serializeParam(
          _cashChangeGiven,
          ParamType.bool,
        ),
        'cash_due_amount': serializeParam(
          _cashDueAmount,
          ParamType.JSON,
        ),
        'status': serializeParam(
          _status,
          ParamType.String,
        ),
        'total_amount': serializeParam(
          _totalAmount,
          ParamType.JSON,
        ),
        'product_type': serializeParam(
          _productType,
          ParamType.String,
        ),
        'delivery_type': serializeParam(
          _deliveryType,
          ParamType.String,
        ),
        'delivery_address': serializeParam(
          _deliveryAddress,
          ParamType.String,
        ),
        'notes': serializeParam(
          _notes,
          ParamType.String,
        ),
      }.withoutNulls;

  static Studio59StaffOrderDetailsStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59StaffOrderDetailsStruct(
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
        customerName: deserializeParam(
          data['customer_name'],
          ParamType.String,
          false,
        ),
        customerEmail: deserializeParam(
          data['customer_email'],
          ParamType.String,
          false,
        ),
        customerPhone: deserializeParam(
          data['customer_phone'],
          ParamType.String,
          false,
        ),
        paymentMethod: deserializeParam(
          data['payment_method'],
          ParamType.String,
          false,
        ),
        cashReceivedAmount: deserializeParam(
          data['cash_received_amount'],
          ParamType.JSON,
          false,
        ),
        cashChangeAmount: deserializeParam(
          data['cash_change_amount'],
          ParamType.JSON,
          false,
        ),
        cashChangeGiven: deserializeParam(
          data['cash_change_given'],
          ParamType.bool,
          false,
        ),
        cashDueAmount: deserializeParam(
          data['cash_due_amount'],
          ParamType.JSON,
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
        productType: deserializeParam(
          data['product_type'],
          ParamType.String,
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
        notes: deserializeParam(
          data['notes'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'Studio59StaffOrderDetailsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59StaffOrderDetailsStruct &&
        id == other.id &&
        orderCode == other.orderCode &&
        customerName == other.customerName &&
        customerEmail == other.customerEmail &&
        customerPhone == other.customerPhone &&
        paymentMethod == other.paymentMethod &&
        cashReceivedAmount == other.cashReceivedAmount &&
        cashChangeAmount == other.cashChangeAmount &&
        cashChangeGiven == other.cashChangeGiven &&
        cashDueAmount == other.cashDueAmount &&
        status == other.status &&
        totalAmount == other.totalAmount &&
        productType == other.productType &&
        deliveryType == other.deliveryType &&
        deliveryAddress == other.deliveryAddress &&
        notes == other.notes;
  }

  @override
  int get hashCode => const ListEquality().hash([
        id,
        orderCode,
        customerName,
        customerEmail,
        customerPhone,
        paymentMethod,
        cashReceivedAmount,
        cashChangeAmount,
        cashChangeGiven,
        cashDueAmount,
        status,
        totalAmount,
        productType,
        deliveryType,
        deliveryAddress,
        notes
      ]);
}

Studio59StaffOrderDetailsStruct createStudio59StaffOrderDetailsStruct({
  int? id,
  String? orderCode,
  String? customerName,
  String? customerEmail,
  String? customerPhone,
  String? paymentMethod,
  dynamic? cashReceivedAmount,
  dynamic? cashChangeAmount,
  bool? cashChangeGiven,
  dynamic? cashDueAmount,
  String? status,
  dynamic? totalAmount,
  String? productType,
  String? deliveryType,
  String? deliveryAddress,
  String? notes,
}) =>
    Studio59StaffOrderDetailsStruct(
      id: id,
      orderCode: orderCode,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      paymentMethod: paymentMethod,
      cashReceivedAmount: cashReceivedAmount,
      cashChangeAmount: cashChangeAmount,
      cashChangeGiven: cashChangeGiven,
      cashDueAmount: cashDueAmount,
      status: status,
      totalAmount: totalAmount,
      productType: productType,
      deliveryType: deliveryType,
      deliveryAddress: deliveryAddress,
      notes: notes,
    );
