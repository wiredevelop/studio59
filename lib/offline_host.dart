import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

const String kOfflineHostSessionFileName = 'studio59_offline_host_session.json';
const String kOfflineOrdersFileName = 'studio59_offline_orders.json';
const String kOfflineAccessFileName = 'studio59_offline_access.json';
const int kOfflineDiscoveryPort = 40059;
const String kOfflineDiscoveryType = 'studio59_offline_discovery';
const String kOfflineDiscoveryResponseType =
    'studio59_offline_discovery_response';

Uint8List? _generateThumbnailBytes(Uint8List srcBytes) {
  final decoded = img.decodeImage(srcBytes);
  if (decoded == null) return null;
  const maxWidth = 400;
  final resized = decoded.width > maxWidth
      ? img.copyResize(
          decoded,
          width: maxWidth,
          interpolation: img.Interpolation.linear,
        )
      : decoded;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
}

bool looksLikeLocalApiBaseUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  if (host == 'localhost' || host == '127.0.0.1') return true;
  if (host.startsWith('10.')) return true;
  if (host.startsWith('192.168.')) return true;
  if (host.startsWith('172.16.') ||
      host.startsWith('172.17.') ||
      host.startsWith('172.18.') ||
      host.startsWith('172.19.') ||
      host.startsWith('172.20.') ||
      host.startsWith('172.21.') ||
      host.startsWith('172.22.') ||
      host.startsWith('172.23.') ||
      host.startsWith('172.24.') ||
      host.startsWith('172.25.') ||
      host.startsWith('172.26.') ||
      host.startsWith('172.27.') ||
      host.startsWith('172.28.') ||
      host.startsWith('172.29.') ||
      host.startsWith('172.30.') ||
      host.startsWith('172.31.')) {
    return true;
  }
  return false;
}

String _pathJoin(String dir, String leaf) {
  final sep = Platform.pathSeparator;
  if (dir.endsWith(sep)) return '$dir$leaf';
  return '$dir$sep$leaf';
}

String _basenameWithoutExtension(String path) {
  final normalized = path.replaceAll('\\', '/');
  final file = normalized.split('/').last;
  final idx = file.lastIndexOf('.');
  if (idx <= 0) return file;
  return file.substring(0, idx);
}

String _mimeTypeForPath(String path) {
  final ext = path.toLowerCase();
  if (ext.endsWith('.png')) return 'image/png';
  if (ext.endsWith('.webp')) return 'image/webp';
  if (ext.endsWith('.gif')) return 'image/gif';
  if (ext.endsWith('.heic')) return 'image/heic';
  if (ext.endsWith('.heif')) return 'image/heif';
  return 'image/jpeg';
}

String? _multipartHeaderValue(String? header, String key) {
  if (header == null || header.trim().isEmpty) return null;
  final quoted = RegExp('$key="([^"]*)"').firstMatch(header);
  if (quoted != null) return quoted.group(1)?.trim();
  final plain = RegExp('$key=([^;]+)').firstMatch(header);
  return plain?.group(1)?.trim().replaceAll('"', '');
}

String _imageExtensionForName(String? filename) {
  final value = (filename ?? '').trim().toLowerCase();
  if (value.endsWith('.png')) return '.png';
  if (value.endsWith('.webp')) return '.webp';
  if (value.endsWith('.gif')) return '.gif';
  if (value.endsWith('.heic')) return '.heic';
  if (value.endsWith('.heif')) return '.heif';
  return '.jpg';
}

String generateOfflinePassword() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
  final rnd = Random.secure();
  return List.generate(10, (_) => chars[rnd.nextInt(chars.length)]).join();
}

String generateOfflineUsername(String eventName) {
  final base = eventName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '.')
      .replaceAll(RegExp(r'\.+'), '.')
      .replaceAll(RegExp(r'^\.|\.$'), '');
  final suffix = Random.secure().nextInt(9000) + 1000;
  if (base.isEmpty) return 'offline.$suffix';
  return '${base.substring(0, min(base.length, 16))}.$suffix';
}

String generateOfflineToken() {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rnd = Random.secure();
  return List.generate(48, (_) => chars[rnd.nextInt(chars.length)]).join();
}

String generateOfflineOrderCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rnd = Random.secure();
  return 'S59-${List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join()}';
}

class OfflineDiscoveryResult {
  const OfflineDiscoveryResult({
    required this.serverUrl,
    required this.eventName,
    required this.sessionId,
    required this.qrUrl,
    required this.host,
    required this.port,
    required this.candidateUrls,
  });

  final String serverUrl;
  final String eventName;
  final String sessionId;
  final String qrUrl;
  final String host;
  final int port;
  final List<String> candidateUrls;

  OfflineDiscoveryResult copyWith({
    String? serverUrl,
    String? eventName,
    String? sessionId,
    String? qrUrl,
    String? host,
    int? port,
    List<String>? candidateUrls,
  }) => OfflineDiscoveryResult(
    serverUrl: serverUrl ?? this.serverUrl,
    eventName: eventName ?? this.eventName,
    sessionId: sessionId ?? this.sessionId,
    qrUrl: qrUrl ?? this.qrUrl,
    host: host ?? this.host,
    port: port ?? this.port,
    candidateUrls: candidateUrls ?? this.candidateUrls,
  );

  factory OfflineDiscoveryResult.fromJson(Map<String, dynamic> json) =>
      OfflineDiscoveryResult(
        serverUrl: json['server_url']?.toString() ?? '',
        eventName: json['event_name']?.toString() ?? '',
        sessionId: json['session_id']?.toString() ?? '',
        qrUrl: json['qr_url']?.toString() ?? '',
        host: json['host']?.toString() ?? '',
        port: (json['port'] as num?)?.toInt() ?? 4000,
        candidateUrls: ((json['candidate_urls'] as List?) ?? const [])
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(),
      );
}

class OfflineHostPhoto {
  const OfflineHostPhoto({
    required this.id,
    required this.number,
    required this.path,
  });

  final int id;
  final String number;
  final String path;

  Map<String, dynamic> toJson() => {'id': id, 'number': number, 'path': path};

  factory OfflineHostPhoto.fromJson(Map<String, dynamic> json) =>
      OfflineHostPhoto(
        id: (json['id'] as num?)?.toInt() ?? 0,
        number: json['number']?.toString() ?? '',
        path: json['path']?.toString() ?? '',
      );
}

class OfflineHostOrderItem {
  const OfflineHostOrderItem({
    required this.photoId,
    required this.photoNumber,
    required this.quantity,
    required this.price,
  });

  final int photoId;
  final String photoNumber;
  final int quantity;
  final num price;

  Map<String, dynamic> toJson() => {
    'photo_id': photoId,
    'photo_number': photoNumber,
    'quantity': quantity,
    'price': price,
  };

  factory OfflineHostOrderItem.fromJson(Map<String, dynamic> json) =>
      OfflineHostOrderItem(
        photoId: (json['photo_id'] as num?)?.toInt() ?? 0,
        photoNumber: json['photo_number']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        price: json['price'] is num
            ? json['price'] as num
            : num.tryParse(json['price']?.toString() ?? '') ?? 0,
      );
}

