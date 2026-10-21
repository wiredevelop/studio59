// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59EventInfo
class Studio59EventInfoStruct extends BaseStruct {
  Studio59EventInfoStruct({
    /// Studio59EventInfo.id
    int? id,

    /// Studio59EventInfo.name
    String? name,

    /// Studio59EventInfo.price_per_photo
    double? pricePerPhoto,
  })  : _id = id,
        _name = name,
        _pricePerPhoto = pricePerPhoto;

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

  // "price_per_photo" field.
  double? _pricePerPhoto;
  double get pricePerPhoto => _pricePerPhoto ?? 0.0;
  set pricePerPhoto(double? val) => _pricePerPhoto = val;

  void incrementPricePerPhoto(double amount) =>
      pricePerPhoto = pricePerPhoto + amount;

  bool hasPricePerPhoto() => _pricePerPhoto != null;

  static Studio59EventInfoStruct fromMap(Map<String, dynamic> data) =>
      Studio59EventInfoStruct(
        id: castToType<int>(data['id']),
        name: data['name'] as String?,
        pricePerPhoto: castToType<double>(data['price_per_photo']),
      );

  static Studio59EventInfoStruct? maybeFromMap(dynamic data) => data is Map
      ? Studio59EventInfoStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'name': _name,
        'price_per_photo': _pricePerPhoto,
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
        'price_per_photo': serializeParam(
          _pricePerPhoto,
          ParamType.double,
        ),
      }.withoutNulls;

  static Studio59EventInfoStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59EventInfoStruct(
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
        pricePerPhoto: deserializeParam(
          data['price_per_photo'],
          ParamType.double,
          false,
        ),
      );

  @override
  String toString() => 'Studio59EventInfoStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59EventInfoStruct &&
        id == other.id &&
        name == other.name &&
        pricePerPhoto == other.pricePerPhoto;
  }

  @override
  int get hashCode => const ListEquality().hash([id, name, pricePerPhoto]);
}

Studio59EventInfoStruct createStudio59EventInfoStruct({
  int? id,
  String? name,
  double? pricePerPhoto,
}) =>
    Studio59EventInfoStruct(
      id: id,
      name: name,
      pricePerPhoto: pricePerPhoto,
    );
