// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59StaffEvent
class Studio59StaffEventStruct extends BaseStruct {
  Studio59StaffEventStruct({
    /// Studio59StaffEvent.id
    int? id,

    /// Studio59StaffEvent.name
    String? name,
  })  : _id = id,
        _name = name;

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

  static Studio59StaffEventStruct fromMap(Map<String, dynamic> data) =>
      Studio59StaffEventStruct(
        id: castToType<int>(data['id']),
        name: data['name'] as String?,
      );

  static Studio59StaffEventStruct? maybeFromMap(dynamic data) => data is Map
      ? Studio59StaffEventStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'name': _name,
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
      }.withoutNulls;

  static Studio59StaffEventStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59StaffEventStruct(
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
      );

  @override
  String toString() => 'Studio59StaffEventStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59StaffEventStruct &&
        id == other.id &&
        name == other.name;
  }

  @override
  int get hashCode => const ListEquality().hash([id, name]);
}

Studio59StaffEventStruct createStudio59StaffEventStruct({
  int? id,
  String? name,
}) =>
    Studio59StaffEventStruct(
      id: id,
      name: name,
    );