class OfflineHostOrder {
  const OfflineHostOrder({
    required this.id,
    required this.orderCode,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.productType,
    required this.deliveryType,
    required this.deliveryAddress,
    required this.wantsFilm,
    required this.filmFee,
    required this.shippingFee,
    required this.extrasTotal,
    required this.itemsTotal,
    required this.paymentMethod,
    required this.cashReceivedAmount,
    required this.cashChangeAmount,
    required this.cashDueAmount,
    required this.status,
    required this.totalAmount,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String orderCode;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String productType;
  final String? deliveryType;
  final String deliveryAddress;
  final bool wantsFilm;
  final num filmFee;
  final num shippingFee;
  final num extrasTotal;
  final num itemsTotal;
  final String paymentMethod;
  final num? cashReceivedAmount;
  final num? cashChangeAmount;
  final num? cashDueAmount;
  final String status;
  final num totalAmount;
  final List<OfflineHostOrderItem> items;
  final String createdAt;
  final String updatedAt;

  OfflineHostOrder copyWith({
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? paymentMethod,
    num? cashReceivedAmount,
    num? cashChangeAmount,
    num? cashDueAmount,
    String? status,
    String? updatedAt,
  }) => OfflineHostOrder(
    id: id,
    orderCode: orderCode,
    customerName: customerName ?? this.customerName,
    customerPhone: customerPhone ?? this.customerPhone,
    customerEmail: customerEmail ?? this.customerEmail,
    productType: productType,
    deliveryType: deliveryType,
    deliveryAddress: deliveryAddress,
    wantsFilm: wantsFilm,
    filmFee: filmFee,
    shippingFee: shippingFee,
    extrasTotal: extrasTotal,
    itemsTotal: itemsTotal,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    cashReceivedAmount: cashReceivedAmount ?? this.cashReceivedAmount,
    cashChangeAmount: cashChangeAmount ?? this.cashChangeAmount,
    cashDueAmount: cashDueAmount ?? this.cashDueAmount,
    status: status ?? this.status,
    totalAmount: totalAmount,
    items: items,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_code': orderCode,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'customer_email': customerEmail,
    'product_type': productType,
    'delivery_type': deliveryType,
    'delivery_address': deliveryAddress,
    'wants_film': wantsFilm,
    'film_fee': filmFee,
    'shipping_fee': shippingFee,
    'extras_total': extrasTotal,
    'items_total': itemsTotal,
    'payment_method': paymentMethod,
    'cash_received_amount': cashReceivedAmount,
    'cash_change_amount': cashChangeAmount,
    'cash_due_amount': cashDueAmount,
    'status': status,
    'total_amount': totalAmount,
    'items': items.map((e) => e.toJson()).toList(),
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  Map<String, dynamic> toOrderDetailJson() => {
    'order_code': orderCode,
    'status': status,
    'total_amount': totalAmount,
    'items_total': itemsTotal,
    'extras_total': extrasTotal,
    'shipping_fee': shippingFee,
    'film_fee': filmFee,
    'product_type': productType,
    'delivery_type': deliveryType,
    'delivery_address': deliveryAddress,
    'wants_film': wantsFilm,
    'payment_method': paymentMethod,
    'cash_received_amount': cashReceivedAmount,
    'cash_change_amount': cashChangeAmount,
    'cash_due_amount': cashDueAmount,
    'customer_name': customerName,
    'customer_email': customerEmail,
    'customer_phone': customerPhone,
    'offline_mode': true,
    'photos': items
        .map(
          (item) => {
            'id': item.photoId,
            'number': item.photoNumber,
            'quantity': item.quantity,
          },
        )
        .toList(),
  };

  Map<String, dynamic> toStaffListJson(Map<String, dynamic> event) => {
    'id': id,
    'order_code': orderCode,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'customer_email': customerEmail,
    'payment_method': paymentMethod,
    'cash_received_amount': cashReceivedAmount,
    'cash_change_amount': cashChangeAmount,
    'cash_due_amount': cashDueAmount,
    'status': status,
    'total_amount': totalAmount,
    'event': event,
  };

  factory OfflineHostOrder.fromJson(Map<String, dynamic> json) =>
      OfflineHostOrder(
        id: (json['id'] as num?)?.toInt() ?? 0,
        orderCode: json['order_code']?.toString() ?? '',
        customerName: json['customer_name']?.toString() ?? '',
        customerPhone: json['customer_phone']?.toString() ?? '',
        customerEmail: json['customer_email']?.toString() ?? '',
        productType: json['product_type']?.toString() ?? 'digital',
        deliveryType: json['delivery_type']?.toString(),
        deliveryAddress: json['delivery_address']?.toString() ?? '',
        wantsFilm: json['wants_film'] == true || json['wants_film'] == 1,
        filmFee: json['film_fee'] is num
            ? json['film_fee'] as num
            : num.tryParse(json['film_fee']?.toString() ?? '') ?? 0,
        shippingFee: json['shipping_fee'] is num
            ? json['shipping_fee'] as num
            : num.tryParse(json['shipping_fee']?.toString() ?? '') ?? 0,
        extrasTotal: json['extras_total'] is num
            ? json['extras_total'] as num
            : num.tryParse(json['extras_total']?.toString() ?? '') ?? 0,
        itemsTotal: json['items_total'] is num
            ? json['items_total'] as num
            : num.tryParse(json['items_total']?.toString() ?? '') ?? 0,
        paymentMethod: json['payment_method']?.toString() ?? 'cash',
        cashReceivedAmount: json['cash_received_amount'] == null
            ? null
            : (json['cash_received_amount'] is num
                  ? json['cash_received_amount'] as num
                  : num.tryParse(
                      json['cash_received_amount']?.toString() ?? '',
                    )),
        cashChangeAmount: json['cash_change_amount'] == null
            ? null
            : (json['cash_change_amount'] is num
                  ? json['cash_change_amount'] as num
                  : num.tryParse(json['cash_change_amount']?.toString() ?? '')),
        cashDueAmount: json['cash_due_amount'] == null
            ? null
            : (json['cash_due_amount'] is num
                  ? json['cash_due_amount'] as num
                  : num.tryParse(json['cash_due_amount']?.toString() ?? '')),
        status: json['status']?.toString() ?? 'pending',
        totalAmount: json['total_amount'] is num
            ? json['total_amount'] as num
            : num.tryParse(json['total_amount']?.toString() ?? '') ?? 0,
        items: ((json['items'] as List?) ?? const [])
            .map(
              (item) => OfflineHostOrderItem.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        createdAt:
            json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        updatedAt:
            json['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      );
}

class OfflineHostSession {
  const OfflineHostSession({
    required this.isActive,
    required this.sessionId,
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    required this.eventType,
    required this.location,
    required this.pricePerPhoto,
    required this.basePrice,
    required this.accessPin,
    required this.qrToken,
    required this.guestToken,
    required this.photoDir,
    required this.photos,
    required this.orders,
    required this.eventMeta,
    required this.staffUsername,
    required this.staffPassword,
    required this.staffToken,
    required this.staffName,
    required this.staffUserId,
    required this.port,
    required this.serverHost,
    required this.createdAt,
    required this.updatedAt,
  });

  final bool isActive;
  final String sessionId;
  final int eventId;
  final String eventName;
  final String eventDate;
  final String eventType;
  final String location;
  final num pricePerPhoto;
  final num basePrice;
  final String accessPin;
  final String qrToken;
  final String guestToken;
  final String photoDir;
  final List<OfflineHostPhoto> photos;
  final List<OfflineHostOrder> orders;
  final Map<String, dynamic> eventMeta;
  final String staffUsername;
  final String staffPassword;
  final String staffToken;
  final String staffName;
  final int staffUserId;
  final int port;
  final String serverHost;
  final String createdAt;
  final String updatedAt;

  String get localApiBaseUrl => 'http://127.0.0.1:$port/api';
  String get lanApiBaseUrl => 'http://$serverHost:$port/api';
  String get publicQrUrl =>
      'http://$serverHost:$port/api/public/events/qr/$qrToken';
  String get ordersFilePath => _pathJoin(photoDir, kOfflineOrdersFileName);
  String get accessFilePath => _pathJoin(photoDir, kOfflineAccessFileName);

  OfflineHostSession copyWith({
    bool? isActive,
    List<OfflineHostPhoto>? photos,
    List<OfflineHostOrder>? orders,
    Map<String, dynamic>? eventMeta,
    int? port,
    String? serverHost,
    String? updatedAt,
  }) => OfflineHostSession(
    isActive: isActive ?? this.isActive,
    sessionId: sessionId,
    eventId: eventId,
    eventName: eventName,
    eventDate: eventDate,
    eventType: eventType,
    location: location,
    pricePerPhoto: pricePerPhoto,
    basePrice: basePrice,
    accessPin: accessPin,
    qrToken: qrToken,
    guestToken: guestToken,
    photoDir: photoDir,
    photos: photos ?? this.photos,
    orders: orders ?? this.orders,
    eventMeta: eventMeta ?? this.eventMeta,
    staffUsername: staffUsername,
    staffPassword: staffPassword,
    staffToken: staffToken,
    staffName: staffName,
    staffUserId: staffUserId,
    port: port ?? this.port,
    serverHost: serverHost ?? this.serverHost,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'is_active': isActive,
    'session_id': sessionId,
    'event_id': eventId,
    'event_name': eventName,
    'event_date': eventDate,
    'event_type': eventType,
    'location': location,
    'price_per_photo': pricePerPhoto,
    'base_price': basePrice,
    'access_pin': accessPin,
    'qr_token': qrToken,
    'guest_token': guestToken,
    'photo_dir': photoDir,
    'photos': photos.map((e) => e.toJson()).toList(),
    'orders': orders.map((e) => e.toJson()).toList(),
    'event_meta': eventMeta,
    'staff_username': staffUsername,
    'staff_password': staffPassword,
    'staff_token': staffToken,
    'staff_name': staffName,
    'staff_user_id': staffUserId,
    'port': port,
    'server_host': serverHost,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  Map<String, dynamic> buildExportPayload() => {
    'session_id': sessionId,
    'event': {
      'id': eventId,
      'name': eventName,
      'event_date': eventDate,
      'event_type': eventType,
      'location': location,
      'price_per_photo': pricePerPhoto,
      'base_price': basePrice,
      'qr_token': qrToken,
      'access_pin': accessPin,
      'event_meta': eventMeta,
    },
    'orders': orders.map((e) => e.toJson()).toList(),
    'photos': photos
        .map(
          (photo) => {
            'id': photo.id,
            'number': photo.number,
            'original_path': photo.path,
            'preview_path': photo.path,
            'status': 'active',
          },
        )
        .toList(),
    'selections': const <Map<String, dynamic>>[],
    'exported_at': DateTime.now().toIso8601String(),
  };

  factory OfflineHostSession.fromJson(
    Map<String, dynamic> json,
  ) => OfflineHostSession(
    isActive: json['is_active'] == true,
    sessionId: json['session_id']?.toString() ?? '',
    eventId: (json['event_id'] as num?)?.toInt() ?? 0,
    eventName: json['event_name']?.toString() ?? '',
    eventDate: json['event_date']?.toString() ?? '',
    eventType: json['event_type']?.toString() ?? '',
    location: json['location']?.toString() ?? '',
    pricePerPhoto: json['price_per_photo'] is num
        ? json['price_per_photo'] as num
        : num.tryParse(json['price_per_photo']?.toString() ?? '') ?? 0,
    basePrice: json['base_price'] is num
        ? json['base_price'] as num
        : num.tryParse(json['base_price']?.toString() ?? '') ?? 0,
    accessPin: json['access_pin']?.toString() ?? '',
    qrToken: json['qr_token']?.toString() ?? '',
    guestToken: json['guest_token']?.toString() ?? '',
    photoDir: json['photo_dir']?.toString() ?? '',
    photos: ((json['photos'] as List?) ?? const [])
        .map(
          (item) =>
              OfflineHostPhoto.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    orders: ((json['orders'] as List?) ?? const [])
        .map(
          (item) =>
              OfflineHostOrder.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    eventMeta: json['event_meta'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['event_meta'] as Map<String, dynamic>)
        : (json['event_meta'] is Map
              ? Map<String, dynamic>.from(json['event_meta'] as Map)
              : <String, dynamic>{}),
    staffUsername: json['staff_username']?.toString() ?? '',
    staffPassword: json['staff_password']?.toString() ?? '',
    staffToken: json['staff_token']?.toString() ?? '',
    staffName: json['staff_name']?.toString() ?? 'Offline',
    staffUserId: (json['staff_user_id'] as num?)?.toInt() ?? 1,
    port: (json['port'] as num?)?.toInt() ?? 4000,
    serverHost: json['server_host']?.toString() ?? '127.0.0.1',
    createdAt:
        json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    updatedAt:
        json['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
  );
}

Future<File> _offlineHostSessionFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File(_pathJoin(dir.path, kOfflineHostSessionFileName));
}

Future<OfflineHostSession?> readOfflineHostSession() async {
  final file = await _offlineHostSessionFile();
  if (!await file.exists()) return null;
  final raw = await file.readAsString();
  if (raw.trim().isEmpty) return null;
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) {
    return OfflineHostSession.fromJson(decoded);
  }
  if (decoded is Map) {
    return OfflineHostSession.fromJson(Map<String, dynamic>.from(decoded));
  }
  return null;
}

Future<void> saveOfflineHostSession(OfflineHostSession session) async {
  final file = await _offlineHostSessionFile();
  await file.writeAsString(jsonEncode(session.toJson()));
}

Future<void> clearOfflineHostSession() async {
  final file = await _offlineHostSessionFile();
  if (await file.exists()) {
    await file.delete();
  }
}

Future<List<OfflineHostPhoto>> scanOfflinePhotos(String directoryPath) async {
  final dir = Directory(directoryPath);
  if (!await dir.exists()) return const <OfflineHostPhoto>[];
  final files = <File>[];
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final lower = entity.path.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif')) {
      files.add(entity);
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return [
    for (var i = 0; i < files.length; i++)
      OfflineHostPhoto(
        id: i + 1,
        number: _basenameWithoutExtension(files[i].path),
        path: files[i].path,
      ),
  ];
}

Future<OfflineDiscoveryResult?> discoverOfflineSession({
  Duration timeout = const Duration(seconds: 3),
}) async {
  RawDatagramSocket? socket;
  try {
    socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: true,
      reusePort: true,
    );
    socket.broadcastEnabled = true;
    final completer = Completer<OfflineDiscoveryResult?>();
    late final StreamSubscription<RawSocketEvent> sub;
    sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket?.receive();
      if (datagram == null) return;
      final text = utf8.decode(datagram.data, allowMalformed: true).trim();
      if (text.isEmpty) return;
      try {
        final decoded = jsonDecode(text);
        if (decoded is! Map) return;
        final map = Map<String, dynamic>.from(decoded);
        if (map['type']?.toString() != kOfflineDiscoveryResponseType) return;
        if (!completer.isCompleted) {
          completer.complete(OfflineDiscoveryResult.fromJson(map));
        }
      } catch (_) {}
    });
    final payload = utf8.encode(
      jsonEncode({
        'type': kOfflineDiscoveryType,
        'ts': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    final targets = <InternetAddress>{InternetAddress('255.255.255.255')};
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final address in iface.addresses) {
          final parts = address.address.split('.');
          if (parts.length == 4) {
            targets.add(
              InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'),
            );
          }
        }
      }
    } catch (_) {}
    for (final target in targets) {
      socket.send(payload, target, kOfflineDiscoveryPort);
    }
    final result = await completer.future.timeout(
      timeout,
      onTimeout: () => null,
    );
    await sub.cancel();
    socket.close();
    if (result == null) return null;
    return _resolveReachableDiscoveryResult(result);
  } catch (_) {
    socket?.close();
    return null;
  }
}

Future<OfflineDiscoveryResult> _resolveReachableDiscoveryResult(
  OfflineDiscoveryResult result,
) async {
  final candidates = <String>{
    if (result.serverUrl.trim().isNotEmpty) result.serverUrl.trim(),
    ...result.candidateUrls
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty),
    if (result.host.trim().isNotEmpty)
      'http://${result.host.trim()}:${result.port}/api',
  }.toList();
  for (final candidate in candidates) {
    if (await _canReachOfflineApi(candidate)) {
      return result.copyWith(serverUrl: candidate, candidateUrls: candidates);
    }
  }
  return result.copyWith(
    serverUrl: candidates.isNotEmpty ? candidates.first : result.serverUrl,
    candidateUrls: candidates,
  );
}

Future<bool> _canReachOfflineApi(String apiBaseUrl) async {
  HttpClient? client;
  try {
    client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2)
      ..idleTimeout = const Duration(seconds: 2)
      ..findProxy = (_) => 'DIRECT';
    final uri = Uri.parse('$apiBaseUrl/public/events/today');
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 2));
    final response = await request.close().timeout(const Duration(seconds: 2));
    await response.drain<void>();
    return response.statusCode >= 200 && response.statusCode < 500;
  } catch (_) {
    return false;
  } finally {
    client?.close(force: true);
  }
}

String _publicQrUrlForApiBaseUrl(String apiBaseUrl, String qrToken) {
  final uri = Uri.tryParse(apiBaseUrl.trim());
  if (uri == null) return '';
  return uri
      .replace(
        path: '${uri.path}/public/events/qr/$qrToken',
        query: null,
        fragment: null,
      )
      .toString();
}

class OfflineHostStartResult {
  const OfflineHostStartResult({
    required this.session,
    required this.localApiBaseUrl,
    required this.lanApiBaseUrl,
  });

