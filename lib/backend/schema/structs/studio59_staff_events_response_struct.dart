// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// DSL struct Studio59StaffEventsResponse
class Studio59StaffEventsResponseStruct extends BaseStruct {
  Studio59StaffEventsResponseStruct({
    /// Studio59StaffEventsResponse.current_page
    int? currentPage,

    /// Studio59StaffEventsResponse.last_page
    int? lastPage,

    /// Studio59StaffEventsResponse.data
    List<Studio59StaffEventStruct>? data,
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
  List<Studio59StaffEventStruct>? _data;
  List<Studio59StaffEventStruct> get data => _data ?? const [];
  set data(List<Studio59StaffEventStruct>? val) => _data = val;

  void updateData(Function(List<Studio59StaffEventStruct>) updateFn) {
    updateFn(_data ??= []);
  }

  bool hasData() => _data != null;

  static Studio59StaffEventsResponseStruct fromMap(Map<String, dynamic> data) =>
      Studio59StaffEventsResponseStruct(
        currentPage: castToType<int>(data['current_page']),
        lastPage: castToType<int>(data['last_page']),
        data: getStructList(
          data['data'],
          Studio59StaffEventStruct.fromMap,
        ),
      );

  static Studio59StaffEventsResponseStruct? maybeFromMap(dynamic data) => data
          is Map
      ? Studio59StaffEventsResponseStruct.fromMap(data.cast<String, dynamic>())
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

  static Studio59StaffEventsResponseStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      Studio59StaffEventsResponseStruct(
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
        data: deserializeStructParam<Studio59StaffEventStruct>(
          data['data'],
          ParamType.DataStruct,
          true,
          structBuilder: Studio59StaffEventStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'Studio59StaffEventsResponseStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is Studio59StaffEventsResponseStruct &&
        currentPage == other.currentPage &&
        lastPage == other.lastPage &&
        listEquality.equals(data, other.data);
  }

  @override
  int get hashCode => const ListEquality()
      .hash([currentPage, lastPage, const ListEquality().hash(data)]);
}

Studio59StaffEventsResponseStruct createStudio59StaffEventsResponseStruct({
  int? currentPage,
  int? lastPage,
}) =>
    Studio59StaffEventsResponseStruct(
      currentPage: currentPage,
      lastPage: lastPage,
    );
