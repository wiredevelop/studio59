// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59StaffOrdersResponse
class Studio59StaffOrdersResponseStruct extends BaseStruct {
  Studio59StaffOrdersResponseStruct({
    /// Studio59StaffOrdersResponse.current_page
    int? currentPage,

    /// Studio59StaffOrdersResponse.last_page
    int? lastPage,

    /// Studio59StaffOrdersResponse.data
    List<Studio59StaffOrderStruct>? data,
  })  : _currentPage = currentPage,
        _lastPage = lastPage,
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

  // "data" field.
  List<Studio59StaffOrderStruct>? _data;
  List<Studio59StaffOrderStruct> get data => _data ?? const [];
  set data(List<Studio59StaffOrderStruct>? val) => _data = val;

  void updateData(Function(List<Studio59StaffOrderStruct>) updateFn) {
    updateFn(_data ??= []);
  }

  bool hasData() => _data != null;

  static Studio59StaffOrdersResponseStruct fromMap(Map<String, dynamic> data) =>
      Studio59StaffOrdersResponseStruct(
        currentPage: castToType<int>(data['current_page']),
        lastPage: castToType<int>(data['last_page']),
        data: getStructList(
          data['data'],
          Studio59StaffOrderStruct.fromMap,
        ),
      );

  static Studio59StaffOrdersResponseStruct? maybeFromMap(dynamic data) => data
          is Map
      ? Studio59StaffOrdersResponseStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'current_page': _currentPage,
        'last_page': _lastPage,
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
        'data': serializeParam(
          _data,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static Studio59StaffOrdersResponseStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59StaffOrdersResponseStruct(
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
        data: deserializeStructParam<Studio59StaffOrderStruct>(
          data['data'],
          ParamType.DataStruct,
          true,
          structBuilder: Studio59StaffOrderStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'Studio59StaffOrdersResponseStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is Studio59StaffOrdersResponseStruct &&
        currentPage == other.currentPage &&
        lastPage == other.lastPage &&
        listEquality.equals(data, other.data);
  }

  @override
  int get hashCode => const ListEquality()
      .hash([currentPage, lastPage, const ListEquality().hash(data)]);
}

Studio59StaffOrdersResponseStruct createStudio59StaffOrdersResponseStruct({
  int? currentPage,
  int? lastPage,
}) =>
    Studio59StaffOrdersResponseStruct(
      currentPage: currentPage,
      lastPage: lastPage,
    );