  final OfflineHostSession session;
  final String localApiBaseUrl;
  final String lanApiBaseUrl;
}

class _OfflinePythonCommand {
  const _OfflinePythonCommand(this.command, [this.prefixArgs = const []]);

  final String command;
  final List<String> prefixArgs;
}

class OfflineHostServer {
  OfflineHostServer._();

  static final OfflineHostServer instance = OfflineHostServer._();

  HttpServer? _server;
  RawDatagramSocket? _discoverySocket;
  OfflineHostSession? _session;
  bool get isRunning => _server != null;
  OfflineHostSession? get session => _session;

  Future<OfflineHostStartResult> start(OfflineHostSession session) async {
    await stop(clearSessionFile: false);
    final lanHosts = await _resolveLanHosts();
    final host = lanHosts.isNotEmpty ? lanHosts.first : '127.0.0.1';
    final server = await _bindServer(session.port);
    _server = server;
    _session = session.copyWith(
      isActive: true,
      port: server.port,
      serverHost: host,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _startDiscoveryResponder();
    await _persistArtifacts();
    unawaited(_listen(server));
    return OfflineHostStartResult(
      session: _session!,
      localApiBaseUrl: _session!.localApiBaseUrl,
      lanApiBaseUrl: _session!.lanApiBaseUrl,
    );
  }

  Future<void> stop({bool clearSessionFile = true}) async {
    final server = _server;
    final discoverySocket = _discoverySocket;
    _server = null;
    _discoverySocket = null;
    if (server != null) {
      await server.close(force: true);
    }
    discoverySocket?.close();
    if (_session != null && clearSessionFile) {
      await clearOfflineHostSession();
    } else if (_session != null) {
      await saveOfflineHostSession(_session!.copyWith(isActive: false));
    }
    _session = null;
  }

  Future<void> _persistArtifacts() async {
    final session = _session;
    if (session == null) return;
    await saveOfflineHostSession(session);
    await File(
      session.ordersFilePath,
    ).writeAsString(jsonEncode(session.buildExportPayload()), flush: true);
    await File(session.accessFilePath).writeAsString(
      jsonEncode({
        'session_id': session.sessionId,
        'event_name': session.eventName,
        'api_base_url': session.lanApiBaseUrl,
        'public_qr_url': session.publicQrUrl,
        'staff_username': session.staffUsername,
        'staff_password': session.staffPassword,
        'client_pin': session.accessPin,
        'photo_count': session.photos.length,
        'generated_at': DateTime.now().toIso8601String(),
      }),
      flush: true,
    );
  }

  Future<HttpServer> _bindServer(int preferredPort) async {
    final ports = <int>[preferredPort, 4000, 4001, 4002, 4010, 4100];
    for (final port in ports.toSet()) {
      try {
        return await HttpServer.bind(
          InternetAddress.anyIPv4,
          port,
          shared: true,
        );
      } catch (_) {}
    }
    return HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
  }

  Future<void> _startDiscoveryResponder() async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      kOfflineDiscoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
    socket.broadcastEnabled = true;
    _discoverySocket = socket;
    socket.listen((event) async {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      final text = utf8.decode(datagram.data, allowMalformed: true).trim();
      if (text.isEmpty) return;
      try {
        final decoded = jsonDecode(text);
        if (decoded is! Map) return;
        final map = Map<String, dynamic>.from(decoded);
        if (map['type']?.toString() != kOfflineDiscoveryType) return;
        final session = _session;
        if (session == null || !session.isActive) return;
        final candidateUrls = (await _resolveLanHosts())
            .map((host) => 'http://$host:${session.port}/api')
            .toList();
        final response = utf8.encode(
          jsonEncode({
            'type': kOfflineDiscoveryResponseType,
            'server_url': candidateUrls.isNotEmpty
                ? candidateUrls.first
                : session.lanApiBaseUrl,
            'event_name': session.eventName,
            'session_id': session.sessionId,
            'qr_url': candidateUrls.isNotEmpty
                ? _publicQrUrlForApiBaseUrl(
                    candidateUrls.first,
                    session.qrToken,
                  )
                : session.publicQrUrl,
            'host': candidateUrls.isNotEmpty
                ? Uri.parse(candidateUrls.first).host
                : session.serverHost,
            'port': session.port,
            'candidate_urls': candidateUrls,
          }),
        );
        socket.send(response, datagram.address, datagram.port);
      } catch (_) {}
    });
  }

