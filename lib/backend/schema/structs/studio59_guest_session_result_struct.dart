// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59GuestSessionResult
class Studio59GuestSessionResultStruct extends BaseStruct {
  Studio59GuestSessionResultStruct({
    /// Studio59GuestSessionResult.success
    bool? success,

    /// Studio59GuestSessionResult.status_code
    int? statusCode,

    /// Studio59GuestSessionResult.message
    String? message,

    /// Studio59GuestSessionResult.event_session_token
    String? eventSessionToken,

    /// Studio59GuestSessionResult.event
    Studio59EventInfoStruct? event,
  })  : _success = success,
        _statusCode = statusCode,
        _message = message,
        _eventSessionToken = eventSessionToken,
        _event = event;

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

  // "event_session_token" field.
  String? _eventSessionToken;
  String get eventSessionToken => _eventSessionToken ?? '';
  set eventSessionToken(String? val) => _eventSessionToken = val;

  bool hasEventSessionToken() => _eventSessionToken != null;

  // "event" field.
  Studio59EventInfoStruct? _event;
  Studio59EventInfoStruct get event => _event ?? Studio59EventInfoStruct();
  set event(Studio59EventInfoStruct? val) => _event = val;

  void updateEvent(Function(Studio59EventInfoStruct) updateFn) {
    updateFn(_event ??= Studio59EventInfoStruct());
  }

  bool hasEvent() => _event != null;

  static Studio59GuestSessionResultStruct fromMap(Map<String, dynamic> data) =>
      Studio59GuestSessionResultStruct(
        success: data['success'] as bool?,
        statusCode: castToType<int>(data['status_code']),
        message: data['message'] as String?,
        eventSessionToken: data['event_session_token'] as String?,
        event: data['event'] is Studio59EventInfoStruct
            ? data['event']
            : Studio59EventInfoStruct.maybeFromMap(data['event']),
      );

  static Studio59GuestSessionResultStruct? maybeFromMap(dynamic data) => data
          is Map
      ? Studio59GuestSessionResultStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'success': _success,
        'status_code': _statusCode,
        'message': _message,
        'event_session_token': _eventSessionToken,
        'event': _event?.toMap(),
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
        'event_session_token': serializeParam(
          _eventSessionToken,
          ParamType.String,
        ),
        'event': serializeParam(
          _event,
          ParamType.DataStruct,
        ),
      }.withoutNulls;

  static Studio59GuestSessionResultStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59GuestSessionResultStruct(
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
        eventSessionToken: deserializeParam(
          data['event_session_token'],
          ParamType.String,
          false,
        ),
        event: deserializeStructParam(
          data['event'],
          ParamType.DataStruct,
          false,
          structBuilder: Studio59EventInfoStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'Studio59GuestSessionResultStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59GuestSessionResultStruct &&
        success == other.success &&
        statusCode == other.statusCode &&
        message == other.message &&
        eventSessionToken == other.eventSessionToken &&
        event == other.event;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([success, statusCode, message, eventSessionToken, event]);
}

Studio59GuestSessionResultStruct createStudio59GuestSessionResultStruct({
  bool? success,
  int? statusCode,
  String? message,
  String? eventSessionToken,
  Studio59EventInfoStruct? event,
}) =>
    Studio59GuestSessionResultStruct(
      success: success,
      statusCode: statusCode,
      message: message,
      eventSessionToken: eventSessionToken,
      event: event ?? Studio59EventInfoStruct(),
    );
