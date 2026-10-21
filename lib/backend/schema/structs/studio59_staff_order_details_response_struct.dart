// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59StaffOrderDetailsResponse
class Studio59StaffOrderDetailsResponseStruct extends BaseStruct {
  Studio59StaffOrderDetailsResponseStruct({
    /// Studio59StaffOrderDetailsResponse.data
    Studio59StaffOrderStruct? data,
  }) : _data = data;

  // "data" field.
  Studio59StaffOrderStruct? _data;
  Studio59StaffOrderStruct get data => _data ?? Studio59StaffOrderStruct();
  set data(Studio59StaffOrderStruct? val) => _data = val;

  void updateData(Function(Studio59StaffOrderStruct) updateFn) {
    updateFn(_data ??= Studio59StaffOrderStruct());
  }

  bool hasData() => _data != null;

  static Studio59StaffOrderDetailsResponseStruct fromMap(
          Map<String, dynamic> data) =>
      Studio59StaffOrderDetailsResponseStruct(
        data: data['data'] is Studio59StaffOrderStruct
            ? data['data']
            : Studio59StaffOrderStruct.maybeFromMap(data['data']),
      );

  static Studio59StaffOrderDetailsResponseStruct? maybeFromMap(dynamic data) =>
      data is Map
          ? Studio59StaffOrderDetailsResponseStruct.fromMap(
              data.cast<String, dynamic>())
          : null;

  Map<String, dynamic> toMap() => {
        'data': _data?.toMap(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'data': serializeParam(
          _data,
          ParamType.DataStruct,
        ),
      }.withoutNulls;

  static Studio59StaffOrderDetailsResponseStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59StaffOrderDetailsResponseStruct(
        data: deserializeStructParam(
          data['data'],
          ParamType.DataStruct,
          false,
          structBuilder: Studio59StaffOrderStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'Studio59StaffOrderDetailsResponseStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59StaffOrderDetailsResponseStruct &&
        data == other.data;
  }

  @override
  int get hashCode => const ListEquality().hash([data]);
}

Studio59StaffOrderDetailsResponseStruct
    createStudio59StaffOrderDetailsResponseStruct({
  Studio59StaffOrderStruct? data,
}) =>
        Studio59StaffOrderDetailsResponseStruct(
          data: data ?? Studio59StaffOrderStruct(),
        );
