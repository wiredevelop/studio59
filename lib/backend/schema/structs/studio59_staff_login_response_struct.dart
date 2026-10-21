// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59StaffLoginResponse
class Studio59StaffLoginResponseStruct extends BaseStruct {
  Studio59StaffLoginResponseStruct({
    /// Studio59StaffLoginResponse.token
    String? token,

    /// Studio59StaffLoginResponse.user
    Studio59StaffUserStruct? user,
  })  : _token = token,
        _user = user;

  // "token" field.
  String? _token;
  String get token => _token ?? '';
  set token(String? val) => _token = val;

  bool hasToken() => _token != null;

  // "user" field.
  Studio59StaffUserStruct? _user;
  Studio59StaffUserStruct get user => _user ?? Studio59StaffUserStruct();
  set user(Studio59StaffUserStruct? val) => _user = val;

  void updateUser(Function(Studio59StaffUserStruct) updateFn) {
    updateFn(_user ??= Studio59StaffUserStruct());
  }

  bool hasUser() => _user != null;

  static Studio59StaffLoginResponseStruct fromMap(Map<String, dynamic> data) =>
      Studio59StaffLoginResponseStruct(
        token: data['token'] as String?,
        user: data['user'] is Studio59StaffUserStruct
            ? data['user']
            : Studio59StaffUserStruct.maybeFromMap(data['user']),
      );

  static Studio59StaffLoginResponseStruct? maybeFromMap(dynamic data) => data
          is Map
      ? Studio59StaffLoginResponseStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'token': _token,
        'user': _user?.toMap(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'token': serializeParam(
          _token,
          ParamType.String,
        ),
        'user': serializeParam(
          _user,
          ParamType.DataStruct,
        ),
      }.withoutNulls;

  static Studio59StaffLoginResponseStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59StaffLoginResponseStruct(
        token: deserializeParam(
          data['token'],
          ParamType.String,
          false,
        ),
        user: deserializeStructParam(
          data['user'],
          ParamType.DataStruct,
          false,
          structBuilder: Studio59StaffUserStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'Studio59StaffLoginResponseStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59StaffLoginResponseStruct &&
        token == other.token &&
        user == other.user;
  }

  @override
  int get hashCode => const ListEquality().hash([token, user]);
}

Studio59StaffLoginResponseStruct createStudio59StaffLoginResponseStruct({
  String? token,
  Studio59StaffUserStruct? user,
}) =>
    Studio59StaffLoginResponseStruct(
      token: token,
      user: user ?? Studio59StaffUserStruct(),
    );
