// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59StaffUser
class Studio59StaffUserStruct extends BaseStruct {
  Studio59StaffUserStruct({
    /// Studio59StaffUser.id
    int? id,

    /// Studio59StaffUser.name
    String? name,

    /// Studio59StaffUser.email
    String? email,

    /// Studio59StaffUser.role
    String? role,
  })  : _id = id,
        _name = name,
        _email = email,
        _role = role;

  // "id" field.
  int? _id;
  int get id => _id ?? 0;
  set id(int? val) => _id = val;

  void incrementId(int amount) => id = id + amount;

  bool hasId() => _id != null;

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  set name(String? val) => _name = val;

  bool hasName() => _name != null;

  // "email" field.
  String? _email;
  String get email => _email ?? '';
  set email(String? val) => _email = val;

  bool hasEmail() => _email != null;

  // "role" field.
  String? _role;
  String get role => _role ?? '';
  set role(String? val) => _role = val;

  bool hasRole() => _role != null;

  static Studio59StaffUserStruct fromMap(Map<String, dynamic> data) =>
      Studio59StaffUserStruct(
        id: castToType<int>(data['id']),
        name: data['name'] as String?,
        email: data['email'] as String?,
        role: data['role'] as String?,
      );

  static Studio59StaffUserStruct? maybeFromMap(dynamic data) => data is Map
      ? Studio59StaffUserStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'name': _name,
        'email': _email,
        'role': _role,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id': serializeParam(
          _id,
          ParamType.int,
        ),
        'name': serializeParam(
          _name,
          ParamType.String,
        ),
        'email': serializeParam(
          _email,
          ParamType.String,
        ),
        'role': serializeParam(
          _role,
          ParamType.String,
        ),
      }.withoutNulls;

  static Studio59StaffUserStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59StaffUserStruct(
        id: deserializeParam(
          data['id'],
          ParamType.int,
          false,
        ),
        name: deserializeParam(
          data['name'],
          ParamType.String,
          false,
        ),
        email: deserializeParam(
          data['email'],
          ParamType.String,
          false,
        ),
        role: deserializeParam(
          data['role'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'Studio59StaffUserStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59StaffUserStruct &&
        id == other.id &&
        name == other.name &&
        email == other.email &&
        role == other.role;
  }

  @override
  int get hashCode => const ListEquality().hash([id, name, email, role]);
}

Studio59StaffUserStruct createStudio59StaffUserStruct({
  int? id,
  String? name,
  String? email,
  String? role,
}) =>
    Studio59StaffUserStruct(
      id: id,
      name: name,
      email: email,
      role: role,
    );
