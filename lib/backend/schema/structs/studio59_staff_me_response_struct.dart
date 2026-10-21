// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59StaffMeResponse
class Studio59StaffMeResponseStruct extends BaseStruct {
  Studio59StaffMeResponseStruct({
    /// Studio59StaffMeResponse.user
    Studio59StaffUserStruct? user,
  }) : _user = user;

  // "user" field.
  Studio59StaffUserStruct? _user;
  Studio59StaffUserStruct get user => _user ?? Studio59StaffUserStruct();
  set user(Studio59StaffUserStruct? val) => _user = val;

  void updateUser(Function(Studio59StaffUserStruct) updateFn) {
    updateFn(_user ??= Studio59StaffUserStruct());
  }

  bool hasUser() => _user != null;

  static Studio59StaffMeResponseStruct fromMap(Map<String, dynamic> data) =>
      Studio59StaffMeResponseStruct(
        user: data['user'] is Studio59StaffUserStruct
            ? data['user']
            : Studio59StaffUserStruct.maybeFromMap(data['user']),
      );

  static Studio59StaffMeResponseStruct? maybeFromMap(dynamic data) =>
      data is Map
          ? Studio59StaffMeResponseStruct.fromMap(data.cast<String, dynamic>())
          : null;

  Map<String, dynamic> toMap() => {
        'user': _user?.toMap(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'user': serializeParam(
          _user,
          ParamType.DataStruct,
        ),
      }.withoutNulls;

  static Studio59StaffMeResponseStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59StaffMeResponseStruct(
        user: deserializeStructParam(
          data['user'],
          ParamType.DataStruct,
          false,
          structBuilder: Studio59StaffUserStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'Studio59StaffMeResponseStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59StaffMeResponseStruct && user == other.user;
  }

  @override
  int get hashCode => const ListEquality().hash([user]);
}

Studio59StaffMeResponseStruct createStudio59StaffMeResponseStruct({
  Studio59StaffUserStruct? user,
}) =>
    Studio59StaffMeResponseStruct(
      user: user ?? Studio59StaffUserStruct(),
    );