  Future<List<String>> _resolveLanHosts() async {
    final candidates = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      final sorted = [...interfaces];
      sorted.sort(
        (a, b) => _interfaceScore(b.name).compareTo(_interfaceScore(a.name)),
      );
      for (final iface in sorted) {
        for (final address in iface.addresses) {
          if (!address.isLoopback &&
              looksLikeLocalApiBaseUrl('http://${address.address}')) {
            candidates.add(address.address);
          }
        }
      }
    } catch (_) {}
    if (candidates.isEmpty) return const ['127.0.0.1'];
    return candidates.toSet().toList();
  }

  Future<void> _listen(HttpServer server) async {
    try {
      await for (final request in server) {
        unawaited(_handle(request));
      }
    } catch (_) {}
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (request.method == 'OPTIONS') {
        _writeCors(request.response);
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }
      final path = request.uri.path;
      if (path.startsWith('/offline/previews/')) {
        await _servePreview(request);
        return;
      }
      if (path.startsWith('/offline/photos/')) {
        await _servePhoto(request);
        return;
      }
      if (path == '/api/public/events/today' && request.method == 'GET') {
        await _handleTodayEvents(request);
        return;
      }
      if (path == '/api/public/events/pin' && request.method == 'POST') {
        await _handleEnterByPin(request);
        return;
      }
      if (path.startsWith('/api/public/events/') &&
          path.endsWith('/enter') &&
          request.method == 'POST') {
        await _handleEnterById(request);
        return;
      }
      if (path.startsWith('/api/public/events/qr/') &&
          request.method == 'GET') {
        await _handleEnterByQr(request);
        return;
      }
      if (path.startsWith('/api/public/events/') &&
          path.endsWith('/photos') &&
          request.method == 'GET') {
        await _handlePhotos(request);
        return;
      }
      if (path.startsWith('/api/public/events/') &&
          path.endsWith('/face-search') &&
          request.method == 'POST') {
        await _handleFaceSearch(request);
        return;
      }
      if (path == '/api/public/orders' && request.method == 'POST') {
        await _handleCreateOrder(request);
        return;
      }
      if (path.startsWith('/api/public/orders/') &&
          path.endsWith('/download-link') &&
          request.method == 'POST') {
        await _handleDownloadLink(request);
        return;
      }
      if (path.startsWith('/api/public/orders/') && request.method == 'GET') {
        await _handlePublicOrderDetail(request);
        return;
      }
      if (path == '/api/public/logs' && request.method == 'POST') {
        await _json(request, HttpStatus.ok, {'ok': true});
        return;
      }
      if (path == '/api/auth/login' && request.method == 'POST') {
        await _handleStaffLogin(request);
        return;
      }
      if (path == '/api/auth/logout' && request.method == 'POST') {
        await _json(request, HttpStatus.ok, {'message': 'Logged out'});
        return;
      }
      if (path == '/api/auth/me' && request.method == 'GET') {
        await _handleStaffMe(request);
        return;
      }
      if (path == '/api/events' && request.method == 'GET') {
        await _handleStaffEvents(request);
        return;
      }
      if (path == '/api/orders' && request.method == 'GET') {
        await _handleStaffOrdersList(request);
        return;
      }
      if (path == '/api/orders/bulk-status' && request.method == 'POST') {
        await _handleBulkStatus(request);
        return;
      }
      if (path.startsWith('/api/events/') &&
          path.endsWith('/orders') &&
          request.method == 'GET') {
        await _handleStaffEventOrders(request);
        return;
      }
      if (path.startsWith('/api/orders/') &&
          path.endsWith('/mark-paid') &&
          request.method == 'POST') {
        await _handleMarkPaid(request);
        return;
      }
      if (path.startsWith('/api/orders/') &&
          path.endsWith('/send-download-link') &&
          request.method == 'POST') {
        await _handleSendDownloadLink(request);
        return;
      }
      if (path.startsWith('/api/orders/') &&
          path.endsWith('/download-all') &&
          request.method == 'GET') {
        await _json(request, HttpStatus.unprocessableEntity, {
          'message': 'Indisponível offline.',
        });
        return;
      }
      if (path.startsWith('/api/orders/') && request.method == 'GET') {
        await _handleStaffOrderDetail(request);
        return;
      }
      if (path.startsWith('/api/orders/') && request.method == 'PUT') {
        await _handleUpdateOrder(request);
        return;
      }
      if (path.startsWith('/api/offline/events/') &&
          path.endsWith('/export') &&
          request.method == 'GET') {
        await _handleOfflineExport(request);
        return;
      }
      if (path.startsWith('/api/offline/events/') &&
          path.endsWith('/import') &&
          request.method == 'POST') {
        await _json(request, HttpStatus.ok, {
          'message': 'Import local não necessário.',
        });
        return;
      }
      await _json(request, HttpStatus.notFound, {'message': 'Not found'});
    } catch (e, st) {
      debugPrint('offline host error: $e\n$st');
      try {
        await _json(request, HttpStatus.internalServerError, {
          'message': 'Erro interno offline.',
        });
      } catch (_) {
        try {
          await request.response.close();
        } catch (_) {}
      }
    }
  }

  void _writeCors(HttpResponse response) {
    response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
    response.headers.set(
      HttpHeaders.accessControlAllowHeadersHeader,
      'Content-Type, Authorization',
    );
    response.headers.set(
      HttpHeaders.accessControlAllowMethodsHeader,
      'GET, POST, PUT, OPTIONS',
    );
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  Future<void> _json(
    HttpRequest request,
    int status,
    Map<String, dynamic> body,
  ) async {
    _writeCors(request.response);
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  OfflineHostSession _requireSession() {
    final session = _session;
    if (session == null) {
      throw StateError('Offline session unavailable');
    }
    return session;
  }

  Map<String, dynamic> _eventJson(OfflineHostSession session) => {
    'id': session.eventId,
    'name': session.eventName,
    'event_type': session.eventType,
    'event_meta': session.eventMeta,
    'event_date': session.eventDate,
    'location': session.location,
    'base_price': session.basePrice,
    'price_per_photo': session.pricePerPhoto,
    'qr_token': session.qrToken,
    'access_pin': session.accessPin,
  };

  Map<String, dynamic> _guestSessionJson(OfflineHostSession session) => {
    'event_session_token': session.guestToken,
    'event': _eventJson(session),
  };

  Map<String, dynamic> _staffUserJson(OfflineHostSession session) => {
    'id': session.staffUserId,
    'name': session.staffName,
    'username': session.staffUsername,
    'email': '',
    'role': 'staff',
    'permissions': [
      'dashboard.view',
      'events.list',
      'events.view',
      'orders.list',
      'orders.view',
      'orders.update',
      'offline.export',
    ],
  };

  Future<void> _servePhoto(HttpRequest request) async {
    final session = _requireSession();
    final idText = request.uri.pathSegments.isNotEmpty
        ? request.uri.pathSegments.last
        : '';
    final photoId = int.tryParse(idText);
    final photo = session.photos.cast<OfflineHostPhoto?>().firstWhere(
      (item) => item?.id == photoId,
      orElse: () => null,
    );
    if (photo == null || !await File(photo.path).exists()) {
      await _json(request, HttpStatus.notFound, {
        'message': 'Foto não encontrada.',
      });
      return;
    }
    _writeCors(request.response);
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.parse(
      _mimeTypeForPath(photo.path),
    );
    await request.response.addStream(File(photo.path).openRead());
    await request.response.close();
  }

  Future<void> _servePreview(HttpRequest request) async {
    final session = _requireSession();
    final idText = request.uri.pathSegments.isNotEmpty
        ? request.uri.pathSegments.last
        : '';
    final photoId = int.tryParse(idText);
    final photo = session.photos.cast<OfflineHostPhoto?>().firstWhere(
      (item) => item?.id == photoId,
      orElse: () => null,
    );
    if (photo == null || !await File(photo.path).exists()) {
      await _json(request, HttpStatus.notFound, {
        'message': 'Foto não encontrada.',
      });
      return;
    }
    final p = photo.path.toLowerCase();
    final isUnsupported = p.endsWith('.heic') || p.endsWith('.heif');
    if (!isUnsupported) {
      try {
        final cacheDir = await getTemporaryDirectory();
        final cacheFile = File('${cacheDir.path}/s59_thumb_${photo.id}.jpg');
        Uint8List thumbBytes;
        if (await cacheFile.exists()) {
          thumbBytes = await cacheFile.readAsBytes();
        } else {
          final srcBytes = await File(photo.path).readAsBytes();
          final generated = await compute(_generateThumbnailBytes, srcBytes);
          if (generated != null) {
            thumbBytes = generated;
            try {
              await cacheFile.writeAsBytes(thumbBytes);
            } catch (_) {}
          } else {
            thumbBytes = srcBytes;
          }
        }
        _writeCors(request.response);
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.parse('image/jpeg');
        request.response.contentLength = thumbBytes.length;
        request.response.add(thumbBytes);
        await request.response.close();
        return;
      } catch (_) {
        // Fall through to serve original on any error
      }
    }
    _writeCors(request.response);
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.parse(
      _mimeTypeForPath(photo.path),
    );
    await request.response.addStream(File(photo.path).openRead());
    await request.response.close();
  }

  bool _hasGuestToken(HttpRequest request, OfflineHostSession session) {
    final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    return header == 'Bearer ${session.guestToken}';
  }

  bool _hasStaffToken(HttpRequest request, OfflineHostSession session) {
    final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    return header == 'Bearer ${session.staffToken}';
  }

  Future<void> _handleTodayEvents(HttpRequest request) async {
    final session = _requireSession();
    await _json(request, HttpStatus.ok, {
      'data': [
        {
          'id': session.eventId,
          'name': session.eventName,
          'event_date': session.eventDate,
          'location': session.location,
        },
      ],
    });
  }

  Future<void> _handleEnterByPin(HttpRequest request) async {
    final session = _requireSession();
    final body = await _readJsonBody(request);
    final pin = body['pin']?.toString().trim() ?? '';
    if (pin.isEmpty || pin != session.accessPin) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Invalid PIN',
      });
      return;
    }
    await _json(request, HttpStatus.ok, _guestSessionJson(session));
  }

  Future<void> _handleEnterById(HttpRequest request) async {
    final session = _requireSession();
    final body = await _readJsonBody(request);
    final pin = (body['pin']?.toString() ?? body['password']?.toString() ?? '')
        .trim();
    if (pin.isEmpty || pin != session.accessPin) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Invalid PIN',
      });
      return;
    }
    await _json(request, HttpStatus.ok, _guestSessionJson(session));
  }

  Future<void> _handleEnterByQr(HttpRequest request) async {
    final session = _requireSession();
    final token = request.uri.pathSegments.isNotEmpty
        ? request.uri.pathSegments.last
        : '';
    if (token != session.qrToken) {
      await _json(request, HttpStatus.notFound, {
        'message': 'Event not available',
      });
      return;
    }
    await _json(request, HttpStatus.ok, _guestSessionJson(session));
  }

  Future<void> _handlePhotos(HttpRequest request) async {
    final session = _requireSession();
    if (!_hasGuestToken(request, session)) {
      await _json(request, HttpStatus.forbidden, {
        'message': 'Sessão inválida.',
      });
      return;
    }
    final search =
        request.uri.queryParameters['search']?.trim().toLowerCase() ?? '';
    final page = int.tryParse(request.uri.queryParameters['page'] ?? '1') ?? 1;
    final perPage =
        int.tryParse(request.uri.queryParameters['per_page'] ?? '50') ?? 50;
    final filtered = session.photos
        .where(
          (photo) =>
              search.isEmpty || photo.number.toLowerCase().contains(search),
        )
        .toList();
    final safePerPage = perPage < 1 ? 50 : min(perPage, 200);
    final safePage = page < 1 ? 1 : page;
    final total = filtered.length;
    final lastPage = total == 0 ? 1 : ((total - 1) ~/ safePerPage) + 1;
    final start = (safePage - 1) * safePerPage;
    final slice = start >= total
        ? <OfflineHostPhoto>[]
        : filtered.skip(start).take(safePerPage).toList();
    final requested = request.requestedUri;
    await _json(request, HttpStatus.ok, {
      'data': [
        for (final photo in slice)
          {
            'id': photo.id,
            'number': photo.number,
            'preview_url': requested
                .replace(
                  path: '/offline/previews/${photo.id}',
                  query: null,
                  fragment: null,
                )
                .toString(),
          },
      ],
      'total': total,
      'current_page': safePage,
      'last_page': lastPage,
      'per_page': safePerPage,
    });
  }

  Future<void> _handleFaceSearch(HttpRequest request) async {
    final session = _requireSession();
    if (!_hasGuestToken(request, session)) {
      await _json(request, HttpStatus.forbidden, {
        'message': 'Sessão inválida.',
      });
      return;
    }
    final eventId = request.uri.pathSegments.length >= 4
        ? int.tryParse(request.uri.pathSegments[3])
        : null;
    if (eventId == null || eventId != session.eventId) {
      await _json(request, HttpStatus.notFound, {
        'message': 'Event not available',
      });
      return;
    }
    final scriptPath = await _resolveFaceSearchScriptPath();
    if (scriptPath == null) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Reconhecimento facial offline indisponível neste PC.',
      });
      return;
    }
    final python = await _resolveOfflinePythonCommand();
    if (python == null) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Python não encontrado neste PC.',
      });
      return;
    }
    final faceRoot = await _offlineFaceSearchRootDirectory();
    final tmpDir = Directory(_pathJoin(faceRoot.path, 'tmp'));
    final indexDir = Directory(_pathJoin(faceRoot.path, 'face_index'));
    final insightDir = Directory(_pathJoin(faceRoot.path, 'insightface'));
    await tmpDir.create(recursive: true);
    await indexDir.create(recursive: true);
    await insightDir.create(recursive: true);
    final selfieFile = await _saveMultipartSelfie(request, tmpDir);
    if (selfieFile == null || !await selfieFile.exists()) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Selfie inválida.',
      });
      return;
    }
    if (await selfieFile.length() > (5 * 1024 * 1024)) {
      try {
        await selfieFile.delete();
      } catch (_) {}
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'A selfie é demasiado grande.',
      });
      return;
    }
    final photosPayload = <Map<String, dynamic>>[];
    for (final photo in session.photos) {
      final file = File(photo.path);
      if (!await file.exists()) continue;
      DateTime? modified;
      try {
        modified = await file.lastModified();
      } catch (_) {}
      photosPayload.add({
        'id': photo.id,
        'path': photo.path,
        'mtime': modified?.millisecondsSinceEpoch,
      });
    }
    if (photosPayload.isEmpty) {
      try {
        await selfieFile.delete();
      } catch (_) {}
      await _json(request, HttpStatus.ok, {'suggested': const []});
      return;
    }
    final token = DateTime.now().microsecondsSinceEpoch;
    final photosJson = File(
      _pathJoin(tmpDir.path, 'face-photos-${session.eventId}-$token.json'),
    );
    await photosJson.writeAsString(jsonEncode(photosPayload), flush: true);
    final indexPath = _pathJoin(
      indexDir.path,
      'event_${session.eventId}.pkl',
    );
    final args = [
      ...python.prefixArgs,
      scriptPath,
      '--event',
      session.eventId.toString(),
      '--selfie',
      selfieFile.path,
      '--photos',
      photosJson.path,
      '--index',
      indexPath,
    ];
    ProcessResult? result;
    try {
      result = await Process.run(
        python.command,
        args,
        runInShell: Platform.isWindows,
        environment: {
          ...Platform.environment,
          'INSIGHTFACE_HOME': insightDir.path,
          'HOME': insightDir.path,
        },
      );
    } catch (_) {}
    try {
      await selfieFile.delete();
    } catch (_) {}
    try {
      await photosJson.delete();
    } catch (_) {}
    if (result == null) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Falha ao iniciar face search offline.',
      });
      return;
    }
    final stdout = result.stdout?.toString().trim() ?? '';
    final stderr = result.stderr?.toString().trim() ?? '';
    Map<String, dynamic>? payload;
    if (stdout.isNotEmpty) {
      try {
        final decoded = jsonDecode(stdout);
        if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    final errorCode = payload?['error']?.toString().trim() ?? '';
    if (errorCode == 'no_face_detected') {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Nenhum rosto detetado.',
      });
      return;
    }
    if (errorCode.isNotEmpty) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Erro no reconhecimento facial.',
      });
      return;
    }
    if (payload == null) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Resposta inválida do reconhecimento facial.',
        if (stderr.isNotEmpty) 'detail': stderr,
      });
      return;
    }
    final suggestedIds = ((payload['suggested'] as List?) ?? const [])
        .map((item) {
          if (item is Map) {
            return int.tryParse(item['id']?.toString() ?? '');
          }
          return null;
        })
        .whereType<int>()
        .toList();
    final byId = {for (final photo in session.photos) photo.id: photo};
    final requested = request.requestedUri;
    final responsePayload = <Map<String, dynamic>>[];
    for (final id in suggestedIds) {
      final photo = byId[id];
      if (photo == null) continue;
      responsePayload.add({
        'id': photo.id,
        'number': photo.number,
        'preview_url': requested
            .replace(
              path: '/offline/previews/${photo.id}',
              query: null,
              fragment: null,
            )
            .toString(),
      });
    }
    await _json(request, HttpStatus.ok, {'suggested': responsePayload});
  }

  Future<Directory> _offlineFaceSearchRootDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(_pathJoin(docs.path, 'studio59_face'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<String?> _resolveFaceSearchScriptPath() async {
    final candidates = <String>{
      _pathJoin(Directory.current.path, 'backend/scripts/face_search.py'),
      _pathJoin(Directory.current.path, 'scripts/face_search.py'),
      _pathJoin(
        Directory.current.parent.path,
        'backend/scripts/face_search.py',
      ),
    };
    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        return candidate;
      }
    }
    return null;
  }

  Future<_OfflinePythonCommand?> _resolveOfflinePythonCommand() async {
    final attempts = <_OfflinePythonCommand>[
      if (Platform.isWindows) const _OfflinePythonCommand('py', ['-3']),
      const _OfflinePythonCommand('python3'),
      const _OfflinePythonCommand('python'),
    ];
    for (final attempt in attempts) {
      try {
        final result = await Process.run(
          attempt.command,
          [...attempt.prefixArgs, '--version'],
          runInShell: Platform.isWindows,
        );
        if (result.exitCode == 0) return attempt;
      } catch (_) {}
    }
    return null;
  }

  Future<File?> _saveMultipartSelfie(
    HttpRequest request,
    Directory directory,
  ) async {
    final contentType = request.headers.contentType;
    final boundary = contentType?.parameters['boundary'];
    if (contentType == null ||
        contentType.mimeType != 'multipart/form-data' ||
        boundary == null ||
        boundary.trim().isEmpty) {
      return null;
    }
    final parts = MimeMultipartTransformer(boundary).bind(request);
    await for (final part in parts) {
      final disposition = part.headers['content-disposition'];
      final name = _multipartHeaderValue(disposition, 'name');
      if (name != 'selfie') {
        await part.drain<void>();
        continue;
      }
      final ext = _imageExtensionForName(
        _multipartHeaderValue(disposition, 'filename'),
      );
      final file = File(
        _pathJoin(
          directory.path,
          'face-selfie-${DateTime.now().microsecondsSinceEpoch}$ext',
        ),
      );
      final sink = file.openWrite();
      try {
        await sink.addStream(part);
      } finally {
        await sink.close();
      }
      return file;
    }
    return null;
  }

  Future<void> _handleCreateOrder(HttpRequest request) async {
    final session = _requireSession();
    if (!_hasGuestToken(request, session)) {
      await _json(request, HttpStatus.forbidden, {
        'message': 'Sessão inválida.',
      });
      return;
    }
    final body = await _readJsonBody(request);
    final customerName = body['customer_name']?.toString().trim() ?? '';
    final customerPhone = body['customer_phone']?.toString().trim() ?? '';
    final customerEmail = body['customer_email']?.toString().trim() ?? '';
    final productType = body['product_type']?.toString().trim() ?? 'digital';
    final deliveryTypeRaw = body['delivery_type']?.toString().trim();
    final deliveryType = deliveryTypeRaw == null || deliveryTypeRaw.isEmpty
        ? null
        : deliveryTypeRaw;
    final deliveryAddress = body['delivery_address']?.toString().trim() ?? '';
    final wantsFilm = body['wants_film'] == true || body['wants_film'] == 1;
    final paymentMethod = body['payment_method']?.toString().trim() ?? 'cash';
    final photoItemsRaw = (body['photo_items'] as List?) ?? const [];
    if (customerName.isEmpty || customerPhone.isEmpty) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Nome e telemóvel são obrigatórios.',
      });
      return;
    }
    if ((productType == 'digital' || productType == 'both') &&
        customerEmail.isEmpty) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Email obrigatório para entrega digital.',
      });
      return;
    }
    if (customerEmail.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(customerEmail)) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Email inválido.',
      });
      return;
    }
    if (productType != 'digital' && deliveryType == null) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Escolhe o tipo de entrega.',
      });
      return;
    }
    if (deliveryType == 'shipping' && deliveryAddress.isEmpty) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Morada obrigatória para envio.',
      });
      return;
    }
    if (paymentMethod != 'cash') {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Offline só suporta pagamento físico.',
      });
      return;
    }
    final quantityByPhoto = <int, int>{};
    for (final item in photoItemsRaw) {
      if (item is! Map) continue;
      final photoId = int.tryParse(item['photo_id']?.toString() ?? '') ?? 0;
      final quantity = max(
        1,
        int.tryParse(item['quantity']?.toString() ?? '') ?? 1,
      );
      if (photoId > 0) {
        quantityByPhoto[photoId] = quantity;
      }
    }
    if (quantityByPhoto.isEmpty) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Seleciona pelo menos 1 foto.',
      });
      return;
    }
    final photos = session.photos
        .where((photo) => quantityByPhoto.containsKey(photo.id))
        .toList();
    if (photos.length != quantityByPhoto.length) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Algumas fotos não existem nesta sessão.',
      });
      return;
    }
    final items = [
      for (final photo in photos)
        OfflineHostOrderItem(
          photoId: photo.id,
          photoNumber: photo.number,
          quantity: quantityByPhoto[photo.id] ?? 1,
          price: session.pricePerPhoto,
        ),
    ];
    final itemsTotal = items.fold<num>(
      0,
      (sum, item) => sum + (item.quantity * item.price),
    );
    final shippingFee = deliveryType == 'shipping' ? 5.0 : 0.0;
    final filmFee = wantsFilm ? 30.0 : 0.0;
    final extrasTotal = shippingFee + filmFee;
    final totalAmount = itemsTotal + extrasTotal;
    final now = DateTime.now().toIso8601String();
    final order = OfflineHostOrder(
      id: (session.orders.map((e) => e.id).fold<int>(0, max)) + 1,
      orderCode: generateOfflineOrderCode(),
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      productType: productType,
      deliveryType: deliveryType,
      deliveryAddress: deliveryAddress,
      wantsFilm: wantsFilm,
      filmFee: filmFee,
      shippingFee: shippingFee,
      extrasTotal: extrasTotal,
      itemsTotal: itemsTotal,
      paymentMethod: 'cash',
      cashReceivedAmount: null,
      cashChangeAmount: null,
      cashDueAmount: null,
      status: 'pending',
      totalAmount: totalAmount,
      items: items,
      createdAt: now,
      updatedAt: now,
    );
    _session = session.copyWith(
      orders: [...session.orders, order],
      updatedAt: now,
    );
    await _persistArtifacts();
    await _json(request, HttpStatus.created, {
      'order_code': order.orderCode,
      'status': order.status,
      'total_amount': order.totalAmount,
    });
  }

  Future<void> _handlePublicOrderDetail(HttpRequest request) async {
    final session = _requireSession();
    final orderCode = request.uri.pathSegments.isNotEmpty
        ? request.uri.pathSegments.last
        : '';
    final order = session.orders.cast<OfflineHostOrder?>().firstWhere(
      (item) => item?.orderCode == orderCode,
      orElse: () => null,
    );
    if (order == null) {
      await _json(request, HttpStatus.notFound, {
        'message': 'Pedido não encontrado.',
      });
      return;
    }
    await _json(request, HttpStatus.ok, order.toOrderDetailJson());
  }

  Future<void> _handleDownloadLink(HttpRequest request) async {
    final session = _requireSession();
    final orderCode = request.uri.pathSegments.length >= 4
        ? request.uri.pathSegments[3]
        : '';
    final order = session.orders.cast<OfflineHostOrder?>().firstWhere(
      (item) => item?.orderCode == orderCode,
      orElse: () => null,
    );
    if (order == null) {
      await _json(request, HttpStatus.notFound, {
        'message': 'Pedido não encontrado.',
      });
      return;
    }
    if (order.status != 'paid') {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Order is not paid',
      });
      return;
    }
    await _json(request, HttpStatus.unprocessableEntity, {
      'message': 'Download indisponível offline. Sincroniza primeiro.',
    });
  }

  Future<void> _handleStaffLogin(HttpRequest request) async {
    final session = _requireSession();
    final body = await _readJsonBody(request);
    final login =
        body['login']?.toString().trim() ??
        body['email']?.toString().trim() ??
        '';
    final password = body['password']?.toString() ?? '';
    if (login != session.staffUsername || password != session.staffPassword) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Invalid credentials',
      });
      return;
    }
    await _json(request, HttpStatus.ok, {
      'token': session.staffToken,
      'user': _staffUserJson(session),
      'offline_mode': true,
    });
  }

  Future<void> _handleStaffMe(HttpRequest request) async {
    final session = _requireSession();
    if (!_hasStaffToken(request, session)) {
      await _json(request, HttpStatus.unauthorized, {
        'message': 'Unauthorized',
      });
      return;
    }
    await _json(request, HttpStatus.ok, _staffUserJson(session));
  }

  Future<void> _handleStaffEvents(HttpRequest request) async {
    final session = _requireSession();
    if (!_hasStaffToken(request, session)) {
      await _json(request, HttpStatus.unauthorized, {
        'message': 'Unauthorized',
      });
      return;
    }
    await _json(request, HttpStatus.ok, {
      'data': [
        {
          'id': session.eventId,
          'name': session.eventName,
          'event_date': session.eventDate,
          'event_time': null,
          'price_per_photo': session.pricePerPhoto,
          'base_price': session.basePrice,
          'is_active_today': true,
          'location': session.location,
          'event_type': session.eventType,
          'event_meta': session.eventMeta,
          'qr_token': session.qrToken,
          'access_pin': session.accessPin,
          'notes': 'Sessão offline local',
          'is_locked': false,
        },
      ],
      'current_page': 1,
      'last_page': 1,
      'per_page': 200,
      'total': 1,
    });
  }

  Future<void> _handleStaffOrdersList(HttpRequest request) async {
    final session = _requireSession();
    if (!_hasStaffToken(request, session)) {
      await _json(request, HttpStatus.unauthorized, {
        'message': 'Unauthorized',
      });
      return;
    }
    final q = request.uri.queryParameters['q']?.trim().toLowerCase() ?? '';
    final status = request.uri.queryParameters['status']?.trim() ?? '';
    final eventDate = request.uri.queryParameters['event_date']?.trim() ?? '';
    if (eventDate.isNotEmpty && eventDate != session.eventDate) {
      await _json(request, HttpStatus.ok, {
        'data': const <Map<String, dynamic>>[],
        'current_page': 1,
        'last_page': 1,
        'per_page': 30,
        'total': 0,
      });
      return;
    }
    final event = {
      'id': session.eventId,
      'name': session.eventName,
      'event_date': session.eventDate,
    };
    final filtered = session.orders.where((order) {
      if (status.isNotEmpty && order.status != status) return false;
      if (q.isEmpty) return true;
      return order.customerName.toLowerCase().contains(q) ||
          order.orderCode.toLowerCase().contains(q) ||
          order.customerPhone.toLowerCase().contains(q) ||
          order.customerEmail.toLowerCase().contains(q);
    }).toList()..sort((a, b) => b.id.compareTo(a.id));
    await _json(request, HttpStatus.ok, {
      'data': filtered.map((order) => order.toStaffListJson(event)).toList(),
      'current_page': 1,
      'last_page': 1,
      'per_page': 30,
      'total': filtered.length,
    });
  }

  Future<void> _handleStaffEventOrders(HttpRequest request) async {
    final session = _requireSession();
    if (!_hasStaffToken(request, session)) {
      await _json(request, HttpStatus.unauthorized, {
        'message': 'Unauthorized',
      });
      return;
    }
    final status = request.uri.queryParameters['status']?.trim() ?? '';
    final q = request.uri.queryParameters['q']?.trim().toLowerCase() ?? '';
    final filtered = session.orders.where((order) {
      if (status.isNotEmpty && order.status != status) return false;
      if (q.isEmpty) return true;
      return order.customerName.toLowerCase().contains(q) ||
          order.orderCode.toLowerCase().contains(q);
    }).toList()..sort((a, b) => b.id.compareTo(a.id));
    await _json(request, HttpStatus.ok, {
      'data': filtered
          .map(
            (order) => {
              'id': order.id,
              'order_code': order.orderCode,
              'customer_name': order.customerName,
              'status': order.status,
            },
          )
          .toList(),
      'current_page': 1,
      'last_page': 1,
      'per_page': 30,
      'total': filtered.length,
    });
  }

  OfflineHostOrder? _findOrderById(int id) {
    final session = _session;
    if (session == null) return null;
    for (final order in session.orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  Future<void> _handleStaffOrderDetail(HttpRequest request) async {
    final session = _requireSession();
    if (!_hasStaffToken(request, session)) {
      await _json(request, HttpStatus.unauthorized, {
        'message': 'Unauthorized',
      });
      return;
    }
    final idText = request.uri.pathSegments.isNotEmpty
        ? request.uri.pathSegments.last
        : '';
    final id = int.tryParse(idText);
    final order = id == null ? null : _findOrderById(id);
    if (order == null) {
      await _json(request, HttpStatus.notFound, {
        'message': 'Pedido não encontrado.',
      });
      return;
    }
    await _json(request, HttpStatus.ok, {
      ...order.toStaffListJson({
        'id': session.eventId,
        'name': session.eventName,
        'event_date': session.eventDate,
      }),
      'photos': [
        for (final item in order.items)
          {
            'id': item.photoId,
            'number': item.photoNumber,
            'quantity': item.quantity,
          },
      ],
    });
  }

  Future<void> _handleUpdateOrder(HttpRequest request) async {
    final session = _requireSession();
    if (!_hasStaffToken(request, session)) {
      await _json(request, HttpStatus.unauthorized, {
        'message': 'Unauthorized',
      });
      return;
    }
    final idText = request.uri.pathSegments.isNotEmpty
        ? request.uri.pathSegments.last
        : '';
    final id = int.tryParse(idText);
    final current = id == null ? null : _findOrderById(id);
    if (current == null) {
      await _json(request, HttpStatus.notFound, {
        'message': 'Pedido não encontrado.',
      });
      return;
    }
    final body = await _readJsonBody(request);
    final updated = current.copyWith(
      customerName: body['customer_name']?.toString().trim().isNotEmpty == true
          ? body['customer_name']?.toString().trim()
          : current.customerName,
      customerEmail:
          body['customer_email']?.toString().trim() ?? current.customerEmail,
      customerPhone:
          body['customer_phone']?.toString().trim() ?? current.customerPhone,
      paymentMethod:
          body['payment_method']?.toString().trim().isNotEmpty == true
          ? body['payment_method']?.toString().trim()
          : current.paymentMethod,
      cashReceivedAmount: body['cash_received_amount'] == null
          ? current.cashReceivedAmount
          : (body['cash_received_amount'] is num
                ? body['cash_received_amount'] as num
                : num.tryParse(body['cash_received_amount']?.toString() ?? '')),
      cashChangeAmount: body['cash_change_amount'] == null
          ? current.cashChangeAmount
          : (body['cash_change_amount'] is num
                ? body['cash_change_amount'] as num
                : num.tryParse(body['cash_change_amount']?.toString() ?? '')),
      cashDueAmount: body['cash_due_amount'] == null
          ? current.cashDueAmount
          : (body['cash_due_amount'] is num
                ? body['cash_due_amount'] as num
                : num.tryParse(body['cash_due_amount']?.toString() ?? '')),
      status: body['status']?.toString().trim().isNotEmpty == true
          ? body['status']?.toString().trim()
          : current.status,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _session = session.copyWith(
      orders: [
        for (final order in session.orders)
          if (order.id == updated.id) updated else order,
      ],
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _persistArtifacts();
    await _handleStaffOrderDetail(request);
  }

  Future<void> _handleBulkStatus(HttpRequest request) async {
    final session = _requireSession();
    if (!_hasStaffToken(request, session)) {
      await _json(request, HttpStatus.unauthorized, {
        'message': 'Unauthorized',
      });
      return;
    }
    final body = await _readJsonBody(request);
    final ids = ((body['order_ids'] as List?) ?? const [])
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .where((id) => id > 0)
        .toSet();
    final status = body['status']?.toString().trim() ?? '';
    if (ids.isEmpty || status.isEmpty) {
      await _json(request, HttpStatus.unprocessableEntity, {
        'message': 'Dados inválidos.',
      });
      return;
    }
    var updatedCount = 0;
    _session = session.copyWith(
      orders: [
        for (final order in session.orders)
          if (ids.contains(order.id))
            (() {
              updatedCount += 1;
              return order.copyWith(
                status: status,
                updatedAt: DateTime.now().toIso8601String(),
              );
            })()
          else
            order,
      ],
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _persistArtifacts();
    await _json(request, HttpStatus.ok, {'updated': updatedCount});
  }

  Future<void> _handleMarkPaid(HttpRequest request) async {
    final session = _requireSession();
    if (!_hasStaffToken(request, session)) {
      await _json(request, HttpStatus.unauthorized, {
        'message': 'Unauthorized',
      });
      return;
    }
    final idText = request.uri.pathSegments.length >= 3
        ? request.uri.pathSegments[2]
        : '';
    final id = int.tryParse(idText);
    final current = id == null ? null : _findOrderById(id);
    if (current == null) {
      await _json(request, HttpStatus.notFound, {
        'message': 'Pedido não encontrado.',
      });
      return;
    }
    final body = await _readJsonBody(request);
    final updated = current.copyWith(
      cashReceivedAmount: body['cash_received_amount'] is num
          ? body['cash_received_amount'] as num
          : num.tryParse(body['cash_received_amount']?.toString() ?? ''),
      cashChangeAmount: body['cash_change_amount'] is num
          ? body['cash_change_amount'] as num
          : num.tryParse(body['cash_change_amount']?.toString() ?? ''),
      cashDueAmount: body['cash_due_amount'] is num
          ? body['cash_due_amount'] as num
          : num.tryParse(body['cash_due_amount']?.toString() ?? ''),
      status: 'paid',
      updatedAt: DateTime.now().toIso8601String(),
    );
    _session = session.copyWith(
      orders: [
        for (final order in session.orders)
          if (order.id == updated.id) updated else order,
      ],
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _persistArtifacts();
    await _json(request, HttpStatus.ok, {
      'message': 'Order marked paid',
      'download_link_emailed': false,
    });
  }

  Future<void> _handleSendDownloadLink(HttpRequest request) async {
    final session = _requireSession();
    if (!_hasStaffToken(request, session)) {
      await _json(request, HttpStatus.unauthorized, {
        'message': 'Unauthorized',
      });
      return;
    }
    await _json(request, HttpStatus.ok, {
      'message': 'O email será enviado após sincronização online.',
      'sent': false,
    });
  }

  Future<void> _handleOfflineExport(HttpRequest request) async {
    final session = _requireSession();
    if (!_hasStaffToken(request, session)) {
      await _json(request, HttpStatus.unauthorized, {
        'message': 'Unauthorized',
      });
      return;
    }
    await _json(request, HttpStatus.ok, session.buildExportPayload());
  }
}

int _interfaceScore(String name) {
  final value = name.toLowerCase();
  var score = 0;
  if (value.contains('wi-fi') ||
      value.contains('wifi') ||
      value.contains('wlan') ||
      value.contains('wireless')) {
    score += 50;
  }
  if (value.contains('ethernet') ||
      value == 'en0' ||
      value == 'en1' ||
      value.startsWith('eth')) {
    score += 40;
  }
  if (value.contains('virtual') ||
      value.contains('vbox') ||
      value.contains('vmware') ||
      value.contains('hyper-v') ||
      value.contains('docker') ||
      value.contains('wsl') ||
      value.contains('loopback') ||
      value.contains('tailscale') ||
      value.contains('hamachi') ||
      value.contains('zerotier') ||
      value.contains('bridge') ||
      value.contains('vpn')) {
    score -= 100;
  }
  return score;
}
