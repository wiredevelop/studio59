// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59StaffAuthResult
class Studio59StaffAuthResultStruct extends BaseStruct {
  Studio59StaffAuthResultStruct({
    /// Studio59StaffAuthResult.success
    bool? success,

    /// Studio59StaffAuthResult.status_code
    int? statusCode,

    /// Studio59StaffAuthResult.message
    String? message,

    /// Studio59StaffAuthResult.token
    String? token,

    /// Studio59StaffAuthResult.user_name
    String? userName,

    /// Studio59StaffAuthResult.events
    List<Studio59StaffEventStruct>? events,
  })  : _success = success,
        _statusCode = statusCode,
        _message = message,
        _token = token,
        _userName = userName,
        _events = events;

  // "success" field.
  bool? _success;
  bool get success => _success ?? false;
  set success(bool? val) => _success = val;

  bool hasSuccess() => _success != null;

  // "status_code" field.
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

  // "token" field.
  String? _token;
  String get token => _token ?? '';
  set token(String? val) => _token = val;

  bool hasToken() => _token != null;

  // "user_name" field.
  String? _userName;
  String get userName => _userName ?? '';
  set userName(String? val) => _userName = val;

  bool hasUserName() => _userName != null;

  // "events" field.
  List<Studio59StaffEventStruct>? _events;
  List<Studio59StaffEventStruct> get events => _events ?? const [];
  set events(List<Studio59StaffEventStruct>? val) => _events = val;

  void updateEvents(Function(List<Studio59StaffEventStruct>) updateFn) {
    updateFn(_events ??= []);
  }

  bool hasEvents() => _events != null;

  static Studio59StaffAuthResultStruct fromMap(Map<String, dynamic> data) =>
      Studio59StaffAuthResultStruct(
        success: data['success'] as bool?,
        statusCode: castToType<int>(data['status_code']),
        message: data['message'] as String?,
        token: data['token'] as String?,
        userName: data['user_name'] as String?,
        events: getStructList(
          data['events'],
          Studio59StaffEventStruct.fromMap,
        ),
      );

  static Studio59StaffAuthResultStruct? maybeFromMap(dynamic data) =>
      data is Map
          ? Studio59StaffAuthResultStruct.fromMap(data.cast<String, dynamic>())
          : null;

  Map<String, dynamic> toMap() => {
        'success': _success,
        'status_code': _statusCode,
        'message': _message,
        'token': _token,
        'user_name': _userName,
        'events': _events?.map((e) => e.toMap()).toList(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'success': serializeParam(
          _success,
          ParamType.bool,
        ),
        'status_code': serializeParam(
          _statusCode,
          ParamType.int,
        ),
        'message': serializeParam(
          _message,
          ParamType.String,
        ),
        'token': serializeParam(
          _token,
          ParamType.String,
        ),
        'user_name': serializeParam(
          _userName,
          ParamType.String,
        ),
        'events': serializeParam(
          _events,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static Studio59StaffAuthResultStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59StaffAuthResultStruct(
        success: deserializeParam(
          data['success'],
          ParamType.bool,
          false,
        ),
        statusCode: deserializeParam(
          data['status_code'],
          ParamType.int,
          false,
        ),
        message: deserializeParam(
          data['message'],
          ParamType.String,
          false,
        ),
        token: deserializeParam(
          data['token'],
          ParamType.String,
          false,
        ),
        userName: deserializeParam(
          data['user_name'],
          ParamType.String,
          false,
        ),
        events: deserializeStructParam<Studio59StaffEventStruct>(
          data['events'],
          ParamType.DataStruct,
          true,
          structBuilder: Studio59StaffEventStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'Studio59StaffAuthResultStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is Studio59StaffAuthResultStruct &&
        success == other.success &&
        statusCode == other.statusCode &&
        message == other.message &&
        token == other.token &&
        userName == other.userName &&
        listEquality.equals(events, other.events);
  }

  @override
  int get hashCode => const ListEquality().hash([
        success,
        statusCode,
        message,
        token,
        userName,
        const ListEquality().hash(events)
      ]);
}

Studio59StaffAuthResultStruct createStudio59StaffAuthResultStruct({
  bool? success,
  int? statusCode,
  String? message,
  String? token,
  String? userName,
}) =>
    Studio59StaffAuthResultStruct(
      success: success,
      statusCode: statusCode,
      message: message,
      token: token,
      userName: userName,
    );
