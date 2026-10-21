// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59PinResponse
class Studio59PinResponseStruct extends BaseStruct {
  Studio59PinResponseStruct({
    /// Studio59PinResponse.event_session_token
    String? eventSessionToken,

    /// Studio59PinResponse.event
    Studio59EventInfoStruct? event,
  })  : _eventSessionToken = eventSessionToken,
        _event = event;

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

  static Studio59PinResponseStruct fromMap(Map<String, dynamic> data) =>
      Studio59PinResponseStruct(
        eventSessionToken: data['event_session_token'] as String?,
        event: data['event'] is Studio59EventInfoStruct
            ? data['event']
            : Studio59EventInfoStruct.maybeFromMap(data['event']),
      );

  static Studio59PinResponseStruct? maybeFromMap(dynamic data) => data is Map
      ? Studio59PinResponseStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'event_session_token': _eventSessionToken,
        'event': _event?.toMap(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'event_session_token': serializeParam(
          _eventSessionToken,
          ParamType.String,
        ),
        'event': serializeParam(
          _event,
          ParamType.DataStruct,
        ),
      }.withoutNulls;

  static Studio59PinResponseStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59PinResponseStruct(
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
  String toString() => 'Studio59PinResponseStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59PinResponseStruct &&
        eventSessionToken == other.eventSessionToken &&
        event == other.event;
  }

  @override
  int get hashCode => const ListEquality().hash([eventSessionToken, event]);
}

Studio59PinResponseStruct createStudio59PinResponseStruct({
  String? eventSessionToken,
  Studio59EventInfoStruct? event,
}) =>
    Studio59PinResponseStruct(
      eventSessionToken: eventSessionToken,
      event: event ?? Studio59EventInfoStruct(),
    );
