// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59CartPhoto
class Studio59CartPhotoStruct extends BaseStruct {
  Studio59CartPhotoStruct({
    /// Studio59CartPhoto.photo_id
    int? photoId,

    /// Studio59CartPhoto.filename
    String? filename,

    /// Studio59CartPhoto.preview_url
    String? previewUrl,

    /// Studio59CartPhoto.quantity
    int? quantity,
  })  : _photoId = photoId,
        _filename = filename,
        _previewUrl = previewUrl,
        _quantity = quantity;

  // "photo_id" field.
  int? _photoId;
  int get photoId => _photoId ?? 0;
  set photoId(int? val) => _photoId = val;

  void incrementPhotoId(int amount) => photoId = photoId + amount;

  bool hasPhotoId() => _photoId != null;

  // "filename" field.
  String? _filename;
  String get filename => _filename ?? '';
  set filename(String? val) => _filename = val;

  bool hasFilename() => _filename != null;

  // "preview_url" field.
  String? _previewUrl;
  String get previewUrl => _previewUrl ?? '';
  set previewUrl(String? val) => _previewUrl = val;

  bool hasPreviewUrl() => _previewUrl != null;

  // "quantity" field.
  int? _quantity;
  int get quantity => _quantity ?? 0;
  set quantity(int? val) => _quantity = val;

  void incrementQuantity(int amount) => quantity = quantity + amount;

  bool hasQuantity() => _quantity != null;

  static Studio59CartPhotoStruct fromMap(Map<String, dynamic> data) =>
      Studio59CartPhotoStruct(
        photoId: castToType<int>(data['photo_id']),
        filename: data['filename'] as String?,
        previewUrl: data['preview_url'] as String?,
        quantity: castToType<int>(data['quantity']),
      );

  static Studio59CartPhotoStruct? maybeFromMap(dynamic data) => data is Map
      ? Studio59CartPhotoStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'photo_id': _photoId,
        'filename': _filename,
        'preview_url': _previewUrl,
        'quantity': _quantity,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'photo_id': serializeParam(
          _photoId,
          ParamType.int,
        ),
        'filename': serializeParam(
          _filename,
          ParamType.String,
        ),
        'preview_url': serializeParam(
          _previewUrl,
          ParamType.String,
        ),
        'quantity': serializeParam(
          _quantity,
          ParamType.int,
        ),
      }.withoutNulls;

  static Studio59CartPhotoStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59CartPhotoStruct(
        photoId: deserializeParam(
          data['photo_id'],
          ParamType.int,
          false,
        ),
        filename: deserializeParam(
          data['filename'],
          ParamType.String,
          false,
        ),
        previewUrl: deserializeParam(
          data['preview_url'],
          ParamType.String,
          false,
        ),
        quantity: deserializeParam(
          data['quantity'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'Studio59CartPhotoStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59CartPhotoStruct &&
        photoId == other.photoId &&
        filename == other.filename &&
        previewUrl == other.previewUrl &&
        quantity == other.quantity;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([photoId, filename, previewUrl, quantity]);
}

Studio59CartPhotoStruct createStudio59CartPhotoStruct({
  int? photoId,
  String? filename,
  String? previewUrl,
  int? quantity,
}) =>
    Studio59CartPhotoStruct(
      photoId: photoId,
      filename: filename,
      previewUrl: previewUrl,
      quantity: quantity,
    );
