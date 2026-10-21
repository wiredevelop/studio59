import 'dart:convert';
import 'dart:typed_data';
import '../schema/structs/index.dart';

import 'package:flutter/foundation.dart';

import '/flutter_flow/flutter_flow_util.dart';
import 'api_manager.dart';

export 'api_manager.dart' show ApiCallResponse;

const _kPrivateApiFunctionName = 'ffPrivateApiCall';

/// Start Studio59API Group Code

class Studio59APIGroup {
  static String getBaseUrl() => 'https://studio59.wiredevelop.pt/api';
  static Map<String, String> headers = {
    'Accept': 'application/json',
  };
  static Studio59StaffLoginCall studio59StaffLoginCall =
      Studio59StaffLoginCall();
  static Studio59StaffMeCall studio59StaffMeCall = Studio59StaffMeCall();
  static Studio59StaffLogoutCall studio59StaffLogoutCall =
      Studio59StaffLogoutCall();
  static Studio59EnterByPinCall studio59EnterByPinCall =
      Studio59EnterByPinCall();
  static Studio59EnterEventCall studio59EnterEventCall =
      Studio59EnterEventCall();
  static Studio59EventGalleryCall studio59EventGalleryCall =
      Studio59EventGalleryCall();
  static Studio59CreateCashOrderCall studio59CreateCashOrderCall =
      Studio59CreateCashOrderCall();
  static Studio59EventOrdersCall studio59EventOrdersCall =
      Studio59EventOrdersCall();
  static Studio59OrderDetailsCall studio59OrderDetailsCall =
      Studio59OrderDetailsCall();
  static Studio59MarkOrderPaidCall studio59MarkOrderPaidCall =
      Studio59MarkOrderPaidCall();
  static Studio59ChunkUploadCall studio59ChunkUploadCall =
      Studio59ChunkUploadCall();
  static Studio59UploadStatusCall studio59UploadStatusCall =
      Studio59UploadStatusCall();
}

