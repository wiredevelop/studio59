// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59GalleryResponse
class Studio59GalleryResponseStruct extends BaseStruct {
  Studio59GalleryResponseStruct({
    /// Studio59GalleryResponse.current_page
    int? currentPage,

    /// Studio59GalleryResponse.last_page
    int? lastPage,

    /// Studio59GalleryResponse.total
    int? total,

    /// Studio59GalleryResponse.data
    List<Studio59GalleryPhotoStruct>? data,
  })  : _currentPage = currentPage,
        _lastPage = lastPage,
        _total = total,
        _data = data;

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

  static Studio59GalleryResponseStruct fromMap(Map<String, dynamic> data) =>
      Studio59GalleryResponseStruct(
        currentPage: castToType<int>(data['current_page']),
        lastPage: castToType<int>(data['last_page']),
        total: castToType<int>(data['total']),
        data: getStructList(
          data['data'],
          Studio59GalleryPhotoStruct.fromMap,
        ),
      );

  static Studio59GalleryResponseStruct? maybeFromMap(dynamic data) =>
      data is Map
          ? Studio59GalleryResponseStruct.fromMap(data.cast<String, dynamic>())
          : null;

  Map<String, dynamic> toMap() => {
        'current_page': _currentPage,
        'last_page': _lastPage,
        'total': _total,
        'data': _data?.map((e) => e.toMap()).toList(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
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

  static Studio59GalleryResponseStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59GalleryResponseStruct(
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
  String toString() => 'Studio59GalleryResponseStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is Studio59GalleryResponseStruct &&
        currentPage == other.currentPage &&
        lastPage == other.lastPage &&
        total == other.total &&
        listEquality.equals(data, other.data);
  }

  @override
  int get hashCode => const ListEquality()
      .hash([currentPage, lastPage, total, const ListEquality().hash(data)]);
}

Studio59GalleryResponseStruct createStudio59GalleryResponseStruct({
  int? currentPage,
  int? lastPage,
  int? total,
}) =>
    Studio59GalleryResponseStruct(
      currentPage: currentPage,
      lastPage: lastPage,
      total: total,
    );
