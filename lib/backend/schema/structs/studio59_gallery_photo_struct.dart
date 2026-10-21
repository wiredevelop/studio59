// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59GalleryPhoto
class Studio59GalleryPhotoStruct extends BaseStruct {
  Studio59GalleryPhotoStruct({
    /// Studio59GalleryPhoto.id
    int? id,

    /// Studio59GalleryPhoto.filename
    String? filename,

    /// Studio59GalleryPhoto.preview_url
    String? previewUrl,
  })  : _id = id,
        _filename = filename,
        _previewUrl = previewUrl;

  // "id" field.
  int? _id;
  int get id => _id ?? 0;
  set id(int? val) => _id = val;

  void incrementId(int amount) => id = id + amount;

  bool hasId() => _id != null;

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

  static Studio59GalleryPhotoStruct fromMap(Map<String, dynamic> data) =>
      Studio59GalleryPhotoStruct(
        id: castToType<int>(data['id']),
        filename: data['filename'] as String?,
        previewUrl: data['preview_url'] as String?,
      );

  static Studio59GalleryPhotoStruct? maybeFromMap(dynamic data) => data is Map
      ? Studio59GalleryPhotoStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'filename': _filename,
        'preview_url': _previewUrl,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id': serializeParam(
          _id,
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
      }.withoutNulls;

  static Studio59GalleryPhotoStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59GalleryPhotoStruct(
        id: deserializeParam(
          data['id'],
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
      );

  @override
  String toString() => 'Studio59GalleryPhotoStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Studio59GalleryPhotoStruct &&
        id == other.id &&
        filename == other.filename &&
        previewUrl == other.previewUrl;
  }

  @override
  int get hashCode => const ListEquality().hash([id, filename, previewUrl]);
}

Studio59GalleryPhotoStruct createStudio59GalleryPhotoStruct({
  int? id,
  String? filename,
  String? previewUrl,
}) =>
    Studio59GalleryPhotoStruct(
      id: id,
      filename: filename,
      previewUrl: previewUrl,
    );