class Studio59StaffLoginCall {
  Future<ApiCallResponse> call({
    String? email = '',
    String? password = '',
  }) async {
    final baseUrl = Studio59APIGroup.getBaseUrl();

    final ffApiRequestBody = '''
{"email":${email == null ? 'null' : '"${email}"'},"password":${password == null ? 'null' : '"${password}"'}}''';
    return ApiManager.instance.makeApiCall(
      callName: 'Studio59StaffLogin',
      apiUrl: '${baseUrl}/auth/login',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59StaffMeCall {
  Future<ApiCallResponse> call({
    String? token = '',
  }) async {
    final baseUrl = Studio59APIGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: 'Studio59StaffMe',
      apiUrl: '${baseUrl}/auth/me',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer <token>',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59StaffLogoutCall {
  Future<ApiCallResponse> call({
    String? token = '',
  }) async {
    final baseUrl = Studio59APIGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: 'Studio59StaffLogout',
      apiUrl: '${baseUrl}/auth/logout',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer <token>',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59EnterByPinCall {
  Future<ApiCallResponse> call({
    String? pin = '',
  }) async {
    final baseUrl = Studio59APIGroup.getBaseUrl();

    final ffApiRequestBody = '''
{"pin":${pin == null ? 'null' : '"${pin}"'}}''';
    return ApiManager.instance.makeApiCall(
      callName: 'Studio59EnterByPin',
      apiUrl: '${baseUrl}/public/events/pin',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59EnterEventCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = Studio59APIGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: 'Studio59EnterEvent',
      apiUrl: '${baseUrl}/public/events/${id}/enter',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59EventGalleryCall {
  Future<ApiCallResponse> call({
    int? id,
    String? token = '',
    int? page,
    int? perPage,
  }) async {
    final baseUrl = Studio59APIGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: 'Studio59EventGallery',
      apiUrl: '${baseUrl}/public/events/${id}/photos',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer <token>',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59CreateCashOrderCall {
  Future<ApiCallResponse> call({
    String? token = '',
    String? customerName = '',
    String? customerPhone = '',
    String? customerEmail = '',
    String? productType = '',
    bool? wantsFilm,
    String? photoItems = '',
  }) async {
    final baseUrl = Studio59APIGroup.getBaseUrl();

    final ffApiRequestBody = '''
{"customer_name":${customerName == null ? 'null' : '"${customerName}"'},"customer_phone":${customerPhone == null ? 'null' : '"${customerPhone}"'},"customer_email":${customerEmail == null ? 'null' : '"${customerEmail}"'},"payment_method":"cash","product_type":${productType == null ? 'null' : '"${productType}"'},"wants_film":${wantsFilm},"photo_items":${photoItems == null ? 'null' : '"${photoItems}"'}}''';
    return ApiManager.instance.makeApiCall(
      callName: 'Studio59CreateCashOrder',
      apiUrl: '${baseUrl}/public/orders',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer <token>',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59EventOrdersCall {
  Future<ApiCallResponse> call({
    int? event,
    String? token = '',
  }) async {
    final baseUrl = Studio59APIGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: 'Studio59EventOrders',
      apiUrl: '${baseUrl}/events/${event}/orders',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer <token>',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59OrderDetailsCall {
  Future<ApiCallResponse> call({
    int? order,
    String? token = '',
  }) async {
    final baseUrl = Studio59APIGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: 'Studio59OrderDetails',
      apiUrl: '${baseUrl}/orders/${order}',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer <token>',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59MarkOrderPaidCall {
  Future<ApiCallResponse> call({
    int? order,
    String? token = '',
  }) async {
    final baseUrl = Studio59APIGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: 'Studio59MarkOrderPaid',
      apiUrl: '${baseUrl}/orders/${order}/mark-paid',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer <token>',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59ChunkUploadCall {
  Future<ApiCallResponse> call({
    int? event,
    String? token = '',
  }) async {
    final baseUrl = Studio59APIGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: 'Studio59ChunkUpload',
      apiUrl: '${baseUrl}/events/${event}/uploads/chunk',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer <token>',
      },
      params: {},
      bodyType: BodyType.MULTIPART,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59UploadStatusCall {
  Future<ApiCallResponse> call({
    int? event,
    String? token = '',
    String? uploadId = '',
  }) async {
    final baseUrl = Studio59APIGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: 'Studio59UploadStatus',
      apiUrl: '${baseUrl}/events/${event}/uploads/status',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer <token>',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// End Studio59API Group Code

/// Start Studio59Web Group Code

class Studio59WebGroup {
  static String getBaseUrl() => 'https://studio59.wiredevelop.pt';
  static Map<String, String> headers = {};
  static Studio59WebOriginCall studio59WebOriginCall = Studio59WebOriginCall();
}

class Studio59WebOriginCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = Studio59WebGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: 'Studio59WebOrigin',
      apiUrl: '${baseUrl}/',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// End Studio59Web Group Code

class Studio59EventGalleryPagedCall {
  static Future<ApiCallResponse> call({
    int? id,
    String? token = '',
    int? page,
    int? perPage,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'Studio59EventGalleryPaged',
      apiUrl:
          'https://studio59.wiredevelop.pt/api/public/events/${id}/photos?page=${page}&per_page=${perPage}',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer <token>',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59EnterByPinTypedCall {
  static Future<ApiCallResponse> call({
    String? pin = '',
  }) async {
    final ffApiRequestBody = '''
{"pin":${pin == null ? 'null' : '"${pin}"'}}''';
    return ApiManager.instance.makeApiCall(
      callName: 'Studio59EnterByPinTyped',
      apiUrl: 'https://studio59.wiredevelop.pt/api/public/events/pin',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59CreateCashOrderOnlineCall {
  static Future<ApiCallResponse> call({
    int? eventId,
    String? token = '',
    String? customerName = '',
    String? customerPhone = '',
    String? customerEmail = '',
    String? productType = '',
    dynamic? photoItemsJson,
    bool? wantsFilm,
  }) async {
    final photoItems = _serializeJson(photoItemsJson);
    final ffApiRequestBody = '''
{"event_id":${eventId},"customer_name":${customerName == null ? 'null' : '"${customerName}"'},"customer_phone":${customerPhone == null ? 'null' : '"${customerPhone}"'},"customer_email":${customerEmail == null ? 'null' : '"${customerEmail}"'},"payment_method":"cash","product_type":${productType == null ? 'null' : '"${productType}"'},"photo_items":${photoItems},"wants_film":${wantsFilm}}''';
    return ApiManager.instance.makeApiCall(
      callName: 'Studio59CreateCashOrderOnline',
      apiUrl: 'https://studio59.wiredevelop.pt/api/public/orders',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer <token>',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59AssignedStaffEventsCall {
  static Future<ApiCallResponse> call({
    String? token = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'Studio59AssignedStaffEvents',
      apiUrl: 'https://studio59.wiredevelop.pt/api/events',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer <token>',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59StaffLoginTypedCall {
  static Future<ApiCallResponse> call({
    String? email = '',
    String? password = '',
  }) async {
    final ffApiRequestBody = '''
{"email":${email == null ? 'null' : '"${email}"'},"password":${password == null ? 'null' : '"${password}"'}}''';
    return ApiManager.instance.makeApiCall(
      callName: 'Studio59StaffLoginTyped',
      apiUrl: 'https://studio59.wiredevelop.pt/api/auth/login',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59StaffMeTypedCall {
  static Future<ApiCallResponse> call({
    String? token = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'Studio59StaffMeTyped',
      apiUrl: 'https://studio59.wiredevelop.pt/api/auth/me',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer <token>',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59StaffLogoutTypedCall {
  static Future<ApiCallResponse> call({
    String? token = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'Studio59StaffLogoutTyped',
      apiUrl: 'https://studio59.wiredevelop.pt/api/auth/logout',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer <token>',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59EventOrdersTypedCall {
  static Future<ApiCallResponse> call({
    int? event,
    String? token = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'Studio59EventOrdersTyped',
      apiUrl: 'https://studio59.wiredevelop.pt/api/events/${event}/orders',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer <token>',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59OrderDetailsTypedCall {
  static Future<ApiCallResponse> call({
    int? order,
    String? token = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'Studio59OrderDetailsTyped',
      apiUrl: 'https://studio59.wiredevelop.pt/api/orders/${order}',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer <token>',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59OrderDetailsRawCall {
  static Future<ApiCallResponse> call({
    int? order,
    String? token = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'Studio59OrderDetailsRaw',
      apiUrl: 'https://studio59.wiredevelop.pt/api/orders/${order}',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer <token>',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59PublicOrderByCodeCall {
  static Future<ApiCallResponse> call({
    String? orderCode = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'Studio59PublicOrderByCode',
      apiUrl: 'https://studio59.wiredevelop.pt/api/public/orders/${orderCode}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class Studio59EnterByQrTypedCall {
  static Future<ApiCallResponse> call({
    String? token = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'Studio59EnterByQrTyped',
      apiUrl: 'https://studio59.wiredevelop.pt/api/public/events/qr/${token}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ApiPagingParams {
  int nextPageNumber = 0;
  int numItems = 0;
  dynamic lastResponse;

  ApiPagingParams({
    required this.nextPageNumber,
    required this.numItems,
    required this.lastResponse,
  });

  @override
  String toString() =>
      'PagingParams(nextPageNumber: $nextPageNumber, numItems: $numItems, lastResponse: $lastResponse,)';
}

String _toEncodable(dynamic item) {
  return item;
}

String _serializeList(List? list) {
  list ??= <String>[];
  try {
    return json.encode(list, toEncodable: _toEncodable);
  } catch (_) {
    if (kDebugMode) {
      print("List serialization failed. Returning empty list.");
    }
    return '[]';
  }
}

String _serializeJson(dynamic jsonVar, [bool isList = false]) {
  jsonVar ??= (isList ? [] : {});
  try {
    return json.encode(jsonVar, toEncodable: _toEncodable);
  } catch (_) {
    if (kDebugMode) {
      print("Json serialization failed. Returning empty json.");
    }
    return isList ? '[]' : '{}';
  }
}
