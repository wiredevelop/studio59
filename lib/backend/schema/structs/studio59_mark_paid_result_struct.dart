// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59MarkPaidResult
class Studio59MarkPaidResultStruct extends BaseStruct {
  Studio59MarkPaidResultStruct({
    /// Studio59MarkPaidResult.success
    bool? success,

    /// Studio59MarkPaidResult.statusCode
    int? statusCode,

    /// Studio59MarkPaidResult.message
    String? message,
  })  : _success = success,
        _statusCode = statusCode,
        _message = message;

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

  // "message" field.
  String? _message;
  String get message => _message ?? '';
  set message(String? val) => _message = val;

  bool hasMessage() => _message != null;

  static Studio59MarkPaidResultStruct fromMap(Map<String, dynamic> data) =>
      Studio59MarkPaidResultStruct(
        success: data['success'] as bool?,
        statusCode: castToType<int>(data['statusCode']),
        message: data['message'] as String?,
      );

  static Studio59MarkPaidResultStruct? maybeFromMap(dynamic data) => data is Map
      ? Studio59MarkPaidResultStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'success': _success,
        'statusCode': _statusCode,
        'message': _message,
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
        'message': serializeParam(
          _message,
          ParamType.String,
        ),
      }.withoutNulls;

  static Studio59MarkPaidResultStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59MarkPaidResultStruct(
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
        message: deserializeParam(
          data['message'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'Studio59MarkPaidResultStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59MarkPaidResultStruct &&
        success == other.success &&
        statusCode == other.statusCode &&
        message == other.message;
  }

  @override
  int get hashCode => const ListEquality().hash([success, statusCode, message]);
}

Studio59MarkPaidResultStruct createStudio59MarkPaidResultStruct({
  bool? success,
  int? statusCode,
  String? message,
}) =>
    Studio59MarkPaidResultStruct(
      success: success,
      statusCode: statusCode,
      message: message,
    );
