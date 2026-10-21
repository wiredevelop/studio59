// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59GalleryFetchResult
class Studio59GalleryFetchResultStruct extends BaseStruct {
  Studio59GalleryFetchResultStruct({
    /// Studio59GalleryFetchResult.success
    bool? success,

    /// Studio59GalleryFetchResult.status_code
    int? statusCode,

    /// Studio59GalleryFetchResult.message
    String? message,

    /// Studio59GalleryFetchResult.current_page
    int? currentPage,

    /// Studio59GalleryFetchResult.last_page
    int? lastPage,

    /// Studio59GalleryFetchResult.total
    int? total,

    /// Studio59GalleryFetchResult.data
    List<Studio59GalleryPhotoStruct>? data,
  })  : _success = success,
        _statusCode = statusCode,
        _message = message,
        _currentPage = currentPage,
        _lastPage = lastPage,
        _total = total,
        _data = data;

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

  // "current_page" field.
  int? _currentPage;
  int get currentPage => _currentPage ?? 0;
  set currentPage(int? val) => _currentPage = val;

  void incrementCurrentPage(int amount) => currentPage = currentPage + amount;

  bool hasCurrentPage() => _currentPage != null;

  // "last_page" field.
  int? _lastPage;
  int get lastPage => _lastPage ?? 0;
  set lastPage(int? val) => _lastPage = val;

  void incrementLastPage(int amount) => lastPage = lastPage + amount;

  bool hasLastPage() => _lastPage != null;

  // "total" field.
  int? _total;
  int get total => _total ?? 0;
  set total(int? val) => _total = val;

  void incrementTotal(int amount) => total = total + amount;

  bool hasTotal() => _total != null;

  // "data" field.
  List<Studio59GalleryPhotoStruct>? _data;
  List<Studio59GalleryPhotoStruct> get data => _data ?? const [];
  set data(List<Studio59GalleryPhotoStruct>? val) => _data = val;

  void updateData(Function(List<Studio59GalleryPhotoStruct>) updateFn) {
    updateFn(_data ??= []);
  }

  bool hasData() => _data != null;

  static Studio59GalleryFetchResultStruct fromMap(Map<String, dynamic> data) =>
      Studio59GalleryFetchResultStruct(
        success: data['success'] as bool?,
        statusCode: castToType<int>(data['status_code']),
        message: data['message'] as String?,
        currentPage: castToType<int>(data['current_page']),
        lastPage: castToType<int>(data['last_page']),
        total: castToType<int>(data['total']),
        data: getStructList(
          data['data'],
          Studio59GalleryPhotoStruct.fromMap,
        ),
      );

  static Studio59GalleryFetchResultStruct? maybeFromMap(dynamic data) => data
          is Map
      ? Studio59GalleryFetchResultStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'success': _success,
        'status_code': _statusCode,
        'message': _message,
        'current_page': _currentPage,
        'last_page': _lastPage,
        'total': _total,
        'data': _data?.map((e) => e.toMap()).toList(),
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
        'current_page': serializeParam(
          _currentPage,
          ParamType.int,
        ),
        'last_page': serializeParam(
          _lastPage,
          ParamType.int,
        ),
        'total': serializeParam(
          _total,
          ParamType.int,
        ),
        'data': serializeParam(
          _data,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static Studio59GalleryFetchResultStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59GalleryFetchResultStruct(
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
        currentPage: deserializeParam(
          data['current_page'],
          ParamType.int,
          false,
        ),
        lastPage: deserializeParam(
          data['last_page'],
          ParamType.int,
          false,
        ),
        total: deserializeParam(
          data['total'],
          ParamType.int,
          false,
        ),
        data: deserializeStructParam<Studio59GalleryPhotoStruct>(
          data['data'],
          ParamType.DataStruct,
          true,
          structBuilder: Studio59GalleryPhotoStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'Studio59GalleryFetchResultStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is Studio59GalleryFetchResultStruct &&
        success == other.success &&
        statusCode == other.statusCode &&
        message == other.message &&
        currentPage == other.currentPage &&
        lastPage == other.lastPage &&
        total == other.total &&
        listEquality.equals(data, other.data);
  }

  @override
  int get hashCode => const ListEquality().hash([
        success,
        statusCode,
        message,
        currentPage,
        lastPage,
        total,
        const ListEquality().hash(data)
      ]);
}

Studio59GalleryFetchResultStruct createStudio59GalleryFetchResultStruct({
  bool? success,
  int? statusCode,
  String? message,
  int? currentPage,
  int? lastPage,
  int? total,
}) =>
    Studio59GalleryFetchResultStruct(
      success: success,
      statusCode: statusCode,
      message: message,
      currentPage: currentPage,
      lastPage: lastPage,
      total: total,
    );
