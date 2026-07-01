import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_prevent_screen_capture/flutter_prevent_screen_capture.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import 'offline_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSize = 80;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 96 << 20;
  await _initFirebase();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const ProviderScope(child: Studio59App()));
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _initFirebase();
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Ignore if Firebase is not configured yet.
  }
}

const Color kBrandBlack = Color(0xFF000000);
const Color kBrandRose = Color(0xFFDBAB97);
const Color kBrandRoseSoft = Color(0x33DBAB97);

const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://studio59.wiredevelop.pt/api',
);
const String kApiFallbackIp = String.fromEnvironment(
  'API_FALLBACK_IP',
  defaultValue: '185.118.113.130',
);
const String kMerchantCountryCode = 'PT';
const String kApplePayMerchantId = 'merchant.com.wiredevelop.studio59';
const bool kEnablePlatformPay = true;
const String kStripeUrlScheme = 'flutterstripe';
const String kRuntimeConfigKey = 'app_runtime_config';

bool isDesktopPlatform() {
  if (kIsWeb) return false;
  final platform = defaultTargetPlatform;
  if (platform == TargetPlatform.windows ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.linux) {
    return true;
  }
  try {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  } catch (_) {
    return false;
  }
}

bool useDesktopLayout(BuildContext context) {
  return MediaQuery.of(context).size.width >= 768;
}

String formatUiError(Object error) {
  if (error is DioException && error.response?.statusCode == 413) {
    return 'Pacote demasiado grande. As fotos serão enviadas em lotes menores.';
  }
  if (error is DioException &&
      (error.type == DioExceptionType.connectionError ||
          error.error is SocketException)) {
    return 'Sem ligação ao servidor. Verifica a internet e tenta novamente.';
  }
  final text = error.toString().trim();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}

String formatEuroAmount(num value) => value.toStringAsFixed(2);

String previewUrlWithWidth(String url, int width) {
  final parsed = Uri.tryParse(url);
  if (parsed == null) return url;
  final query = Map<String, String>.from(parsed.queryParameters);
  query['w'] = '$width';
  return parsed.replace(queryParameters: query).toString();
}

String formatDeliveryTypeLabel(String? value) {
  switch (value) {
    case 'pickup':
      return 'Entregar';
    case 'store_pickup':
      return 'Levantar em Loja';
    case 'shipping':
      return 'Enviar por correio';
    default:
      return value ?? '-';
  }
}

class CashSettlement {
  const CashSettlement({
    required this.receivedAmount,
    required this.changeAmount,
    required this.changeGiven,
    required this.dueAmount,
    this.notes,
  });

  final num receivedAmount;
  final num changeAmount;
  final bool changeGiven;
  final num dueAmount;
  final String? notes;
}

Future<CashSettlement?> promptCashSettlement(
  BuildContext context, {
  required num totalAmount,
  String? initialNotes,
}) async {
  final ctrl = TextEditingController(text: formatEuroAmount(totalAmount));
  final notesCtrl = TextEditingController(text: initialNotes ?? '');
  try {
    return await showDialog<CashSettlement>(
      context: context,
      builder: (dialogContext) {
        num received = totalAmount;
        var changeGiven = false;

        num parseAmount() {
          final normalized = ctrl.text.trim().replaceAll(',', '.');
          return num.tryParse(normalized) ?? 0;
        }

        return StatefulBuilder(
          builder: (context, setState) {
            received = parseAmount();
            final change = received > totalAmount ? received - totalAmount : 0;
            final due = received < totalAmount ? totalAmount - received : 0;
            if (change <= 0) {
              changeGiven = true;
            }
            return AlertDialog(
              title: const Text('Pagamento em dinheiro'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total: €${formatEuroAmount(totalAmount)}'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor entregue',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Text('Troco: €${formatEuroAmount(change)}'),
                  Text('Falta: €${formatEuroAmount(due)}'),
                  if (change > 0) ...[
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: changeGiven,
                      onChanged: (value) =>
                          setState(() => changeGiven = value ?? false),
                      title: const Text('Troco entregue ao cliente'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    CashSettlement(
                      receivedAmount: received,
                      changeAmount: change,
                      changeGiven: change > 0 ? changeGiven : true,
                      dueAmount: due,
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                    ),
                  ),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    ctrl.dispose();
    notesCtrl.dispose();
  }
}

class CashOrderEdit {
  const CashOrderEdit({
    required this.receivedAmount,
    required this.changeAmount,
    required this.changeGiven,
    required this.dueAmount,
    required this.status,
    this.notes,
  });
  final num receivedAmount;
  final num changeAmount;
  final bool changeGiven;
  final num dueAmount;
  final String status;
  final String? notes;
}

Future<CashOrderEdit?> promptCashOrderEdit(
  BuildContext context, {
  required num totalAmount,
  required String currentStatus,
  num? currentReceived,
  bool? currentChangeGiven,
  String? currentNotes,
}) async {
  final ctrl = TextEditingController(
    text: currentReceived != null
        ? formatEuroAmount(currentReceived)
        : formatEuroAmount(totalAmount),
  );
  final notesCtrl = TextEditingController(text: currentNotes ?? '');
  String status = currentStatus;
  try {
    return await showDialog<CashOrderEdit>(
      context: context,
      builder: (dialogContext) {
        var changeGiven = currentChangeGiven ?? false;
        return StatefulBuilder(
          builder: (context, setState) {
            final normalized = ctrl.text.trim().replaceAll(',', '.');
            final received = num.tryParse(normalized) ?? 0;
            final change = received > totalAmount ? received - totalAmount : 0;
            final due = received < totalAmount ? totalAmount - received : 0;
            if (change <= 0) {
              changeGiven = true;
            }
            return AlertDialog(
              title: const Text('Editar pagamento em dinheiro'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total: €${formatEuroAmount(totalAmount)}'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Dinheiro recebido',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  if (change > 0)
                    Text(
                      'Troco a devolver ao cliente: €${formatEuroAmount(change)}',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (due > 0) Text('Falta receber: €${formatEuroAmount(due)}'),
                  if (change > 0) ...[
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: changeGiven,
                      onChanged: (value) =>
                          setState(() => changeGiven = value ?? false),
                      title: const Text('Troco entregue ao cliente'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    items: const [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pendente'),
                      ),
                      DropdownMenuItem(value: 'paid', child: Text('Pago')),
                      DropdownMenuItem(
                        value: 'delivered',
                        child: Text('Entregue'),
                      ),
                    ],
                    onChanged: (v) => setState(() => status = v ?? status),
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    CashOrderEdit(
                      receivedAmount: received,
                      changeAmount: change,
                      changeGiven: change > 0 ? changeGiven : true,
                      dueAmount: due,
                      status: status,
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                    ),
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    ctrl.dispose();
    notesCtrl.dispose();
  }
}

const Color kDeskBg = Color(0xFF0B0A0A);
const Color kDeskSurface = Color(0xFF111010);
const Color kDeskCard = Color(0xFF151313);
const Color kDeskCardAlt = Color(0xFF1A1717);
const Color kDeskMuted = Color(0xFF7B6B63);
const double kDeskRadius = 16;
const double kDeskRadiusLg = 20;
const double kDeskGutter = 22;
const double kDeskSidebarWidth = 260;

class OnlineMethodOption {
  const OnlineMethodOption(this.id, this.label, {this.opensWeb = false});
  final String id;
  final String label;
  final bool opensWeb;
}

const Set<String> kOnlineWebMethods = {'mb_way', 'paypal', 'revolut_pay'};

List<OnlineMethodOption> buildOnlineMethodOptions({
  required bool supportsApplePay,
  required bool supportsGooglePay,
}) {
  return [
    const OnlineMethodOption('card', 'Cartão'),
    if (supportsApplePay) const OnlineMethodOption('apple_pay', 'Apple Pay'),
    if (supportsGooglePay) const OnlineMethodOption('google_pay', 'Google Pay'),
    const OnlineMethodOption('mb_way', 'MB WAY', opensWeb: true),
    const OnlineMethodOption('paypal', 'PayPal', opensWeb: true),
    const OnlineMethodOption('revolut_pay', 'Revolut Pay', opensWeb: true),
  ];
}

const Map<String, String> kStaffPermissions = {
  'dashboard.view': 'Ver dashboard',
  'events.list': 'Ver calendário de eventos',
  'events.view': 'Ver detalhes dos eventos',
  'events.view.all': 'Ver todos os eventos (ignora equipa)',
  'events.pricing.view': 'Ver preços do evento',
  'events.internal.view': 'Ver dados internos do evento',
  'events.create': 'Criar eventos',
  'events.update': 'Editar eventos',
  'events.delete': 'Eliminar eventos',

  'uploads.list': 'Ver uploads',
  'uploads.create': 'Enviar uploads',

  'photos.list': 'Ver fotos',
  'photos.update': 'Atualizar fotos (retry)',
  'photos.delete': 'Apagar fotos',
  'photos.bulk_delete': 'Apagar fotos em massa',
  'photos.original': 'Download original',

  'orders.list': 'Ver pedidos',
  'orders.view': 'Ver detalhes do pedido',
  'orders.update': 'Atualizar pedidos',
  'orders.bulk': 'Atualizar pedidos em massa',
  'orders.download': 'Enviar link / download ZIP',
  'orders.export': 'Exportar CSV',

  'users.list': 'Ver utilizadores',
  'users.view': 'Ver detalhes do utilizador',
  'users.create': 'Criar utilizadores',
  'users.update': 'Editar utilizadores',
  'users.delete': 'Apagar utilizadores',

  'service_templates.manage': 'Gerir tipos de serviço e fichas',

  'clients.list': 'Ver clientes',
  'clients.view': 'Ver detalhes do cliente',
  'clients.create': 'Criar clientes',
  'clients.update': 'Editar clientes',
  'clients.delete': 'Apagar clientes',

  'offline.export': 'Exportar dados offline',
  'offline.import': 'Importar dados offline',

  'dossie.view': 'Ver Dossiê (arquivo por ano/mês/evento)',
};
const Set<String> kStaffDefaultPermissions = {
  'dashboard.view',
  'events.list',
  'events.pricing.view',
  'events.internal.view',
  'photos.list',
  'photos.update',
  'photos.delete',
  'photos.bulk_delete',
  'photos.original',
};

class AppRuntimeConfig {
  const AppRuntimeConfig({
    required this.apiBaseUrl,
    required this.apiFallbackIp,
    required this.merchantCountryCode,
    required this.applePayMerchantId,
    required this.enablePlatformPay,
    required this.stripeUrlScheme,
    required this.stripePercentFee,
    required this.stripeFixedFee,
    required this.commissionRate,
  });

  final String apiBaseUrl;
  final String apiFallbackIp;
  final String merchantCountryCode;
  final String applePayMerchantId;
  final bool enablePlatformPay;
  final String stripeUrlScheme;
  final double stripePercentFee;
  final double stripeFixedFee;
  final double commissionRate;

  static const defaults = AppRuntimeConfig(
    apiBaseUrl: kApiBaseUrl,
    apiFallbackIp: kApiFallbackIp,
    merchantCountryCode: kMerchantCountryCode,
    applePayMerchantId: kApplePayMerchantId,
    enablePlatformPay: kEnablePlatformPay,
    stripeUrlScheme: kStripeUrlScheme,
    stripePercentFee: 1.5,
    stripeFixedFee: 0.25,
    commissionRate: 15.0,
  );

  Map<String, dynamic> toJson() => {
    'api_base_url': apiBaseUrl,
    'api_fallback_ip': apiFallbackIp,
    'merchant_country_code': merchantCountryCode,
    'apple_pay_merchant_id': applePayMerchantId,
    'enable_platform_pay': enablePlatformPay,
    'stripe_url_scheme': stripeUrlScheme,
    'stripe_percent_fee': stripePercentFee,
    'stripe_fixed_fee': stripeFixedFee,
    'commission_rate': commissionRate,
  };

  factory AppRuntimeConfig.fromJson(
    Map<String, dynamic> json,
  ) => AppRuntimeConfig(
    apiBaseUrl: (json['api_base_url'] as String? ?? defaults.apiBaseUrl).trim(),
    apiFallbackIp:
        (json['api_fallback_ip'] as String? ?? defaults.apiFallbackIp).trim(),
    merchantCountryCode:
        (json['merchant_country_code'] as String? ??
                defaults.merchantCountryCode)
            .trim(),
    applePayMerchantId:
        (json['apple_pay_merchant_id'] as String? ??
                defaults.applePayMerchantId)
            .trim(),
    enablePlatformPay: json.containsKey('enable_platform_pay')
        ? (json['enable_platform_pay'] == true ||
              json['enable_platform_pay'] == 1)
        : defaults.enablePlatformPay,
    stripeUrlScheme:
        (json['stripe_url_scheme'] as String? ?? defaults.stripeUrlScheme)
            .trim(),
    stripePercentFee:
        (json['stripe_percent_fee'] as num?)?.toDouble() ??
        defaults.stripePercentFee,
    stripeFixedFee:
        (json['stripe_fixed_fee'] as num?)?.toDouble() ??
        defaults.stripeFixedFee,
    commissionRate:
        (json['commission_rate'] as num?)?.toDouble() ??
        defaults.commissionRate,
  );

  AppRuntimeConfig copyWith({
    String? apiBaseUrl,
    String? apiFallbackIp,
    String? merchantCountryCode,
    String? applePayMerchantId,
    bool? enablePlatformPay,
    String? stripeUrlScheme,
    double? stripePercentFee,
    double? stripeFixedFee,
    double? commissionRate,
  }) => AppRuntimeConfig(
    apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
    apiFallbackIp: apiFallbackIp ?? this.apiFallbackIp,
    merchantCountryCode: merchantCountryCode ?? this.merchantCountryCode,
    applePayMerchantId: applePayMerchantId ?? this.applePayMerchantId,
    enablePlatformPay: enablePlatformPay ?? this.enablePlatformPay,
    stripeUrlScheme: stripeUrlScheme ?? this.stripeUrlScheme,
    stripePercentFee: stripePercentFee ?? this.stripePercentFee,
    stripeFixedFee: stripeFixedFee ?? this.stripeFixedFee,
    commissionRate: commissionRate ?? this.commissionRate,
  );
}

final appRuntimeConfigProvider = StateProvider<AppRuntimeConfig>(
  (_) => AppRuntimeConfig.defaults,
);
final guestSessionProvider = StateProvider<GuestSession?>((_) => null);
final staffTokenProvider = StateProvider<String?>((_) => null);
final staffUserProvider = StateProvider<StaffUser?>((_) => null);
final offlineHostSessionProvider = StateProvider<OfflineHostSession?>(
  (_) => null,
);
final apiProvider = Provider<ApiService>(
  (ref) => ApiService(ref.watch(appRuntimeConfigProvider)),
);
final cartProvider = StateNotifierProvider<CartNotifier, Map<int, CartItem>>(
  (_) => CartNotifier(),
);
final savedOrdersProvider =
    StateNotifierProvider<SavedOrdersNotifier, List<String>>(
      (_) => SavedOrdersNotifier(),
    );
final wantsFilmProvider = StateProvider<bool>((_) => false);

const String kStaffLastRouteKey = 'staff_last_route';
const String kStaffLastRouteUserKey = 'staff_last_route_user_id';
const String kStaffBackupTokenKey = 'staff_token_backup';
const String kStaffBackupUserKey = 'staff_user_backup';
const String kStaffBackupRouteKey = 'staff_route_backup';
const String kRuntimeConfigBackupKey = 'runtime_config_backup';

class Studio59App extends ConsumerStatefulWidget {
  const Studio59App({super.key});

  @override
  ConsumerState<Studio59App> createState() => _Studio59AppState();
}

class _Studio59AppState extends ConsumerState<Studio59App> {
  final _navKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _appLinkSub;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    var config = await readAppRuntimeConfig();
    final offline = await readOfflineHostSession();
    if (offline != null) {
      ref.read(offlineHostSessionProvider.notifier).state = offline;
      if (offline.isActive && isDesktopPlatform()) {
        try {
          final started = await OfflineHostServer.instance.start(offline);
          ref.read(offlineHostSessionProvider.notifier).state = started.session;
          config = config.copyWith(
            apiBaseUrl: started.localApiBaseUrl,
            apiFallbackIp: '',
          );
          await saveAppRuntimeConfig(config);
        } catch (_) {}
      }
    } else if (looksLikeLocalApiBaseUrl(config.apiBaseUrl)) {
      final backupConfig = await restoreBackedUpRuntimeConfig();
      final fallbackConfig = backupConfig ?? AppRuntimeConfig.defaults;
      final fallbackReachable = await ApiService(fallbackConfig).pingPublic();
      if (fallbackReachable) {
        config = fallbackConfig;
        await saveAppRuntimeConfig(config);
        await clearBackedUpRuntimeConfig();
      }
    }
    ref.read(appRuntimeConfigProvider.notifier).state = config;
    ref.invalidate(apiProvider);
    await _initAppLinks();
    if (mounted) {
      setState(() => _booting = false);
    }
  }

  Future<void> _initAppLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _handleAppLink(initial);
      }
    } catch (_) {}
    _appLinkSub = _appLinks.uriLinkStream.listen(
      _handleAppLink,
      onError: (_) {},
    );
  }

  void _handleAppLink(Uri uri) {
    if (uri.scheme != ref.read(appRuntimeConfigProvider).stripeUrlScheme)
      return;
    if (uri.host != 'checkout') return;
    final orderCode =
        uri.queryParameters['order_code'] ?? uri.queryParameters['order'] ?? '';
    if (orderCode.isEmpty) return;
    final nav = _navKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => TicketPage(orderCode: orderCode)),
      (route) => route.isFirst,
    );
  }

  @override
  void dispose() {
    _appLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    final baseScheme = ColorScheme.fromSeed(
      seedColor: kBrandRose,
      brightness: Brightness.dark,
    );
    final colorScheme = baseScheme.copyWith(
      primary: kBrandRose,
      onPrimary: kBrandBlack,
      secondary: kBrandRose,
      onSecondary: kBrandBlack,
      background: kBrandBlack,
      onBackground: kBrandRose,
      surface: kBrandBlack,
      onSurface: kBrandRose,
      outline: kBrandRose,
      surfaceTint: kBrandRose,
      error: kBrandRose,
      onError: kBrandBlack,
    );

    return MaterialApp(
      title: 'Studio 59',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: kBrandBlack,
        fontFamily: '.SF Pro Text',
        fontFamilyFallback: const [
          'SF Pro Text',
          'SF Pro Display',
          'Helvetica Neue',
          'Arial',
        ],
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          },
        ),
        cupertinoOverrideTheme: CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: kBrandRose,
          scaffoldBackgroundColor: kBrandBlack,
          barBackgroundColor: kBrandBlack,
          textTheme: CupertinoTextThemeData(primaryColor: kBrandRose),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBrandBlack,
          foregroundColor: kBrandRose,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: kBrandBlack,
          elevation: 8,
          shadowColor: kBrandRose.withOpacity(0.2),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kBrandRose),
          ),
        ),
        dividerTheme: const DividerThemeData(color: kBrandRose),
        iconTheme: const IconThemeData(color: kBrandRose),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: kBrandRose,
          displayColor: kBrandRose,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kBrandBlack,
          hintStyle: TextStyle(color: kBrandRose.withOpacity(0.6)),
          labelStyle: const TextStyle(color: kBrandRose),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kBrandRose),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kBrandRose, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kBrandBlack,
            foregroundColor: kBrandRose,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: kBrandRose),
            ),
            elevation: 6,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kBrandRose,
            side: const BorderSide(color: kBrandRose),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: kBrandRose),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kBrandRose,
            foregroundColor: kBrandBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: kBrandBlack,
          contentTextStyle: TextStyle(color: kBrandRose),
          actionTextColor: kBrandRose,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: kBrandBlack,
          titleTextStyle: TextStyle(
            color: kBrandRose,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          contentTextStyle: TextStyle(color: kBrandRose),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.skipStaffAutoOpen = false});
  final bool skipStaffAutoOpen;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final MobileScannerController _qrController = MobileScannerController();
  final TextEditingController _pinCtrl = TextEditingController();
  bool _showScanner = false;
  bool _handlingScan = false;
  bool _pinSubmitting = false;
  bool _discoveringOffline = false;
  bool _showOfflineDiscovery = false;
  int _logoTapCount = 0;
  DateTime? _firstTapAt;
  bool _autoOpenedStaff = false;
  OfflineDiscoveryResult? _offlineDiscovery;
  String? _offlineDiscoveryError;

  @override
  void initState() {
    super.initState();
    _restoreStaffSession();
    _pinCtrl.addListener(_handlePinInput);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _discoverOfflineSession();
    });
  }

  @override
  void dispose() {
    _qrController.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreStaffSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('staff_token');
      final userRaw = prefs.getString('staff_user');
      if (token == null || userRaw == null) return;
      var onlineReachable = await ref.read(apiProvider).pingPublic();
      if (!onlineReachable) {
        onlineReachable = await _tryRestoreOnlineRuntimeConfig();
      }
      if (!onlineReachable) {
        ref.read(staffTokenProvider.notifier).state = null;
        ref.read(staffUserProvider.notifier).state = null;
        await clearStaffSession();
        return;
      }
      final decoded = jsonDecode(userRaw);
      if (decoded is! Map) return;
      final user = StaffUser.fromJson(decoded.cast<String, dynamic>());
      ref.read(staffTokenProvider.notifier).state = token;
      ref.read(staffUserProvider.notifier).state = user;
      if (!widget.skipStaffAutoOpen && !_autoOpenedStaff) {
        _autoOpenedStaff = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openStaffRoute(replace: true);
        });
      }
    } catch (_) {
      // ignore stored session errors
    }
  }

  Future<bool> _tryRestoreOnlineRuntimeConfig() async {
    final current = ref.read(appRuntimeConfigProvider);
    if (!looksLikeLocalApiBaseUrl(current.apiBaseUrl)) return false;
    final backupConfig = await restoreBackedUpRuntimeConfig();
    final fallbackConfig = backupConfig ?? AppRuntimeConfig.defaults;
    final backupReachable = await ApiService(fallbackConfig).pingPublic();
    if (!backupReachable) return false;
    await saveAppRuntimeConfig(fallbackConfig);
    ref.read(appRuntimeConfigProvider.notifier).state = fallbackConfig;
    ref.invalidate(apiProvider);
    await clearBackedUpRuntimeConfig();
    return true;
  }

  Future<void> _applyOfflineApiBaseUrl(
    String apiBaseUrl, {
    bool persist = false,
  }) async {
    final current = ref.read(appRuntimeConfigProvider);
    if (current.apiBaseUrl == apiBaseUrl) return;
    if (persist && !looksLikeLocalApiBaseUrl(current.apiBaseUrl)) {
      await backupRuntimeConfig(current);
    }
    final next = current.copyWith(apiBaseUrl: apiBaseUrl, apiFallbackIp: '');
    if (persist) {
      await saveAppRuntimeConfig(next);
    }
    ref.read(appRuntimeConfigProvider.notifier).state = next;
    ref.invalidate(apiProvider);
    ref.read(staffTokenProvider.notifier).state = null;
    ref.read(staffUserProvider.notifier).state = null;
    await clearStaffSession();
  }

  Future<void> _applyOfflineDiscovery(OfflineDiscoveryResult discovery) async {
    await _applyOfflineApiBaseUrl(
      discovery.serverUrl,
      persist: isDesktopPlatform(),
    );
  }

  Future<OfflineDiscoveryResult?> _currentOfflineDiscovery() async {
    final config = ref.read(appRuntimeConfigProvider);
    if (!looksLikeLocalApiBaseUrl(config.apiBaseUrl)) return null;
    if (!await ref.read(apiProvider).pingPublic()) return null;
    String eventName = 'Sessão offline ativa';
    try {
      final events = await ref.read(apiProvider).todayEvents();
      if (events.isNotEmpty) {
        eventName = events.first.name;
      }
    } catch (_) {}
    final uri = Uri.tryParse(config.apiBaseUrl);
    return OfflineDiscoveryResult(
      serverUrl: config.apiBaseUrl,
      eventName: eventName,
      sessionId: '',
      qrUrl: '',
      host: uri?.host ?? '',
      port: uri?.hasPort == true ? uri!.port : 80,
      candidateUrls: [config.apiBaseUrl],
    );
  }

  Future<bool> _ensureOfflineAccess({String? qrRaw}) async {
    if (await ref.read(apiProvider).pingPublic()) {
      return true;
    }
    if (qrRaw != null && qrRaw.trim().isNotEmpty) {
      await _maybeApplyQrRuntimeConfig(qrRaw);
      if (await ref.read(apiProvider).pingPublic()) {
        return true;
      }
    }
    if (_offlineDiscovery != null) {
      await _applyOfflineDiscovery(_offlineDiscovery!);
      if (await ref.read(apiProvider).pingPublic()) {
        return true;
      }
    }
    final discovery = await discoverOfflineSession(
      timeout: const Duration(seconds: 4),
    );
    if (discovery == null) return false;
    await _applyOfflineDiscovery(discovery);
    if (!mounted) return false;
    setState(() {
      _offlineDiscovery = discovery;
      _offlineDiscoveryError = null;
    });
    return ref.read(apiProvider).pingPublic();
  }

  Future<void> _discoverOfflineSession({bool manual = false}) async {
    if (_discoveringOffline) return;
    setState(() {
      _discoveringOffline = true;
      if (manual) _offlineDiscoveryError = null;
    });
    try {
      final currentOffline = await _currentOfflineDiscovery();
      if (currentOffline != null) {
        if (!mounted) return;
        setState(() {
          _discoveringOffline = false;
          _showOfflineDiscovery = true;
          _offlineDiscovery = currentOffline;
          _offlineDiscoveryError = null;
        });
        return;
      }
      final onlineReachable = await ref.read(apiProvider).pingPublic();
      if (onlineReachable) {
        if (!mounted) return;
        setState(() {
          _discoveringOffline = false;
          _showOfflineDiscovery = false;
          _offlineDiscovery = null;
          _offlineDiscoveryError = null;
        });
        return;
      }
      if (await _tryRestoreOnlineRuntimeConfig()) {
        if (!mounted) return;
        setState(() {
          _discoveringOffline = false;
          _showOfflineDiscovery = false;
          _offlineDiscovery = null;
          _offlineDiscoveryError = null;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _showOfflineDiscovery = true;
      });
      final discovery = await discoverOfflineSession(
        timeout: manual
            ? const Duration(seconds: 4)
            : const Duration(seconds: 2),
      );
      if (!mounted) return;
      if (discovery == null) {
        setState(() {
          _discoveringOffline = false;
          _showOfflineDiscovery = true;
          _offlineDiscovery = null;
          _offlineDiscoveryError = 'Nenhuma sessão offline encontrada.';
        });
        return;
      }
      await _applyOfflineDiscovery(discovery);
      if (!mounted) return;
      setState(() {
        _discoveringOffline = false;
        _showOfflineDiscovery = true;
        _offlineDiscovery = discovery;
        _offlineDiscoveryError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _discoveringOffline = false;
        _showOfflineDiscovery = true;
        _offlineDiscoveryError = e.toString();
      });
    }
  }

  Future<void> _maybeApplyQrRuntimeConfig(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !uri.path.contains('/api/public/events/qr/'))
      return;
    final apiPath = uri.path.substring(
      0,
      uri.path.indexOf('/public/events/qr/'),
    );
    final apiBaseUrl = uri
        .replace(path: apiPath, query: null, fragment: null)
        .toString();
    if (!looksLikeLocalApiBaseUrl(apiBaseUrl)) return;
    await _applyOfflineApiBaseUrl(apiBaseUrl);
  }

  Future<void> _enterByQrToken(String raw) async {
    try {
      final ready = await _ensureOfflineAccess(qrRaw: raw);
      if (!ready) {
        throw Exception('Não foi possível ligar à sessão offline.');
      }
      final token = extractQrToken(raw);
      final session = await ref.read(apiProvider).enterEventByQr(token);
      ref.read(guestSessionProvider.notifier).state = session;
      ref.read(cartProvider.notifier).clear();
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GuestCatalogPage(eventId: session.eventId),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao entrar: $e')));
    }
  }

  Future<void> _enterByPin(String pin) async {
    try {
      final ready = await _ensureOfflineAccess();
      if (!ready) {
        throw Exception('Não foi possível ligar à sessão offline.');
      }
      final session = await ref.read(apiProvider).enterEventByPin(pin);
      ref.read(guestSessionProvider.notifier).state = session;
      ref.read(cartProvider.notifier).clear();
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GuestCatalogPage(eventId: session.eventId),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao entrar: $e')));
    }
  }

  void _handlePinInput() {
    final pin = _pinCtrl.text.trim();
    if (pin.length != 4 || _pinSubmitting) return;
    _pinSubmitting = true;
    _enterByPin(pin).whenComplete(() {
      _pinSubmitting = false;
    });
  }

  void _handleLogoTap() {
    final now = DateTime.now();
    if (_firstTapAt == null ||
        now.difference(_firstTapAt!) > const Duration(seconds: 3)) {
      _firstTapAt = now;
      _logoTapCount = 1;
    } else {
      _logoTapCount += 1;
    }

    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      _firstTapAt = null;
      _openStaffEntry();
    }
  }

  Future<void> _openStaffEntry() async {
    final staffToken = ref.read(staffTokenProvider);
    final staffUser = ref.read(staffUserProvider);
    if (staffToken != null && staffUser != null) {
      if (!mounted) return;
      await _openStaffRoute();
      return;
    }

    final result = await Navigator.push<StaffAuthResponse?>(
      context,
      MaterialPageRoute(builder: (_) => const StaffLoginPage()),
    );
    if (result == null) return;
    ref.read(staffTokenProvider.notifier).state = result.token;
    ref.read(staffUserProvider.notifier).state = result.user;
    await saveStaffSession(result.token, result.user);
    if (!mounted) return;
    await saveStaffLastRoute('dashboard', userId: result.user.id);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
    );
  }

  Future<void> _openStaffRoute({bool replace = false}) async {
    final user = ref.read(staffUserProvider);
    final lastRoute = await readStaffLastRoute(userId: user?.id);
    Widget target;
    switch (lastRoute) {
      case 'events':
        target = const StaffEventsPage();
        break;
      case 'uploads':
        target = const StaffUploadsPage();
        break;
      case 'photos':
        target = const StaffPhotosPage();
        break;
      case 'orders':
        target = const StaffOrdersPage();
        break;
      case 'settings':
        target = const StaffSettingsPage();
        break;
      case 'app-config':
        target = const StaffAppConfigPage();
        break;
      case 'users':
        target = const StaffUsersPage();
        break;
      case 'clients':
        target = const StaffClientsPage();
        break;
      case 'sync':
        target = const StaffSyncPage();
        break;
      case 'offline-host':
        target = const StaffOfflineHostPage();
        break;
      case 'dashboard':
      default:
        target = const StaffDashboardPage();
        break;
    }
    if (!mounted) return;
    if (replace) {
      if (lastRoute != null && lastRoute != 'dashboard') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.push(context, MaterialPageRoute(builder: (_) => target));
        });
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => target),
        );
      }
    } else {
      if (lastRoute != null && lastRoute != 'dashboard') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.push(context, MaterialPageRoute(builder: (_) => target));
        });
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => target));
      }
    }
  }

  void _onQrDetect(BarcodeCapture capture) {
    if (_handlingScan) return;
    final raw = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (raw == null || raw.trim().isEmpty) return;
    _handlingScan = true;
    _enterByQrToken(raw).whenComplete(() {
      _handlingScan = false;
      if (mounted) {
        setState(() => _showScanner = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _handleLogoTap,
                      child: Image.asset(
                        'assets/app_icon.png',
                        width: 72,
                        height: 72,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Studio 59',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (_showOfflineDiscovery ||
                  _offlineDiscovery != null ||
                  _discoveringOffline ||
                  _offlineDiscoveryError != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: kBrandRose.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _offlineDiscovery != null
                            ? 'Sessão offline encontrada'
                            : (_discoveringOffline
                                  ? 'A procurar sessão offline...'
                                  : 'Offline'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (_offlineDiscovery != null) ...[
                        const SizedBox(height: 6),
                        Text(_offlineDiscovery!.eventName),
                        Text(
                          _offlineDiscovery!.serverUrl,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      if (_offlineDiscoveryError != null) ...[
                        const SizedBox(height: 6),
                        Text(_offlineDiscoveryError!),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (isDesktopPlatform() &&
                                _offlineDiscovery == null &&
                                !_discoveringOffline)
                              OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const OfflineBootstrapPage(),
                                  ),
                                ),
                                icon: const Icon(Icons.wifi_tethering),
                                label: const Text('Criar sessão offline'),
                              ),
                            OutlinedButton.icon(
                              onPressed: _discoveringOffline
                                  ? null
                                  : () => _discoverOfflineSession(manual: true),
                              icon: _discoveringOffline
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh),
                              label: const Text('Atualizar'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              GestureDetector(
                onTap: () {
                  if (!_showScanner) {
                    setState(() => _showScanner = true);
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: _showScanner
                        ? MobileScanner(
                            controller: _qrController,
                            onDetect: _onQrDetect,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.qr_code_2, size: 86),
                              SizedBox(height: 8),
                              Text('Ler QR Code'),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _pinCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, letterSpacing: 6),
                decoration: const InputDecoration(
                  hintText: 'PIN',
                  border: UnderlineInputBorder(),
                  enabledBorder: UnderlineInputBorder(),
                  focusedBorder: UnderlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

String extractQrToken(String raw) {
  final trimmed = raw.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.pathSegments.isNotEmpty) {
    final idx = uri.pathSegments.indexOf('qr');
    if (idx != -1 && idx + 1 < uri.pathSegments.length) {
      return uri.pathSegments[idx + 1];
    }
    if (uri.pathSegments.length == 1) {
      return uri.pathSegments.first;
    }
  }
  return trimmed;
}

void showQrDialog(
  BuildContext context, {
  required String title,
  required String url,
}) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: kBrandRose,
              padding: const EdgeInsets.all(8),
              child: QrImageView(
                data: url,
                size: 220,
                backgroundColor: kBrandRose,
                foregroundColor: kBrandBlack,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              url,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );
}

PreferredSizeWidget buildNavAppBar(
  BuildContext context,
  String title, {
  List<Widget> actions = const [],
}) {
  return AppBar(
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
    ),
    leading: navLeading(context),
    actions: navActions(context, extra: actions),
    scrolledUnderElevation: 0,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              kBrandRose.withOpacity(0.35),
              Colors.transparent,
            ],
          ),
        ),
      ),
    ),
  );
}

Widget? navLeading(BuildContext context) {
  final canPop = Navigator.of(context).canPop();
  if (!canPop) return null;
  return IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => Navigator.maybePop(context),
    tooltip: 'Voltar',
  );
}

List<Widget> navActions(BuildContext context, {List<Widget> extra = const []}) {
  return [...extra];
}

Future<String> getDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString('device_id');
  if (existing != null && existing.isNotEmpty) return existing;
  final id = const Uuid().v4();
  await prefs.setString('device_id', id);
  return id;
}

Future<AppRuntimeConfig> readAppRuntimeConfig() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kRuntimeConfigKey);
  if (raw == null || raw.trim().isEmpty) return AppRuntimeConfig.defaults;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return AppRuntimeConfig.fromJson(decoded);
    }
    if (decoded is Map) {
      return AppRuntimeConfig.fromJson(decoded.cast<String, dynamic>());
    }
  } catch (_) {}
  return AppRuntimeConfig.defaults;
}

Future<void> saveAppRuntimeConfig(AppRuntimeConfig config) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kRuntimeConfigKey, jsonEncode(config.toJson()));
}

Future<void> clearAppRuntimeConfig() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kRuntimeConfigKey);
}

Future<void> saveStaffSession(String token, StaffUser user) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('staff_token', token);
  await prefs.setInt(kStaffLastRouteUserKey, user.id);
  await prefs.setString(
    'staff_user',
    jsonEncode({
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'role': user.role,
      'permissions': user.permissions,
      'username': user.username,
    }),
  );
}

Future<void> clearStaffSession() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('staff_token');
  await prefs.remove('staff_user');
  await prefs.remove(kStaffLastRouteKey);
  await prefs.remove(kStaffLastRouteUserKey);
}

Future<void> backupCurrentStaffSession() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('staff_token');
  final user = prefs.getString('staff_user');
  if (token == null || user == null) return;
  await prefs.setString(kStaffBackupTokenKey, token);
  await prefs.setString(kStaffBackupUserKey, user);
  final route = prefs.getString(kStaffLastRouteKey);
  if (route != null && route.isNotEmpty) {
    await prefs.setString(kStaffBackupRouteKey, route);
  }
}

Future<StaffAuthResponse?> restoreBackedUpStaffSession() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(kStaffBackupTokenKey);
  final userRaw = prefs.getString(kStaffBackupUserKey);
  if (token == null || userRaw == null) return null;
  try {
    final decoded = jsonDecode(userRaw);
    if (decoded is Map<String, dynamic>) {
      return StaffAuthResponse(token: token, user: StaffUser.fromJson(decoded));
    }
    if (decoded is Map) {
      return StaffAuthResponse(
        token: token,
        user: StaffUser.fromJson(decoded.cast<String, dynamic>()),
      );
    }
  } catch (_) {}
  return null;
}

Future<void> clearBackedUpStaffSession() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kStaffBackupTokenKey);
  await prefs.remove(kStaffBackupUserKey);
  await prefs.remove(kStaffBackupRouteKey);
}

Future<void> backupRuntimeConfig(AppRuntimeConfig config) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kRuntimeConfigBackupKey, jsonEncode(config.toJson()));
}

Future<AppRuntimeConfig?> restoreBackedUpRuntimeConfig() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kRuntimeConfigBackupKey);
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return AppRuntimeConfig.fromJson(decoded);
    }
    if (decoded is Map) {
      return AppRuntimeConfig.fromJson(decoded.cast<String, dynamic>());
    }
  } catch (_) {}
  return null;
}

Future<void> clearBackedUpRuntimeConfig() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kRuntimeConfigBackupKey);
}

Future<void> saveStaffLastRoute(String route, {int? userId}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kStaffLastRouteKey, route);
  if (userId != null) {
    await prefs.setInt(kStaffLastRouteUserKey, userId);
  }
}

Future<String?> readStaffLastRoute({int? userId}) async {
  final prefs = await SharedPreferences.getInstance();
  final storedUserId = prefs.getInt(kStaffLastRouteUserKey);
  if (userId != null && storedUserId != null && storedUserId != userId) {
    return null;
  }
  return prefs.getString(kStaffLastRouteKey);
}

Future<File> _offlineFileForEvent(int eventId) async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/offline_event_$eventId.json');
}

Future<Map<String, dynamic>> _readOfflinePayload(int eventId) async {
  final file = await _offlineFileForEvent(eventId);
  if (!await file.exists()) {
    return {'event_id': eventId, 'orders': []};
  }
  final raw = await file.readAsString();
  final data = jsonDecode(raw);
  if (data is Map<String, dynamic>) return data;
  return {'event_id': eventId, 'orders': []};
}

Future<void> _writeOfflinePayload(
  int eventId,
  Map<String, dynamic> payload,
) async {
  final file = await _offlineFileForEvent(eventId);
  await file.writeAsString(jsonEncode(payload));
}

Future<void> enqueueOfflineOrder(
  int eventId,
  Map<String, dynamic> order,
) async {
  final payload = await _readOfflinePayload(eventId);
  final orders = (payload['orders'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  orders.add(order);
  payload['event_id'] = eventId;
  payload['orders'] = orders;
  payload['selections'] ??= [];
  payload['order_updates'] ??= [];
  final clients = (payload['clients'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  final email = order['customer_email']?.toString().trim();
  final phone = order['customer_phone']?.toString().trim();
  if ((email != null && email.isNotEmpty) ||
      (phone != null && phone.isNotEmpty)) {
    final exists = clients.any(
      (c) =>
          (email != null && c['email'] == email) ||
          (phone != null && c['phone'] == phone),
    );
    if (!exists) {
      clients.add({
        'name': order['customer_name'] ?? 'Cliente',
        'email': email,
        'phone': phone,
      });
    }
  }
  payload['clients'] = clients;
  payload['device_id'] ??= await getDeviceId();
  payload['exported_at'] = DateTime.now().toIso8601String();
  await _writeOfflinePayload(eventId, payload);
}

Future<void> enqueueSelection(int eventId, int photoId, String status) async {
  final payload = await _readOfflinePayload(eventId);
  final selections = (payload['selections'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  selections.add({
    'uuid': const Uuid().v4(),
    'event_id': eventId,
    'device_id': await getDeviceId(),
    'photo_id': photoId,
    'status': status,
    'selected_at': DateTime.now().toIso8601String(),
  });
  payload['selections'] = selections;
  payload['orders'] ??= [];
  payload['order_updates'] ??= [];
  payload['clients'] ??= [];
  await _writeOfflinePayload(eventId, payload);
}

Future<void> enqueueOrderUpdate(
  int eventId,
  int orderId,
  String status, {
  num? cashReceivedAmount,
  num? cashChangeAmount,
  bool? cashChangeGiven,
  num? cashDueAmount,
  String? notes,
}) async {
  final payload = await _readOfflinePayload(eventId);
  final updates = (payload['order_updates'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  updates.add({
    'uuid': const Uuid().v4(),
    'event_id': eventId,
    'order_id': orderId,
    'status': status,
    'cash_received_amount': cashReceivedAmount,
    'cash_change_amount': cashChangeAmount,
    'cash_change_given': cashChangeGiven,
    'cash_due_amount': cashDueAmount,
    'notes': notes,
    'updated_at': DateTime.now().toIso8601String(),
  });
  payload['order_updates'] = updates;
  payload['orders'] ??= [];
  payload['selections'] ??= [];
  payload['clients'] ??= [];
  await _writeOfflinePayload(eventId, payload);
}

Future<Map<String, dynamic>> buildOfflinePayload(int eventId) async {
  final payload = await _readOfflinePayload(eventId);
  payload['device_id'] ??= await getDeviceId();
  payload['exported_at'] = DateTime.now().toIso8601String();
  payload['orders'] ??= [];
  payload['selections'] ??= [];
  payload['order_updates'] ??= [];
  payload['clients'] ??= [];
  return payload;
}

Future<void> clearOfflineQueue(int eventId) async {
  final file = await _offlineFileForEvent(eventId);
  if (await file.exists()) {
    await file.delete();
  }
}

Future<File> writeOfflineExportFile(
  int eventId,
  Map<String, dynamic> payload,
) async {
  final dir = await getApplicationDocumentsDirectory();
  final path =
      '${dir.path}/offline_export_${eventId}_${DateTime.now().millisecondsSinceEpoch}.json';
  final file = File(path);
  await file.writeAsString(jsonEncode(payload));
  return file;
}

const Set<String> kOfflinePhotoExtensions = {'jpg', 'jpeg'};

List<String> listOfflinePhotoPathsFromDirectory(String directoryPath) {
  final dir = Directory(directoryPath);
  if (!dir.existsSync()) return const [];
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((file) {
            final ext = path
                .extension(file.path)
                .toLowerCase()
                .replaceFirst('.', '');
            return kOfflinePhotoExtensions.contains(ext);
          })
          .map((file) => file.path)
          .toList()
        ..sort();
  return files;
}

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (raw == null || raw.trim().isEmpty) return;
    _handled = true;
    final token = extractQrToken(raw);
    Navigator.pop(context, token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildNavAppBar(context, 'Ler QR Code'),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.tonal(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GuestCatalogPage extends ConsumerStatefulWidget {
  final int eventId;
  const GuestCatalogPage({super.key, required this.eventId});

  @override
  ConsumerState<GuestCatalogPage> createState() => _GuestCatalogPageState();
}

class _GuestCatalogPageState extends ConsumerState<GuestCatalogPage> {
  final searchController = TextEditingController();
  String search = '';
  List<PhotoItem> suggested = [];
  bool faceSearching = false;
  int page = 1;
  static const int perPage = 24;
  static const int _offlineCatalogPageSize = 200;
  static const int _offlinePreviewWidth = 640;
  static const int _offlinePreviewDownloadParallelism = 4;
  Future<PhotosPage>? _photosFuture;
  String? _photosCacheToken;
  bool _offlineCatalogMode = false;
  bool _offlineCatalogLoading = false;
  double _offlineCatalogProgress = 0;
  String? _offlineCatalogStatus;
  List<PhotoItem> _offlineCatalogPhotos = const [];
  Map<int, String> _offlinePreviewFiles = const {};

  @override
  void dispose() {
    _releaseCatalogImageCache();
    searchController.dispose();
    super.dispose();
  }

  void _releaseCatalogImageCache() {
    if (_offlineCatalogMode) {
      return;
    }
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  Future<PhotosPage> _fetchPhotosPage(GuestSession session, int targetPage) {
    return ref.read(apiProvider).eventPhotosPage(
      widget.eventId,
      session.token,
      search: search,
      page: targetPage,
      perPage: perPage,
    );
  }

  void _loadPage(GuestSession session, int targetPage) {
    if (_offlineCatalogMode) {
      page = targetPage;
      _photosFuture = Future.value(_buildOfflinePhotosPage());
      return;
    }
    if (targetPage != page) {
      _releaseCatalogImageCache();
    }
    page = targetPage;
    _photosFuture = _fetchPhotosPage(session, targetPage);
  }

  void _refreshPhotosForSearch(GuestSession session, String value) {
    setState(() {
      search = value.trim();
      page = 1;
      if (_offlineCatalogMode) {
        _photosFuture = Future.value(_buildOfflinePhotosPage());
      } else {
        _releaseCatalogImageCache();
        _loadPage(session, 1);
      }
    });
  }

  void _goToPage(GuestSession session, int next, int lastPage) {
    if (next < 1 || next > lastPage || next == page) return;
    setState(() => _loadPage(session, next));
  }

  Future<Directory> _offlineCatalogCacheDir() async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory(
      path.join(dir.path, 'studio59_offline_catalog', '${widget.eventId}'),
    );
    await cacheDir.create(recursive: true);
    return cacheDir;
  }

  File _offlinePreviewFileFor(Directory cacheDir, PhotoItem photo) {
    return File(
      path.join(
        cacheDir.path,
        'p_${photo.id}_${photo.number}_w$_offlinePreviewWidth.jpg',
      ),
    );
  }

  PhotosPage _buildOfflinePhotosPage() {
    final filtered = search.isEmpty
        ? _offlineCatalogPhotos
        : _offlineCatalogPhotos
              .where((photo) => photo.number.toLowerCase().contains(search))
              .toList();
    final total = filtered.length;
    final lastPage = total == 0 ? 1 : ((total - 1) ~/ perPage) + 1;
    final safePage = page.clamp(1, lastPage).toInt();
    final start = (safePage - 1) * perPage;
    final items = start >= total
        ? const <PhotoItem>[]
        : filtered.skip(start).take(perPage).toList();
    page = safePage;
    return PhotosPage(
      items: items,
      total: total,
      currentPage: safePage,
      lastPage: lastPage,
      perPage: perPage,
    );
  }

  Future<List<PhotoItem>> _fetchAllOfflinePhotos(GuestSession session) async {
    final photos = <PhotoItem>[];
    var nextPage = 1;
    var lastPage = 1;
    do {
      final pageData = await ref.read(apiProvider).eventPhotosPage(
        widget.eventId,
        session.token,
        search: '',
        page: nextPage,
        perPage: _offlineCatalogPageSize,
      );
      photos.addAll(pageData.items);
      lastPage = pageData.lastPage;
      nextPage = pageData.currentPage + 1;
    } while (nextPage <= lastPage);
    return photos;
  }

  Future<File?> _cacheOfflinePreview(
    PhotoItem photo,
    Directory cacheDir,
  ) async {
    if (photo.previewUrl == null || photo.previewUrl!.isEmpty) {
      return null;
    }
    final file = _offlinePreviewFileFor(cacheDir, photo);
    if (await file.exists() && await file.length() > 0) {
      return file;
    }
    final uri = Uri.parse(
      previewUrlWithWidth(photo.previewUrl!, _offlinePreviewWidth),
    );
    for (var attempt = 0; attempt < 3; attempt++) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 20)
        ..idleTimeout = const Duration(seconds: 20)
        ..findProxy = (_) => 'DIRECT';
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          continue;
        }
        final bytes = await consolidateHttpClientResponseBytes(response);
        if (bytes.isEmpty) {
          continue;
        }
        await file.writeAsBytes(bytes, flush: false);
        return file;
      } catch (_) {
        if (attempt >= 2) {
          return null;
        }
      } finally {
        client.close(force: true);
      }
      await Future<void>.delayed(
        Duration(milliseconds: 200 * (attempt + 1)),
      );
    }
    return null;
  }

  Future<void> _prepareOfflineCatalog(GuestSession session) async {
    if (_offlineCatalogLoading) {
      return;
    }
    setState(() {
      _offlineCatalogLoading = true;
      _offlineCatalogProgress = 0;
      _offlineCatalogStatus = 'A carregar catálogo offline...';
      _offlineCatalogPhotos = const [];
      _offlinePreviewFiles = const {};
      _photosFuture = null;
    });
    try {
      final photos = await _fetchAllOfflinePhotos(session);
      final cacheDir = await _offlineCatalogCacheDir();
      final previewFiles = <int, String>{};
      final total = photos.length;
      var completed = 0;
      for (
        var i = 0;
        i < photos.length;
        i += _offlinePreviewDownloadParallelism
      ) {
        final batch = photos
            .skip(i)
            .take(_offlinePreviewDownloadParallelism)
            .toList();
        final results = await Future.wait(
          batch.map((photo) => _cacheOfflinePreview(photo, cacheDir)),
        );
        for (var j = 0; j < batch.length; j++) {
          final file = results[j];
          if (file != null) {
            previewFiles[batch[j].id] = file.path;
          }
          completed++;
        }
        if (!mounted) {
          return;
        }
        if (completed == total || completed % 16 == 0) {
          setState(() {
            _offlineCatalogProgress = total == 0 ? 1 : completed / total;
            _offlineCatalogStatus =
                'A preparar catálogo offline... $completed/$total';
          });
        }
      }
      final missing = photos
          .where((photo) => !previewFiles.containsKey(photo.id))
          .toList();
      for (final photo in missing) {
        final file = await _cacheOfflinePreview(photo, cacheDir);
        if (file != null) {
          previewFiles[photo.id] = file.path;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        page = 1;
        _offlineCatalogPhotos = photos;
        _offlinePreviewFiles = previewFiles;
        _offlineCatalogLoading = false;
        _offlineCatalogProgress = 1;
        _offlineCatalogStatus = 'Catálogo offline pronto.';
        _photosFuture = Future.value(_buildOfflinePhotosPage());
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _offlineCatalogLoading = false;
        _offlineCatalogStatus = null;
        _photosFuture = Future<PhotosPage>.error(e);
      });
    }
  }

  Widget _buildCatalogPreviewImage(PhotoItem photo, int previewCacheWidth) {
    final offlinePath = _offlinePreviewFiles[photo.id];
    if (_offlineCatalogMode &&
        offlinePath != null &&
        File(offlinePath).existsSync()) {
      return Image.file(
        File(offlinePath),
        fit: BoxFit.cover,
        width: double.infinity,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
      );
    }
    if (photo.previewUrl == null) {
      return const Center(child: Text('preview...'));
    }
    return Image.network(
      previewUrlWithWidth(photo.previewUrl!, 640),
      fit: BoxFit.cover,
      width: double.infinity,
      cacheWidth: previewCacheWidth,
      filterQuality: FilterQuality.low,
      errorBuilder: (context, error, stackTrace) =>
          const Center(child: Text('Sem preview')),
    );
  }

  void _openPhotoPreview(PhotoItem photo) {
    showDialog(
      context: context,
      builder: (_) {
        final selected = ref.watch(cartProvider).containsKey(photo.id);
        final size = MediaQuery.of(context).size;
        final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        final previewCacheWidth = max(
          1400,
          min(2400, (size.longestSide * devicePixelRatio).round()),
        );
        var rotationTurns = 0;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Foto ${photo.number}'),
            content: SizedBox(
              width: size.width * 0.9,
              height: size.height * 0.7,
              child: photo.previewUrl == null
                  ? const Center(child: Text('Sem preview'))
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 4,
                            child: Center(
                              child: RotatedBox(
                                quarterTurns: rotationTurns,
                                child: _offlineCatalogMode &&
                                        _offlinePreviewFiles[photo.id] != null &&
                                        File(_offlinePreviewFiles[photo.id]!)
                                            .existsSync()
                                    ? Image.file(
                                        File(_offlinePreviewFiles[photo.id]!),
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.medium,
                                      )
                                    : Image.network(
                                        previewUrlWithWidth(
                                          photo.previewUrl!,
                                          1280,
                                        ),
                                        fit: BoxFit.contain,
                                        cacheWidth: previewCacheWidth,
                                        filterQuality: FilterQuality.medium,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: Opacity(
                                opacity: 0.12,
                                child: Text(
                                  'STUDIO 59',
                                  style: TextStyle(
                                    fontSize: size.width * 0.12,
                                    fontWeight: FontWeight.w800,
                                    color: kBrandRose.withOpacity(0.7),
                                    letterSpacing: 4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    setState(() => rotationTurns = (rotationTurns + 1) % 4),
                child: const Text('Rodar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
              FilledButton(
                onPressed: () {
                  ref.read(cartProvider.notifier).toggle(photo);
                  Navigator.pop(context);
                },
                child: Text(selected ? 'Remover' : 'Selecionar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startFaceSearch(GuestSession session) async {
    if (faceSearching) return;
    final picker = ImagePicker();
    XFile? file;
    try {
      if (!Platform.isIOS) {
        var status = await Permission.camera.status;
        if (!status.isGranted) {
          status = await Permission.camera.request();
        }
        if (!status.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permissão de câmara não concedida.')),
          );
          return;
        }
      }
      file = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao abrir câmara: $e')));
      return;
    }
    if (file == null) return;

    setState(() => faceSearching = true);
    try {
      final results = await ref
          .read(apiProvider)
          .faceSearch(widget.eventId, session.token, file.path);
      setState(() => suggested = results);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro pesquisa facial: $e')));
    } finally {
      if (mounted) setState(() => faceSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(guestSessionProvider);
    if (session == null)
      return const Scaffold(body: Center(child: Text('Sessao expirada')));
    final offlineCatalogMode = looksLikeLocalApiBaseUrl(
      ref.read(appRuntimeConfigProvider).apiBaseUrl,
    );
    if (_photosCacheToken != session.token ||
        _offlineCatalogMode != offlineCatalogMode ||
        _photosFuture == null) {
      _photosCacheToken = session.token;
      _offlineCatalogMode = offlineCatalogMode;
      if (_offlineCatalogMode) {
        unawaited(_prepareOfflineCatalog(session));
      } else {
        _releaseCatalogImageCache();
        _loadPage(session, page);
      }
    }

    return SecureScreen(
      child: Scaffold(
        appBar: buildNavAppBar(
          context,
          session.eventName,
          actions: [
            if (session.qrToken != null && session.qrToken!.isNotEmpty)
              IconButton(
                onPressed: () {
                  final url = ref
                      .read(apiProvider)
                      .publicQrUrl(session.qrToken!);
                  showQrDialog(context, title: 'QR Code do Evento', url: url);
                },
                icon: const Icon(Icons.qr_code_2),
                tooltip: 'QR do evento',
              ),
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Detalhes do Evento'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          if (session.eventType != null &&
                              session.eventType!.isNotEmpty)
                            Text('Tipo: ${session.eventType}'),
                          if (session.eventDate != null &&
                              session.eventDate!.isNotEmpty)
                            Text(
                              'Data: ${_formatEventDateTime(session.eventDate!, null)}',
                            ),
                          if (session.basePrice != null)
                            Text('Preço base: ${session.basePrice}'),
                          Text('Preço por foto: ${session.pricePerPhoto}'),
                          const SizedBox(height: 8),
                          ...session.eventMeta.entries.map(
                            (e) => Text('${_prettyMetaKey(e.key)}: ${e.value}'),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fechar'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.info_outline),
              tooltip: 'Detalhes',
            ),
            IconButton(
              onPressed: faceSearching ? null : () => _startFaceSearch(session),
              icon: faceSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.face_retouching_natural),
              tooltip: 'Pesquisa facial',
            ),
            IconButton(
              onPressed: () {
                ref.read(cartProvider.notifier).clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Novo convidado pronto. Carrinho limpo.'),
                  ),
                );
              },
              icon: const Icon(Icons.cleaning_services),
              tooltip: 'Novo convidado / limpar sessao',
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: 'Pesquisar numero',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        _refreshPhotosForSearch(session, searchController.text),
                    icon: const Icon(Icons.search),
                  ),
                ),
                onSubmitted: (v) => _refreshPhotosForSearch(session, v),
              ),
            ),
            Expanded(
              child: FutureBuilder<PhotosPage>(
                future: _photosFuture,
                builder: (context, snap) {
                  if (_offlineCatalogMode && _offlineCatalogLoading) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(_offlineCatalogStatus ?? 'A preparar catálogo offline...'),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: _offlineCatalogProgress.clamp(0, 1).toDouble(),
                              minHeight: 10,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(_offlineCatalogProgress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    if (snap.hasError)
                      return Center(child: Text('Erro: ${snap.error}'));
                    return const Center(child: CircularProgressIndicator());
                  }
                  final pageData = snap.data!;
                  final photos = pageData.items;
                  final selected = ref.watch(cartProvider);
                  final suggestedIds = suggested.map((p) => p.id).toSet();
                  final previewCacheWidth = max(
                    420,
                    min(
                      720,
                      (MediaQuery.of(context).size.width /
                              3 *
                              MediaQuery.of(context).devicePixelRatio)
                          .round(),
                    ),
                  );
                  final remaining = photos
                      .where((p) => !suggestedIds.contains(p.id))
                      .toList();

                  Widget buildPhotoCard(PhotoItem photo) {
                    final isSelected = selected.containsKey(photo.id);
                    return Card(
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: InkWell(
                                    onTap: () => _openPhotoPreview(photo),
                                    child: _buildCatalogPreviewImage(
                                      photo,
                                      previewCacheWidth,
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Center(
                                      child: Opacity(
                                        opacity: 0.15,
                                        child: Text(
                                          'STUDIO 59',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: kBrandRose.withOpacity(0.7),
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: InkWell(
                                    onTap: () async {
                                      ref
                                          .read(cartProvider.notifier)
                                          .toggle(photo);
                                      final nowSelected = ref
                                          .read(cartProvider)
                                          .containsKey(photo.id);
                                      await enqueueSelection(
                                        widget.eventId,
                                        photo.id,
                                        nowSelected ? 'selected' : 'unselected',
                                      );
                                    },
                                    child: Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: isSelected
                                          ? kBrandRose
                                          : kBrandRose.withOpacity(0.6),
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  photo.number,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                  ),
                                  onPressed: () async {
                                    ref
                                        .read(cartProvider.notifier)
                                        .toggle(photo);
                                    final nowSelected = ref
                                        .read(cartProvider)
                                        .containsKey(photo.id);
                                    await enqueueSelection(
                                      widget.eventId,
                                      photo.id,
                                      nowSelected ? 'selected' : 'unselected',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  Widget pager() {
                    if (pageData.lastPage <= 1) return const SizedBox.shrink();
                    final last = pageData.lastPage;
                    final currentPage = pageData.currentPage;
                    final visiblePages = <Object>{};
                    visiblePages.add(1);
                    visiblePages.add(last);
                    for (var d = -2; d <= 2; d++) {
                      final p = currentPage + d;
                      if (p >= 1 && p <= last) visiblePages.add(p);
                    }
                    final sorted = visiblePages.cast<int>().toList()..sort();
                    final items = <Widget>[];
                    for (var i = 0; i < sorted.length; i++) {
                      if (i > 0 && sorted[i] - sorted[i - 1] > 1) {
                        items.add(
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '…',
                              style: TextStyle(color: kBrandRose),
                            ),
                          ),
                        );
                      }
                      final p = sorted[i];
                      final isCurrent = p == currentPage;
                      items.add(
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: OutlinedButton(
                            onPressed: () =>
                                _goToPage(session, p, pageData.lastPage),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isCurrent ? kBrandRose : null,
                              foregroundColor: isCurrent ? kBrandBlack : null,
                              side: BorderSide(
                                color: isCurrent
                                    ? kBrandRose
                                    : kBrandRose.withOpacity(0.6),
                              ),
                              minimumSize: const Size(40, 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                            child: Text('$p'),
                          ),
                        ),
                      );
                    }
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: currentPage > 1
                              ? () => _goToPage(
                                  session,
                                  currentPage - 1,
                                  pageData.lastPage,
                                )
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        ...items,
                        IconButton(
                          onPressed: currentPage < last
                              ? () => _goToPage(
                                  session,
                                  currentPage + 1,
                                  pageData.lastPage,
                                )
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'A mostrar ${pageData.total} fotos',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            pager(),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onHorizontalDragEnd: (details) {
                            final v = details.primaryVelocity ?? 0;
                            if (v > 300) {
                              _goToPage(
                                session,
                                pageData.currentPage - 1,
                                pageData.lastPage,
                              );
                            } else if (v < -300) {
                              _goToPage(
                                session,
                                pageData.currentPage + 1,
                                pageData.lastPage,
                              );
                            }
                          },
                          child: CustomScrollView(
                            slivers: [
                              if (suggested.isNotEmpty) ...[
                                const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(8, 4, 8, 6),
                                    child: Text(
                                      'SUGESTOES',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  sliver: SliverGrid(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, i) =>
                                          buildPhotoCard(suggested[i]),
                                      childCount: suggested.length,
                                    ),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          childAspectRatio: 0.72,
                                        ),
                                  ),
                                ),
                              ],
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(8, 8, 8, 6),
                                  child: Text(
                                    'TODAS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                sliver: SliverGrid(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, i) =>
                                        buildPhotoCard(remaining[i]),
                                    childCount: remaining.length,
                                  ),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        childAspectRatio: 0.72,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyOrdersPage()),
                  ),
                  child: const Text('Os meus pedidos'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CartPage(eventId: widget.eventId),
                    ),
                  ),
                  child: Consumer(
                    builder: (context, ref, child) {
                      final count = ref
                          .watch(cartProvider)
                          .values
                          .fold<int>(0, (sum, item) => sum + item.quantity);
                      return Text('Carrinho ($count)');
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CartPage extends ConsumerStatefulWidget {
  final int eventId;
  const CartPage({super.key, required this.eventId});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final session = ref.watch(guestSessionProvider);
    final pricePerPhoto = session?.pricePerPhoto ?? 0;
    final items = cart.values.toList();
    final itemsTotal = items.fold<num>(
      0,
      (sum, item) => sum + (item.quantity * pricePerPhoto),
    );
    final eventType = session?.eventType ?? '';
    final filmEligible = eventType == 'casamento' || eventType == 'batizado';
    final wantsFilm = ref.watch(wantsFilmProvider);
    if (!filmEligible && wantsFilm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(wantsFilmProvider.notifier).state = false;
      });
    }
    final filmFee = filmEligible && wantsFilm ? 30.0 : 0.0;
    final total = itemsTotal + filmFee;

    return Scaffold(
      appBar: buildNavAppBar(context, 'Carrinho'),
      body: items.isEmpty
          ? const Center(child: Text('Carrinho vazio'))
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return ListTile(
                        leading: item.previewUrl == null
                            ? const SizedBox(
                                width: 56,
                                height: 56,
                                child: Icon(Icons.photo),
                              )
                            : Image.network(
                                item.previewUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                cacheWidth: 160,
                                filterQuality: FilterQuality.medium,
                              ),
                        title: Text('Foto ${item.number}'),
                        subtitle: Text('Quantidade: ${item.quantity}'),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () async {
                                final before = item.quantity;
                                ref
                                    .read(cartProvider.notifier)
                                    .decrement(item.photoId);
                                if (before == 1) {
                                  await enqueueSelection(
                                    widget.eventId,
                                    item.photoId,
                                    'unselected',
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => ref
                                  .read(cartProvider.notifier)
                                  .increment(item.photoId),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                ref
                                    .read(cartProvider.notifier)
                                    .remove(item.photoId);
                                await enqueueSelection(
                                  widget.eventId,
                                  item.photoId,
                                  'unselected',
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (filmEligible)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: wantsFilm,
                      onChanged: (v) =>
                          ref.read(wantsFilmProvider.notifier).state =
                              v ?? false,
                      title: const Text('Adicionar filme (+30€)'),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total: €${total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CheckoutPage(eventId: widget.eventId),
                            ),
                          );
                        },
                        child: const Text('Ir para checkout'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class CheckoutPage extends ConsumerStatefulWidget {
  final int eventId;
  const CheckoutPage({super.key, required this.eventId});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  String paymentMethod = 'cash';
  String onlineMethod = 'card';
  String productType = 'digital';
  String? deliveryType;
  final addressCtrl = TextEditingController();
  bool isSubmitting = false;
  final stripe.CardFormEditController _cardFormController =
      stripe.CardFormEditController();
  bool _cardComplete = false;

  Widget _paymentBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBrandRose),
        color: kBrandRose.withOpacity(0.08),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, letterSpacing: 0.6),
      ),
    );
  }

  Widget _paymentBadges() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _paymentBadge('CARD'),
        _paymentBadge('MB WAY'),
        _paymentBadge('APPLE PAY'),
        _paymentBadge('GOOGLE PAY'),
        _paymentBadge('PAYPAL'),
        _paymentBadge('REVOLUT'),
      ],
    );
  }

  Widget _methodBadge(String text) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: kBrandRose.withOpacity(0.2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: kBrandRose,
        ),
      ),
    );
  }

  Widget _paymentMethodIcon(String id) {
    switch (id) {
      case 'card':
        return const Icon(Icons.credit_card);
      case 'apple_pay':
        return const Icon(Icons.phone_iphone);
      case 'google_pay':
        return const Icon(Icons.android);
      case 'mb_way':
        return _methodBadge('MB');
      case 'paypal':
        return _methodBadge('PP');
      case 'revolut_pay':
        return _methodBadge('R');
      default:
        return const Icon(Icons.payment);
    }
  }

  Widget _checkoutSection({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kDeskCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBrandRose.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: kBrandRose.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (subtitle != null && subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: kDeskMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _checkoutChoiceTile({
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
    Widget? leading,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? kBrandRose.withOpacity(0.12) : kDeskCardAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? kBrandRose.withOpacity(0.7)
                  : kBrandRose.withOpacity(0.16),
            ),
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.white70,
                      ),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: kDeskMuted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected ? kBrandRose : kDeskMuted,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkoutSummaryRow(
    String label,
    String value, {
    bool strong = false,
    Color? valueColor,
  }) {
    final textStyle = TextStyle(
      fontSize: strong ? 15 : 13,
      fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
      color: strong ? Colors.white : Colors.white70,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textStyle),
        Text(
          value,
          style: textStyle.copyWith(color: valueColor ?? textStyle.color),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final items = cart.values.toList();
    final session = ref.watch(guestSessionProvider);
    final pricePerPhoto = session?.pricePerPhoto ?? 0;
    final itemsTotal = items.fold<num>(
      0,
      (sum, item) => sum + (item.quantity * pricePerPhoto),
    );
    final eventType = session?.eventType ?? '';
    final filmEligible = eventType == 'casamento' || eventType == 'batizado';
    final wantsFilm = filmEligible && ref.watch(wantsFilmProvider);
    final filmFee = wantsFilm ? 30.0 : 0.0;
    final shippingFee = deliveryType == 'shipping' ? 5.0 : 0.0;
    final extrasTotal = filmFee + shippingFee;
    final total = itemsTotal + extrasTotal;
    final appConfig = ref.watch(appRuntimeConfigProvider);
    final offlineCheckout =
        session?.offlineMode == true ||
        looksLikeLocalApiBaseUrl(appConfig.apiBaseUrl);
    final allowsOnlinePayment = !offlineCheckout;
    final isOnlinePayment = allowsOnlinePayment && paymentMethod == 'online';
    final processingFee = isOnlinePayment
        ? double.parse(
            (total * (appConfig.stripePercentFee / 100) +
                    appConfig.stripeFixedFee)
                .toStringAsFixed(2),
          )
        : 0.0;
    final totalWithFee = total + processingFee;
    final supportsApplePay = appConfig.enablePlatformPay && Platform.isIOS;
    final supportsGooglePay = appConfig.enablePlatformPay && Platform.isAndroid;
    if (offlineCheckout && paymentMethod != 'cash') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => paymentMethod = 'cash');
      });
    }
    final showEmailField = productType != 'paper';
    final onlineOptions = allowsOnlinePayment
        ? buildOnlineMethodOptions(
            supportsApplePay: supportsApplePay,
            supportsGooglePay: supportsGooglePay,
          )
        : <OnlineMethodOption>[];
    if (onlineOptions.isNotEmpty &&
        !onlineOptions.any((option) => option.id == onlineMethod)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => onlineMethod = onlineOptions.first.id);
      });
    }
    return Scaffold(
      appBar: buildNavAppBar(context, 'Checkout'),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              kBrandRose.withOpacity(0.06),
              Colors.transparent,
              Colors.transparent,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: kBrandRose.withOpacity(0.2)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [kDeskCardAlt, kDeskCard],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kBrandRose.withOpacity(0.1),
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session?.eventName ?? 'Resumo do pedido',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DeskStatusBadge(
                          '${items.length} foto${items.length == 1 ? '' : 's'}',
                        ),
                        _DeskStatusBadge(
                          '€${pricePerPhoto.toStringAsFixed(2)}/foto',
                          color: Colors.lightBlueAccent,
                        ),
                        if (filmEligible && wantsFilm)
                          _DeskStatusBadge(
                            'Filme +€30',
                            color: Colors.orangeAccent,
                          ),
                        if (deliveryType == 'shipping')
                          _DeskStatusBadge(
                            'Envio +€5',
                            color: Colors.amberAccent,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _checkoutSummaryRow(
                      'Total atual',
                      '€${(isOnlinePayment ? totalWithFee : total).toStringAsFixed(2)}',
                      strong: true,
                      valueColor: kBrandRose,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isOnlinePayment
                          ? 'Inclui taxa Stripe.'
                          : 'Pagamento simples e rápido no local.',
                      style: const TextStyle(color: kDeskMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _checkoutSection(
                title: 'Dados do cliente',
                subtitle: 'Preenche os dados para associar o pedido.',
                child: Column(
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Telemóvel',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (showEmailField) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _checkoutSection(
                title: 'Produto',
                subtitle: 'Escolhe o formato final do pedido.',
                child: Column(
                  children: [
                    _checkoutChoiceTile(
                      title: 'Digital',
                      subtitle: 'Entrega por link para download.',
                      selected: productType == 'digital',
                      onTap: () => setState(() {
                        productType = 'digital';
                        deliveryType = null;
                      }),
                      leading: const Icon(
                        Icons.cloud_download_outlined,
                        color: kBrandRose,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _checkoutChoiceTile(
                      title: 'Papel',
                      subtitle: 'Levantamento ou envio.',
                      selected: productType == 'paper',
                      onTap: () => setState(() {
                        productType = 'paper';
                        deliveryType = deliveryType ?? 'pickup';
                      }),
                      leading: const Icon(
                        Icons.print_outlined,
                        color: kBrandRose,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _checkoutChoiceTile(
                      title: 'Ambos',
                      subtitle: 'Recebes digital e papel.',
                      selected: productType == 'both',
                      onTap: () => setState(() {
                        productType = 'both';
                        deliveryType = deliveryType ?? 'pickup';
                      }),
                      leading: const Icon(
                        Icons.layers_outlined,
                        color: kBrandRose,
                      ),
                    ),
                  ],
                ),
              ),
              if (productType != 'digital') ...[
                const SizedBox(height: 16),
                _checkoutSection(
                  title: 'Entrega',
                  subtitle: 'Define como o pedido em papel será entregue.',
                  child: Column(
                    children: [
                      _checkoutChoiceTile(
                        title: eventType == 'batizado'
                            ? 'Entregar aos pais do bebé'
                            : 'Entregar aos noivos',
                        subtitle: 'Sem custo adicional.',
                        selected: deliveryType == 'pickup',
                        onTap: () => setState(() => deliveryType = 'pickup'),
                        leading: const Icon(
                          Icons.handshake_outlined,
                          color: kBrandRose,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _checkoutChoiceTile(
                        title: 'Levantar em Loja',
                        subtitle: 'Sem custo adicional.',
                        selected: deliveryType == 'store_pickup',
                        onTap: () =>
                            setState(() => deliveryType = 'store_pickup'),
                        leading: const Icon(
                          Icons.storefront_outlined,
                          color: kBrandRose,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _checkoutChoiceTile(
                        title: 'Enviar por correio',
                        subtitle: 'Acresce €5.00 ao total.',
                        selected: deliveryType == 'shipping',
                        onTap: () => setState(() => deliveryType = 'shipping'),
                        leading: const Icon(
                          Icons.local_shipping_outlined,
                          color: kBrandRose,
                        ),
                      ),
                      if (deliveryType == 'shipping') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: addressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Morada para envio',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (filmEligible) ...[
                const SizedBox(height: 16),
                _checkoutSection(
                  title: 'Filme',
                  subtitle: 'Opção definida no catálogo do evento.',
                  child: _checkoutChoiceTile(
                    title: wantsFilm ? 'Filme incluído' : 'Sem filme',
                    subtitle: wantsFilm
                        ? 'Extra aplicado: €30.00'
                        : 'Nenhum custo adicional.',
                    selected: wantsFilm,
                    onTap: () {},
                    leading: Icon(
                      wantsFilm
                          ? Icons.movie_creation_outlined
                          : Icons.hide_image_outlined,
                      color: kBrandRose,
                    ),
                    trailing: Text(
                      wantsFilm ? '+€30' : '€0',
                      style: const TextStyle(
                        color: kBrandRose,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _checkoutSection(
                title: 'Pagamento',
                subtitle: offlineCheckout
                    ? 'Modo offline ativo. Só pagamento em dinheiro.'
                    : 'Escolhe como queres concluir o pedido.',
                child: Column(
                  children: [
                    _checkoutChoiceTile(
                      title: 'Dinheiro',
                      subtitle: 'Pagamento direto com o fotógrafo.',
                      selected: paymentMethod == 'cash',
                      onTap: () => setState(() => paymentMethod = 'cash'),
                      leading: const Icon(
                        Icons.payments_outlined,
                        color: kBrandRose,
                      ),
                    ),
                    if (allowsOnlinePayment) ...[
                      const SizedBox(height: 10),
                      _checkoutChoiceTile(
                        title: 'Pagamento online',
                        subtitle: 'Stripe com cartão e métodos locais.',
                        selected: paymentMethod == 'online',
                        onTap: () => setState(() => paymentMethod = 'online'),
                        leading: const Icon(
                          Icons.lock_outline,
                          color: kBrandRose,
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: kBrandRose,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _paymentBadges(),
                      ),
                    ],
                  ],
                ),
              ),
              if (isOnlinePayment) ...[
                const SizedBox(height: 16),
                _checkoutSection(
                  title: 'Método online',
                  subtitle: 'Seleciona a opção preferida.',
                  child: Column(
                    children: [
                      for (var i = 0; i < onlineOptions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _checkoutChoiceTile(
                          title: onlineOptions[i].label,
                          subtitle: onlineOptions[i].opensWeb
                              ? 'Abre no navegador'
                              : 'Pagamento dentro da app',
                          selected: onlineMethod == onlineOptions[i].id,
                          onTap: () => setState(
                            () => onlineMethod = onlineOptions[i].id,
                          ),
                          leading: _paymentMethodIcon(onlineOptions[i].id),
                        ),
                      ],
                      if (onlineMethod == 'card' && Platform.isIOS) ...[
                        const SizedBox(height: 14),
                        stripe.CardFormField(
                          controller: _cardFormController,
                          style: stripe.CardFormStyle(
                            backgroundColor: const Color(0xFF1C1C1C),
                            textColor: Colors.white,
                            placeholderColor: Colors.white38,
                            fontSize: 16,
                            borderColor: kBrandRose,
                            borderWidth: 1,
                            borderRadius: 12,
                          ),
                          onCardChanged: (details) {
                            final complete = details?.complete ?? false;
                            if (_cardComplete != complete) {
                              setState(() => _cardComplete = complete);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _checkoutSection(
                title: 'Resumo',
                subtitle: 'Confirma os valores antes de submeter.',
                child: Column(
                  children: [
                    _checkoutSummaryRow(
                      'Fotos',
                      '€${itemsTotal.toStringAsFixed(2)}',
                    ),
                    if (filmFee > 0) ...[
                      const SizedBox(height: 8),
                      _checkoutSummaryRow(
                        'Filme',
                        '+€${filmFee.toStringAsFixed(2)}',
                      ),
                    ],
                    if (shippingFee > 0) ...[
                      const SizedBox(height: 8),
                      _checkoutSummaryRow(
                        'Envio',
                        '+€${shippingFee.toStringAsFixed(2)}',
                      ),
                    ],
                    if (isOnlinePayment) ...[
                      const SizedBox(height: 8),
                      _checkoutSummaryRow(
                        'Taxa Stripe',
                        '+€${processingFee.toStringAsFixed(2)}',
                      ),
                    ],
                    const SizedBox(height: 12),
                    Divider(color: kBrandRose.withOpacity(0.2), height: 1),
                    const SizedBox(height: 12),
                    _checkoutSummaryRow(
                      'Total',
                      '€${(isOnlinePayment ? totalWithFee : total).toStringAsFixed(2)}',
                      strong: true,
                      valueColor: kBrandRose,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: items.isEmpty || isSubmitting
                            ? null
                            : () async {
                                String? sessionToken;
                                try {
                                  setState(() => isSubmitting = true);
                                  final session = ref.read(
                                    guestSessionProvider,
                                  );
                                  if (session == null) return;
                                  sessionToken = session.token;
                                  if (nameCtrl.text.trim().isEmpty ||
                                      phoneCtrl.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Nome e telemóvel são obrigatórios.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  final email = emailCtrl.text.trim();
                                  if (showEmailField && email.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Email é obrigatório para produto digital ou ambos.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (email.isNotEmpty &&
                                      !RegExp(
                                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                      ).hasMatch(email)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Email invalido. Exemplo: nome@email.com',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (productType != 'digital' &&
                                      deliveryType == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Escolhe o tipo de entrega.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (deliveryType == 'shipping' &&
                                      addressCtrl.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Morada obrigatória para envio.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  if (isOnlinePayment) {
                                    if (!Platform.isAndroid &&
                                        !Platform.isIOS) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Pagamento online disponível apenas no telemóvel (Android/iOS).',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    if (onlineMethod == 'card' &&
                                        Platform.isIOS &&
                                        !_cardComplete) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Preenche os dados do cartão.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    if (kOnlineWebMethods.contains(
                                      onlineMethod,
                                    )) {
                                      final checkout = await ref
                                          .read(apiProvider)
                                          .createStripeCheckoutSession(
                                            eventId: widget.eventId,
                                            token: session.token,
                                            customerName: nameCtrl.text.trim(),
                                            phone: phoneCtrl.text.trim(),
                                            email: email,
                                            photoItems: items
                                                .map(
                                                  (i) => CartItemPayload(
                                                    photoId: i.photoId,
                                                    quantity: i.quantity,
                                                  ),
                                                )
                                                .toList(),
                                            productType: productType,
                                            deliveryType: deliveryType,
                                            deliveryAddress: addressCtrl.text
                                                .trim(),
                                            wantsFilm: wantsFilm,
                                            paymentMethodType: onlineMethod,
                                            processingFee: processingFee,
                                          );
                                      if (checkout.checkoutUrl.isEmpty) {
                                        throw Exception(
                                          'Pagamento online indisponível de momento.',
                                        );
                                      }
                                      final uri = Uri.tryParse(
                                        checkout.checkoutUrl,
                                      );
                                      if (uri == null) {
                                        throw Exception(
                                          'URL de pagamento inválido.',
                                        );
                                      }
                                      final opened = await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                      if (!opened) {
                                        throw Exception(
                                          'Não foi possível abrir o navegador.',
                                        );
                                      }
                                      await ref
                                          .read(savedOrdersProvider.notifier)
                                          .add(checkout.orderCode);
                                      if (!context.mounted) return;
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => TicketPage(
                                            orderCode: checkout.orderCode,
                                            autoClose: true,
                                          ),
                                        ),
                                        (route) => route.isFirst,
                                      );
                                      return;
                                    }
                                    final intent = await ref
                                        .read(apiProvider)
                                        .createStripeIntent(
                                          eventId: widget.eventId,
                                          token: session.token,
                                          customerName: nameCtrl.text.trim(),
                                          phone: phoneCtrl.text.trim(),
                                          email: email,
                                          photoItems: items
                                              .map(
                                                (i) => CartItemPayload(
                                                  photoId: i.photoId,
                                                  quantity: i.quantity,
                                                ),
                                              )
                                              .toList(),
                                          productType: productType,
                                          deliveryType: deliveryType,
                                          deliveryAddress: addressCtrl.text
                                              .trim(),
                                          wantsFilm: wantsFilm,
                                          processingFee: processingFee,
                                        );
                                    stripe.Stripe.publishableKey =
                                        intent.publishableKey;
                                    if (appConfig.enablePlatformPay &&
                                        Platform.isIOS) {
                                      stripe.Stripe.merchantIdentifier =
                                          appConfig.applePayMerchantId;
                                    }
                                    stripe.Stripe.urlScheme =
                                        appConfig.stripeUrlScheme;
                                    await stripe.Stripe.instance
                                        .applySettings();
                                    final isTestKey = intent.publishableKey
                                        .startsWith('pk_test_');
                                    if (onlineMethod == 'card') {
                                      if (Platform.isIOS) {
                                        var confirmed = await stripe
                                            .Stripe
                                            .instance
                                            .confirmPayment(
                                              paymentIntentClientSecret:
                                                  intent.clientSecret,
                                              data: stripe.PaymentMethodParams.card(
                                                paymentMethodData:
                                                    stripe.PaymentMethodData(
                                                      billingDetails:
                                                          stripe.BillingDetails(
                                                            name: nameCtrl.text
                                                                .trim(),
                                                            email: email,
                                                            phone: phoneCtrl
                                                                .text
                                                                .trim(),
                                                          ),
                                                    ),
                                              ),
                                            );
                                        if (confirmed.status ==
                                            stripe
                                                .PaymentIntentsStatus
                                                .RequiresAction) {
                                          confirmed = await stripe
                                              .Stripe
                                              .instance
                                              .handleNextAction(
                                                intent.clientSecret,
                                                returnURL:
                                                    '${appConfig.stripeUrlScheme}://redirect',
                                              );
                                        }
                                      } else {
                                        await stripe.Stripe.instance.initPaymentSheet(
                                          paymentSheetParameters:
                                              stripe.SetupPaymentSheetParameters(
                                                paymentIntentClientSecret:
                                                    intent.clientSecret,
                                                merchantDisplayName:
                                                    'Studio 59',
                                                returnURL:
                                                    '${appConfig.stripeUrlScheme}://redirect',
                                                style: ThemeMode.dark,
                                              ),
                                        );
                                        await stripe.Stripe.instance
                                            .presentPaymentSheet();
                                      }
                                    } else if (onlineMethod == 'apple_pay') {
                                      if (!Platform.isIOS) {
                                        throw Exception(
                                          'Apple Pay só está disponível em iOS.',
                                        );
                                      }
                                      final platformPaySupported = await stripe
                                          .Stripe
                                          .instance
                                          .isPlatformPaySupported(
                                            googlePay:
                                                stripe.IsGooglePaySupportedParams(
                                                  testEnv: isTestKey,
                                                  existingPaymentMethodRequired:
                                                      false,
                                                ),
                                          );
                                      if (!platformPaySupported) {
                                        throw Exception(
                                          'Apple Pay não está disponível neste dispositivo.',
                                        );
                                      }
                                      await stripe.Stripe.instance
                                          .confirmPlatformPayPaymentIntent(
                                            clientSecret: intent.clientSecret,
                                            confirmParams:
                                                stripe
                                                    .PlatformPayConfirmParams.applePay(
                                                  applePay: stripe.ApplePayParams(
                                                    merchantCountryCode:
                                                        appConfig
                                                            .merchantCountryCode,
                                                    currencyCode: 'EUR',
                                                    cartItems: [
                                                      stripe
                                                          .ApplePayCartSummaryItem.immediate(
                                                        label: 'Studio 59',
                                                        amount: total
                                                            .toStringAsFixed(2),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                          );
                                    } else if (onlineMethod == 'google_pay') {
                                      if (!Platform.isAndroid) {
                                        throw Exception(
                                          'Google Pay só está disponível em Android.',
                                        );
                                      }
                                      final platformPaySupported = await stripe
                                          .Stripe
                                          .instance
                                          .isPlatformPaySupported(
                                            googlePay:
                                                stripe.IsGooglePaySupportedParams(
                                                  testEnv: isTestKey,
                                                  existingPaymentMethodRequired:
                                                      false,
                                                ),
                                          );
                                      if (!platformPaySupported) {
                                        throw Exception(
                                          'Google Pay não está disponível neste dispositivo.',
                                        );
                                      }
                                      await stripe.Stripe.instance
                                          .confirmPlatformPayPaymentIntent(
                                            clientSecret: intent.clientSecret,
                                            confirmParams:
                                                stripe
                                                    .PlatformPayConfirmParams.googlePay(
                                                  googlePay: stripe.GooglePayParams(
                                                    testEnv: isTestKey,
                                                    merchantCountryCode:
                                                        appConfig
                                                            .merchantCountryCode,
                                                    currencyCode: 'EUR',
                                                    merchantName: 'Studio 59',
                                                  ),
                                                ),
                                          );
                                    } else {
                                      throw Exception(
                                        'Método de pagamento inválido.',
                                      );
                                    }

                                    final code = intent.orderCode;
                                    await ref
                                        .read(savedOrdersProvider.notifier)
                                        .add(code);
                                    ref.read(cartProvider.notifier).clear();
                                    ref.read(wantsFilmProvider.notifier).state =
                                        false;
                                    if (!context.mounted) return;
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TicketPage(
                                          orderCode: code,
                                          autoClose: true,
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final code = await ref
                                      .read(apiProvider)
                                      .createOrder(
                                        eventId: widget.eventId,
                                        token: session.token,
                                        customerName: nameCtrl.text.trim(),
                                        phone: phoneCtrl.text.trim(),
                                        email: email,
                                        paymentMethod: 'cash',
                                        photoItems: items
                                            .map(
                                              (i) => CartItemPayload(
                                                photoId: i.photoId,
                                                quantity: i.quantity,
                                              ),
                                            )
                                            .toList(),
                                        pricePerPhoto: pricePerPhoto,
                                        productType: productType,
                                        deliveryType: deliveryType,
                                        deliveryAddress: addressCtrl.text
                                            .trim(),
                                        wantsFilm: wantsFilm,
                                      );
                                  await ref
                                      .read(savedOrdersProvider.notifier)
                                      .add(code);
                                  ref.read(cartProvider.notifier).clear();
                                  ref.read(wantsFilmProvider.notifier).state =
                                      false;
                                  if (!context.mounted) return;
                                  if (code.startsWith('OFF-')) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Sem internet. Pedido guardado para sincronizar.',
                                        ),
                                      ),
                                    );
                                  }
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TicketPage(
                                        orderCode: code,
                                        autoClose: true,
                                      ),
                                    ),
                                  );
                                } on stripe.StripeException catch (e) {
                                  if (!context.mounted) return;
                                  final message =
                                      e.error.localizedMessage ??
                                      e.error.message ??
                                      'Pagamento cancelado.';
                                  final type = e.error.type;
                                  final code = e.error.code;
                                  final suffix = [type, code]
                                      .where(
                                        (v) =>
                                            v != null &&
                                            v.toString().isNotEmpty,
                                      )
                                      .join(' / ');
                                  final fullMessage = suffix.isNotEmpty
                                      ? '$message ($suffix)'
                                      : message;
                                  if (sessionToken != null) {
                                    await ref
                                        .read(apiProvider)
                                        .logClientIssue(
                                          token: sessionToken!,
                                          message: 'stripe_exception',
                                          context: {
                                            'message': message,
                                            'type': type?.toString(),
                                            'code': code?.toString(),
                                            'platform':
                                                Platform.operatingSystem,
                                            'release': kReleaseMode,
                                          },
                                        );
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(fullMessage)),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  if (sessionToken != null) {
                                    await ref
                                        .read(apiProvider)
                                        .logClientIssue(
                                          token: sessionToken!,
                                          message: 'payment_flow_error',
                                          context: {
                                            'error': e.toString(),
                                            'platform':
                                                Platform.operatingSystem,
                                            'release': kReleaseMode,
                                          },
                                        );
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erro ao submeter: $e'),
                                    ),
                                  );
                                } finally {
                                  if (mounted)
                                    setState(() => isSubmitting = false);
                                }
                              },
                        child: Text(
                          isSubmitting ? 'A submeter...' : 'Submeter pedido',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyOrdersPage extends ConsumerWidget {
  const MyOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codes = ref.watch(savedOrdersProvider);
    return Scaffold(
      appBar: buildNavAppBar(context, 'Os meus pedidos'),
      body: codes.isEmpty
          ? const Center(
              child: Text('Sem pedidos guardados neste dispositivo.'),
            )
          : ListView.builder(
              itemCount: codes.length,
              itemBuilder: (_, i) {
                final code = codes[i];
                return ListTile(
                  title: Text(code),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailPage(orderCode: code),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class TicketPage extends ConsumerStatefulWidget {
  final String orderCode;
  final bool autoClose;
  const TicketPage({
    super.key,
    required this.orderCode,
    this.autoClose = false,
  });

  @override
  ConsumerState<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends ConsumerState<TicketPage> {
  static const MethodChannel _galleryChannel = MethodChannel(
    'studio59/gallery',
  );
  static const String _galleryPermissionDeniedMessage =
      'Permissão para guardar fotos negada.';
  Timer? timer;
  Timer? _autoCloseTimer;
  int? downloadingPhotoId;
  bool downloadingAll = false;
  late Future<OrderDetail> _orderFuture;

  Future<void> _showPermissionDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permissão necessária'),
        content: const Text(
          'Para guardar fotos na galeria, a app precisa de acesso às fotos.\n\nClica em "Abrir Definições" e ativa a opção Fotos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: const Text('Abrir Definições'),
          ),
        ],
      ),
    );
  }

  Future<bool> _hasGalleryPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.status;
      return status.isGranted || status.isLimited;
    }
    if (Platform.isAndroid) {
      final photos = await Permission.photos.status;
      final storage = await Permission.storage.status;
      return photos.isGranted || photos.isLimited || storage.isGranted;
    }
    return true;
  }

  Future<void> _saveToGallery(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.jpg');
    await file.writeAsBytes(bytes, flush: true);

    bool? ok;
    if (Platform.isAndroid) {
      ok = await _galleryChannel.invokeMethod<bool>('saveToGallery', {
        'path': file.path,
        'name': '$fileName.jpg',
      });
    } else if (Platform.isIOS) {
      ok = await _galleryChannel.invokeMethod<bool>('saveToGallery', {
        'bytes': bytes,
        'name': '$fileName.jpg',
      });
    } else {
      throw 'Download direto para galeria não disponível nesta plataforma.';
    }

    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}

    if (ok != true) {
      if (!await _hasGalleryPermission()) {
        throw _galleryPermissionDeniedMessage;
      }
      throw 'Falha ao guardar na galeria';
    }
  }

  Future<void> _showGalleryError(Object error, {String? photoNumber}) async {
    final message = error.toString();
    if (message == _galleryPermissionDeniedMessage) {
      await _showPermissionDialog();
    }
    if (!mounted) return;
    final text = photoNumber == null
        ? 'Erro ao descarregar: $message'
        : 'Erro no download da foto $photoNumber: $message';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _downloadPhotoToGallery(
    OrderDetail order,
    OrderPhoto photo,
  ) async {
    final url = await ref
        .read(apiProvider)
        .orderDownloadLink(orderCode: order.orderCode, photoId: photo.id);
    final r = await ref
        .read(apiProvider)
        .dio
        .get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(minutes: 3),
            validateStatus: (s) => s == 200,
          ),
        );
    final bytes = Uint8List.fromList(r.data ?? []);
    if (bytes.isEmpty) {
      throw 'Download vazio';
    }
    final safeNumber = photo.number.replaceAll('/', '-');
    await _saveToGallery(bytes, 'S59_${order.orderCode}_$safeNumber');
  }

  Future<void> _downloadAllToGallery(OrderDetail order) async {
    setState(() => downloadingAll = true);
    try {
      for (final p in order.photos) {
        await _downloadPhotoToGallery(order, p);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download concluído. Fotos guardadas na galeria.'),
        ),
      );
    } catch (e) {
      await _showGalleryError(e);
    } finally {
      if (mounted) setState(() => downloadingAll = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _orderFuture = ref.read(apiProvider).orderDetail(widget.orderCode);
    timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {
          _orderFuture = ref.read(apiProvider).orderDetail(widget.orderCode);
        });
      }
    });
    if (widget.autoClose) {
      _autoCloseTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: Scaffold(
        appBar: buildNavAppBar(context, 'Ticket do Pedido'),
        body: FutureBuilder<OrderDetail>(
          future: _orderFuture,
          builder: (_, snap) {
            if (!snap.hasData) {
              if (snap.hasError) {
                return Center(
                  child: Text(formatUiError(snap.error ?? 'Erro desconhecido')),
                );
              }
              return const Center(child: CircularProgressIndicator());
            }

            final order = snap.data!;
            final isPaid = order.status == 'paid';
            final isOnlinePayment = order.paymentMethod == 'online';
            final isOfflineOrder = order.isOffline;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPaid ? kBrandRoseSoft : kBrandBlack,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBrandRose),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOfflineOrder && isPaid
                            ? 'Pagamento registado offline!'
                            : isPaid
                            ? 'Pagamento confirmado!'
                            : (isOnlinePayment
                                  ? 'A confirmar pagamento online'
                                  : isOfflineOrder
                                  ? 'Mostra este ecrã ao fotografo'
                                  : 'Aguarda confirmação do fotógrafo'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isOfflineOrder && isPaid
                            ? 'O pedido ficou guardado no PC do fotógrafo. O email com o link sai depois da sincronização online.'
                            : isPaid
                            ? 'As tuas fotos estão prontas. Vais receber/recebeste um link único no email para download dos originais.'
                            : (isOnlinePayment
                                  ? 'Estamos a confirmar o pagamento. Assim que estiver pago o download fica disponível.'
                                  : isOfflineOrder
                                  ? 'Dirige-te ao fotógrafo, paga, mostra este ticket e deixa o iPad no mesmo local.'
                                  : 'Dirige-te ao fotógrafo, paga e mostra este ticket. Este ecrã fica aqui até o fotógrafo marcar o pagamento.'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ticket: ${order.orderCode}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text('Nome: ${order.customerName}'),
                        Text('Estado: ${order.status.toUpperCase()}'),
                        Text(
                          'Pagamento: ${isOnlinePayment ? 'ONLINE (STRIPE)' : 'DINHEIRO'}',
                        ),
                        Text('Total: ${order.totalAmount} EUR'),
                        if (order.cashReceivedAmount != null)
                          Text(
                            'Entregue: ${formatEuroAmount(order.cashReceivedAmount!)}€',
                          ),
                        if ((order.cashChangeAmount ?? 0) > 0)
                          Text(
                            order.cashChangeGiven
                                ? 'Troco entregue: ${formatEuroAmount(order.cashChangeAmount!)}€'
                                : 'TROCO por entregar: ${formatEuroAmount(order.cashChangeAmount!)}€',
                            style: TextStyle(
                              color: order.cashChangeGiven
                                  ? Colors.lightGreenAccent
                                  : Colors.orangeAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if ((order.cashDueAmount ?? 0) > 0)
                          Text(
                            'DEVE: ${formatEuroAmount(order.cashDueAmount!)}€',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        if (order.productType != null)
                          Text('Produto: ${order.productType}'),
                        if (order.deliveryType != null)
                          Text(
                            'Entrega: ${formatDeliveryTypeLabel(order.deliveryType)}',
                          ),
                        if (order.deliveryAddress != null &&
                            order.deliveryAddress!.isNotEmpty)
                          Text('Morada: ${order.deliveryAddress}'),
                        if (order.wantsFilm) Text('Filme: +${order.filmFee}€'),
                        if (order.shippingFee > 0)
                          Text('Envio: +${order.shippingFee}€'),
                        Text(
                          'Fotos: ${order.itemsTotal}€ | Extras: ${order.extrasTotal}€',
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Fotos:',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: order.photos
                              .map(
                                (p) => Chip(
                                  label: Text('#${p.number} x${p.quantity}'),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (isPaid && !isOfflineOrder) ...[
                  const Text(
                    'Downloads',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: downloadingAll
                        ? null
                        : () => _downloadAllToGallery(order),
                    icon: downloadingAll
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_for_offline),
                    label: const Text('Download todas'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: order.photos.map((p) {
                      final loading = downloadingPhotoId == p.id;
                      return FilledButton.icon(
                        onPressed: loading
                            ? null
                            : () async {
                                try {
                                  setState(() => downloadingPhotoId = p.id);
                                  await _downloadPhotoToGallery(order, p);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Foto ${p.number} guardada na galeria.',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  await _showGalleryError(
                                    e,
                                    photoNumber: p.number,
                                  );
                                } finally {
                                  if (mounted)
                                    setState(() => downloadingPhotoId = null);
                                }
                              },
                        icon: loading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download),
                        label: Text('#${p.number}'),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.tonal(
                  onPressed: () => setState(() {}),
                  child: const Text('Atualizar estado'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomePage()),
                    (route) => false,
                  ),
                  child: const Text('Voltar ao inicio'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class OrderDetailPage extends ConsumerWidget {
  final String orderCode;
  const OrderDetailPage({super.key, required this.orderCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SecureScreen(
      child: Scaffold(
        appBar: buildNavAppBar(context, orderCode),
        body: FutureBuilder<OrderDetail>(
          future: ref.read(apiProvider).orderDetail(orderCode),
          builder: (_, snap) {
            if (!snap.hasData) {
              if (snap.hasError) {
                return Center(
                  child: Text(formatUiError(snap.error ?? 'Erro desconhecido')),
                );
              }
              return const Center(child: CircularProgressIndicator());
            }
            final o = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Status: ${o.status.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Total: ${o.totalAmount} EUR'),
                if (o.cashReceivedAmount != null)
                  Text('Entregue: ${formatEuroAmount(o.cashReceivedAmount!)}€'),
                if ((o.cashChangeAmount ?? 0) > 0)
                  Text(
                    o.cashChangeGiven
                        ? 'Troco entregue: ${formatEuroAmount(o.cashChangeAmount!)}€'
                        : 'TROCO por entregar: ${formatEuroAmount(o.cashChangeAmount!)}€',
                    style: TextStyle(
                      color: o.cashChangeGiven
                          ? Colors.lightGreenAccent
                          : Colors.orangeAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if ((o.cashDueAmount ?? 0) > 0)
                  Text('DEVE: ${formatEuroAmount(o.cashDueAmount!)}€'),
                if (o.productType != null) Text('Produto: ${o.productType}'),
                if (o.deliveryType != null)
                  Text(
                    'Entrega: ${formatDeliveryTypeLabel(o.deliveryType)}',
                  ),
                if (o.deliveryAddress != null && o.deliveryAddress!.isNotEmpty)
                  Text('Morada: ${o.deliveryAddress}'),
                if (o.wantsFilm) Text('Filme: +${o.filmFee}€'),
                if (o.shippingFee > 0) Text('Envio: +${o.shippingFee}€'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      o.isOffline && o.status == 'paid'
                          ? 'Pagamento registado offline. O email com o link segue depois da sincronização online.'
                          : o.status == 'paid'
                          ? 'Pedido pago. O download e enviado por link unico para o email do pedido.'
                          : 'A aguardar pagamento. Depois o staff envia o link por email.',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...o.photos.map(
                  (p) => ListTile(
                    title: Text('Foto ${p.number}'),
                    subtitle: Text('Quantidade: ${p.quantity}'),
                    trailing: const Icon(Icons.image_outlined),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class StaffLoginPage extends ConsumerStatefulWidget {
  const StaffLoginPage({super.key});

  @override
  ConsumerState<StaffLoginPage> createState() => _StaffLoginPageState();
}

class _StaffLoginPageState extends ConsumerState<StaffLoginPage> {
  final loginCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _checkingOnline = true;
  bool _onlineReachable = false;

  @override
  void initState() {
    super.initState();
    _probeOnline();
  }

  Future<void> _probeOnline() async {
    try {
      var reachable = await ref.read(apiProvider).pingPublic();
      if (!reachable) {
        reachable = await _tryRestoreOnlineRuntimeConfig();
      }
      if (!mounted) return;
      setState(() {
        _checkingOnline = false;
        _onlineReachable = reachable;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingOnline = false;
        _onlineReachable = false;
      });
    }
  }

  Future<bool> _tryRestoreOnlineRuntimeConfig() async {
    final current = ref.read(appRuntimeConfigProvider);
    if (!looksLikeLocalApiBaseUrl(current.apiBaseUrl)) return false;
    final backupConfig = await restoreBackedUpRuntimeConfig();
    final fallbackConfig = backupConfig ?? AppRuntimeConfig.defaults;
    final backupReachable = await ApiService(fallbackConfig).pingPublic();
    if (!backupReachable) return false;
    await saveAppRuntimeConfig(fallbackConfig);
    ref.read(appRuntimeConfigProvider.notifier).state = fallbackConfig;
    ref.invalidate(apiProvider);
    await clearBackedUpRuntimeConfig();
    return true;
  }

  Future<void> _applyOfflineApiBaseUrl(
    String apiBaseUrl, {
    bool persist = false,
  }) async {
    final current = ref.read(appRuntimeConfigProvider);
    if (current.apiBaseUrl == apiBaseUrl) return;
    if (persist && !looksLikeLocalApiBaseUrl(current.apiBaseUrl)) {
      await backupRuntimeConfig(current);
    }
    final next = current.copyWith(apiBaseUrl: apiBaseUrl, apiFallbackIp: '');
    if (persist) {
      await saveAppRuntimeConfig(next);
    }
    ref.read(appRuntimeConfigProvider.notifier).state = next;
    ref.invalidate(apiProvider);
    ref.read(staffTokenProvider.notifier).state = null;
    ref.read(staffUserProvider.notifier).state = null;
    await clearStaffSession();
  }

  bool _isInvalidCredentialsError(Object error) {
    final text = formatUiError(error).toLowerCase();
    return text.contains('invalid credentials');
  }

  Future<StaffAuthResponse> _loginWithOnlineFallback(
    String login,
    String password,
  ) async {
    try {
      return await ref.read(apiProvider).staffLogin(login, password);
    } catch (error) {
      final current = ref.read(appRuntimeConfigProvider);
      if (!_isInvalidCredentialsError(error) ||
          !looksLikeLocalApiBaseUrl(current.apiBaseUrl)) {
        rethrow;
      }
      final restored = await _tryRestoreOnlineRuntimeConfig();
      if (!restored) rethrow;
      return ref.read(apiProvider).staffLogin(login, password);
    }
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      var reachable = await ref.read(apiProvider).pingPublic();
      if (!reachable) {
        reachable = await _tryRestoreOnlineRuntimeConfig();
      }
      if (!reachable) {
        final discovery = await discoverOfflineSession(
          timeout: const Duration(seconds: 4),
        );
        if (discovery != null) {
          await _applyOfflineApiBaseUrl(
            discovery.serverUrl,
            persist: isDesktopPlatform(),
          );
          reachable = await ref.read(apiProvider).pingPublic();
        }
      }
      if (!reachable) {
        throw Exception(
          'Sem ligação ao servidor online nem a uma sessão offline.',
        );
      }
      final token = await _loginWithOnlineFallback(
        loginCtrl.text.trim(),
        passCtrl.text.trim(),
      );
      ref.read(staffTokenProvider.notifier).state = token.token;
      ref.read(staffUserProvider.notifier).state = token.user;
      await saveStaffSession(token.token, token.user);
      if (!context.mounted) return;
      Navigator.pop(context, token);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro login: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: kBrandRose.withOpacity(0.3)),
    );
    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kBrandRose, width: 1.5),
    );
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: kDeskCard,
      labelStyle: const TextStyle(color: kDeskMuted),
      enabledBorder: inputBorder,
      focusedBorder: focusBorder,
      border: inputBorder,
    );

    return Scaffold(
      backgroundColor: kBrandBlack,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/app_icon.png', width: 80, height: 80),
                const SizedBox(height: 12),
                const Text(
                  'Studio 59',
                  style: TextStyle(
                    color: kBrandRose,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Acesso staff',
                  style: TextStyle(
                    color: kDeskMuted,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: loginCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: kBrandRose),
                  decoration: inputDecoration.copyWith(
                    labelText: 'Email ou username',
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: kDeskMuted,
                      size: 20,
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: kBrandRose),
                  decoration: inputDecoration.copyWith(
                    labelText: 'Password',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: kDeskMuted,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: kDeskMuted,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 28),
                if (isDesktopPlatform() &&
                    !_checkingOnline &&
                    !_onlineReachable &&
                    ref.read(offlineHostSessionProvider) == null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const OfflineBootstrapPage(),
                              ),
                            ),
                      icon: const Icon(Icons.wifi_tethering),
                      label: const Text('Criar sessão offline neste PC'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: kBrandRose,
                      foregroundColor: kBrandBlack,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: kBrandBlack,
                            ),
                          )
                        : const Text('Entrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StaffDashboardPage extends ConsumerStatefulWidget {
  const StaffDashboardPage({super.key});

  @override
  ConsumerState<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime? _parseEventDate(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final iso = DateTime.tryParse(trimmed);
  if (iso != null) {
    final local = iso.isUtc ? iso.toLocal() : iso;
    return DateTime(local.year, local.month, local.day);
  }
  var datePart = trimmed;
  if (trimmed.contains('T')) {
    datePart = trimmed.split('T').first;
  } else if (trimmed.contains(' ')) {
    datePart = trimmed.split(' ').first;
  }
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart)) {
    final parts = datePart.split('-');
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(datePart);
  if (match == null) return null;
  final day = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  final year = int.tryParse(match.group(3) ?? '');
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

String _formatEventDateTime(String dateRaw, String? timeRaw) {
  final date = _parseEventDate(dateRaw);
  final time = _normalizeTime(timeRaw);
  if (date == null) {
    return '${dateRaw.trim()} $time';
  }
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final yyyy = date.year.toString();
  return '$dd/$mm/$yyyy $time';
}

String _normalizeTime(String? raw) {
  if (raw == null) return '00:00';
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '00:00';
  final match = RegExp(r'^(\\d{1,2})[:h](\\d{2})').firstMatch(trimmed);
  if (match != null) {
    final h = int.tryParse(match.group(1) ?? '') ?? 0;
    final m = int.tryParse(match.group(2) ?? '') ?? 0;
    final hh = h.clamp(0, 23).toString().padLeft(2, '0');
    final mm = m.clamp(0, 59).toString().padLeft(2, '0');
    return '$hh:$mm';
  }
  if (trimmed.length >= 5 && RegExp(r'^\\d{2}:\\d{2}').hasMatch(trimmed)) {
    return trimmed.substring(0, 5);
  }
  return trimmed;
}

bool _isNumericReportNumber(String? value) {
  if (value == null) return false;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  return RegExp(r'^[0-9]+$').hasMatch(trimmed);
}

String? _displayReportNumber(StaffEvent event) {
  final legacy = event.legacyReportNumber?.trim();
  if (_isNumericReportNumber(legacy)) return legacy;
  final report = event.reportNumber?.trim();
  if (_isNumericReportNumber(report)) return report;
  return null;
}

int _numericReportNumberValue(StaffEvent event) {
  final display = _displayReportNumber(event);
  if (display == null) return -1;
  return int.tryParse(display) ?? -1;
}

List<StaffEvent> _upcomingEvents(List<StaffEvent> events, {int? year}) {
  final today = _startOfDay(DateTime.now());
  final upcoming = events.where((e) {
    final date = _parseEventDate(e.eventDate);
    if (date == null) return false;
    final day = _startOfDay(date);
    if (day.isBefore(today)) return false;
    if (year != null && day.year != year) return false;
    return true;
  }).toList();
  upcoming.sort((a, b) {
    final ad = _parseEventDate(a.eventDate)!;
    final bd = _parseEventDate(b.eventDate)!;
    return _startOfDay(ad).compareTo(_startOfDay(bd));
  });
  return upcoming;
}

List<StaffEvent> _pastEvents(List<StaffEvent> events) {
  final today = _startOfDay(DateTime.now());
  final past = events.where((e) {
    final date = _parseEventDate(e.eventDate);
    if (date == null) return true;
    return _startOfDay(date).isBefore(today);
  }).toList();
  past.sort((a, b) {
    final ad = _parseEventDate(a.eventDate);
    final bd = _parseEventDate(b.eventDate);
    final aDay = ad == null ? null : _startOfDay(ad);
    final bDay = bd == null ? null : _startOfDay(bd);
    if (aDay == null && bDay == null) return 0;
    if (aDay == null) return 1;
    if (bDay == null) return -1;
    return bDay.compareTo(aDay);
  });
  return past;
}

Map<DateTime, List<StaffEvent>> _eventsByDay(List<StaffEvent> events) {
  final map = <DateTime, List<StaffEvent>>{};
  for (final e in events) {
    final date = _parseEventDate(e.eventDate);
    if (date == null) continue;
    final key = _startOfDay(date);
    map.putIfAbsent(key, () => []).add(e);
  }
  return map;
}

DateTime _calendarFirstDay(List<StaffEvent> events) {
  return DateTime(2000, 1, 1);
}

DateTime _calendarLastDay(List<StaffEvent> events) {
  return DateTime(2100, 12, 31);
}

String _eventTypeLabel(StaffEvent event) {
  final type = (event.eventType ?? '').toLowerCase();
  if (type.contains('batiz')) return 'Batizado';
  if (type.contains('casam')) return 'Casamento';
  return event.eventType?.trim().isNotEmpty == true
      ? event.eventType!.trim()
      : 'Evento';
}

String _eventTypeInitial(StaffEvent event) {
  final type = (event.eventType ?? '').toLowerCase();
  if (type.contains('batiz')) return 'B';
  if (type.contains('casam')) return 'C';
  return 'E';
}

String _eventTeamLabel(StaffEvent event) {
  final meta = event.eventMeta ?? const <String, dynamic>{};
  final raw = meta['equipa_de_trabalho'] ?? meta['EQUIPA DE TRABALHO'];
  final text = raw?.toString().trim() ?? '';
  return text;
}

String _normalizeRole(String role) {
  final normalized = role.trim().toLowerCase();
  if (normalized.isEmpty) return 'photographer';
  if (normalized == 'staff') return 'photographer';
  return normalized;
}

bool _isAdminRole(String role) => _normalizeRole(role) == 'admin';

bool _isPhotographerRole(String role) => _normalizeRole(role) == 'photographer';

bool _eventMatchesUserTeam(StaffEvent event, StaffUser user) {
  if (_isAdminRole(user.role)) return true;
  final team = _eventTeamLabel(event).trim();
  if (team.isEmpty) return false;
  final normalizedTeam = _normalizeRaw(team);
  if (normalizedTeam.trim().isEmpty) return false;

  final candidates = <String>{};
  final username = user.username?.trim() ?? '';
  if (username.isNotEmpty) candidates.add(username);
  final name = user.name.trim();
  final nameParts = name
      .split(RegExp(r'\\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (name.isNotEmpty) {
    final initials = _initialsFromName(name);
    if (initials.isNotEmpty) candidates.add(initials);
  }

  for (final candidate in candidates) {
    final token = _normalizeToken(candidate);
    if (token.isNotEmpty && normalizedTeam.contains(' $token ')) return true;
  }
  if (nameParts.length == 1) {
    final singleName = _normalizeToken(nameParts.first);
    if (singleName.isNotEmpty && normalizedTeam.contains(' $singleName '))
      return true;
  }
  final normalizedName = _normalizeRaw(name).trim();
  if (normalizedName.isNotEmpty && normalizedTeam.contains(' $normalizedName '))
    return true;

  return false;
}

List<StaffEvent> _filterEventsForUser(List<StaffEvent> events, StaffUser user) {
  if (_canSeeAllEvents(user)) return events;
  return events.where((e) => _eventMatchesUserTeam(e, user)).toList();
}

String _eventSearchBlob(StaffEvent event) {
  final parts = <String>[
    event.name,
    event.eventDate,
    event.eventTime ?? '',
    event.eventType ?? '',
    event.reportNumber ?? '',
    event.legacyReportNumber ?? '',
    event.accessPin ?? '',
    _eventTeamLabel(event),
    _displayReportNumber(event) ?? '',
  ];
  return parts.where((p) => p.trim().isNotEmpty).join(' ').toLowerCase();
}

bool _canSeeAllEvents(StaffUser user) {
  if (_isAdminRole(user.role)) return true;
  return user.hasPermission('events.view.all');
}

String _eventStudioTime(StaffEvent event) {
  final meta = event.eventMeta ?? const <String, dynamic>{};
  final raw = meta['estar_na_loja_as'] ?? meta['ESTAR_NA_LOJA_raw'];
  if (raw != null && raw.toString().trim().isNotEmpty) {
    return _normalizeTime(raw.toString());
  }
  if (event.eventTime != null && event.eventTime!.trim().isNotEmpty) {
    return _normalizeTime(event.eventTime);
  }
  return '';
}

int _eventPhotoCount(StaffEvent event) {
  final meta = event.eventMeta ?? const <String, dynamic>{};
  for (final key in ['photos_count', 'total_photos', 'fotos', 'fotos_total']) {
    final raw = meta[key];
    if (raw == null) continue;
    final value = int.tryParse(raw.toString());
    if (value != null) return value;
  }
  return 0;
}

double _eventSalesTotal(StaffEvent event) {
  final meta = event.eventMeta ?? const <String, dynamic>{};
  for (final key in [
    'total_sales',
    'vendas_total',
    'sales_total',
    'total_vendas',
  ]) {
    final raw = meta[key];
    if (raw == null) continue;
    final value = double.tryParse(raw.toString());
    if (value != null) return value;
  }
  return 0;
}

String _initialsFromName(String? name) {
  if (name == null) return '';
  final parts = name
      .trim()
      .split(RegExp(r'\\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  final first = parts.first;
  final last = parts.length > 1 ? parts.last : parts.first;
  if (first.isEmpty || last.isEmpty) return '';
  final initials = '${first[0]}${last[0]}';
  return _stripDiacritics(initials).toLowerCase();
}

List<String> _splitTeamTokens(String raw) {
  var text = raw.replaceAll(RegExp(r'[\\r\\n]+'), ' ');
  text = text.replaceAll(RegExp(r'\\s*[+,&;\\/]+\\s*'), ',');
  text = text.replaceAll(RegExp(r'\\s+e\\s+', caseSensitive: false), ',');
  text = text.replaceAll(RegExp(r'\\s+and\\s+', caseSensitive: false), ',');
  return text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

String _normalizeRaw(String raw) {
  var text = _stripDiacritics(raw.toLowerCase());
  text = text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  return ' $text ';
}

String _normalizeToken(String raw) {
  var text = raw.replaceAll(RegExp(r'\\(.*?\\)'), '').trim();
  text = text.replaceAll(RegExp("[\"']"), '');
  text = _stripDiacritics(text);
  text = text.replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ').trim();
  if (text.isEmpty) return '';
  return text.split(' ').first.toLowerCase();
}

String _stripDiacritics(String input) {
  const map = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'Á': 'A',
    'À': 'A',
    'Â': 'A',
    'Ã': 'A',
    'Ä': 'A',
    'é': 'e',
    'ê': 'e',
    'è': 'e',
    'ë': 'e',
    'É': 'E',
    'Ê': 'E',
    'È': 'E',
    'Ë': 'E',
    'í': 'i',
    'î': 'i',
    'ì': 'i',
    'ï': 'i',
    'Í': 'I',
    'Î': 'I',
    'Ì': 'I',
    'Ï': 'I',
    'ó': 'o',
    'ô': 'o',
    'ò': 'o',
    'õ': 'o',
    'ö': 'o',
    'Ó': 'O',
    'Ô': 'O',
    'Ò': 'O',
    'Õ': 'O',
    'Ö': 'O',
    'ú': 'u',
    'û': 'u',
    'ù': 'u',
    'ü': 'u',
    'Ú': 'U',
    'Û': 'U',
    'Ù': 'U',
    'Ü': 'U',
    'ç': 'c',
    'Ç': 'C',
    'ñ': 'n',
    'Ñ': 'N',
  };
  final buffer = StringBuffer();
  for (final ch in input.split('')) {
    buffer.write(map[ch] ?? ch);
  }
  return buffer.toString();
}

String _formatDateShort(String raw) {
  final date = _parseEventDate(raw);
  if (date == null) return raw.trim();
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final yyyy = date.year.toString();
  return '$dd/$mm/$yyyy';
}

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.width,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBrandBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBrandRose.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: kBrandRose.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kBrandRose.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: kBrandRose),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: card,
    );
  }
}

class _UpcomingEventCard extends StatelessWidget {
  const _UpcomingEventCard({required this.event});

  final StaffEvent event;

  @override
  Widget build(BuildContext context) {
    final team = _eventTeamLabel(event);
    final typeLabel = _eventTypeLabel(event);
    final studioTime = _eventStudioTime(event);
    final dateLabel = _formatDateShort(event.eventDate);
    final typeInitial = _eventTypeInitial(event);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StaffEventDetailPage(event: event)),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: kBrandBlack,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBrandRose.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kBrandRose.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  typeInitial,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kBrandRose,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    if (team.isNotEmpty)
                      Text(
                        'Equipa: $team',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      'Tipo: $typeLabel',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12,
                      ),
                    ),
                    if (studioTime.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Estúdio: $studioTime',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kBrandRose),
            ],
          ),
        ),
      ),
    );
  }
}

class StaffAgendaPage extends ConsumerStatefulWidget {
  const StaffAgendaPage({super.key});

  @override
  ConsumerState<StaffAgendaPage> createState() => _StaffAgendaPageState();
}

class _StaffAgendaPageState extends ConsumerState<StaffAgendaPage> {
  Future<List<StaffEvent>>? _future;
  String? _token;
  bool? _assignedOnly;
  String? _fromDate;
  DateTime _focusedDay = _startOfDay(DateTime.now());
  DateTime? _selectedDay;

  void _ensureFuture(
    String token, {
    required bool assignedOnly,
    String? fromDate,
  }) {
    if (_future == null ||
        _token != token ||
        _assignedOnly != assignedOnly ||
        _fromDate != fromDate) {
      _token = token;
      _assignedOnly = assignedOnly;
      _fromDate = fromDate;
      _future = ref
          .read(apiProvider)
          .staffEvents(token, assignedOnly: assignedOnly, fromDate: fromDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null)
      return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    if (useDesktopLayout(context)) {
      return StaffDesktopShell(
        user: user,
        token: token,
        initialId: 'agenda',
        overrideTitle: 'Agenda',
        overrideSubtitle: 'Agenda e atribuicoes',
        overrideShowSearch: false,
        overrideContent: (ctx, u, t) => DesktopServicesView(user: u, token: t),
      );
    }
    final canSeeAllEvents = _canSeeAllEvents(user);
    final canCalendar =
        user.hasPermission('events.list') || user.hasPermission('events.view');
    final now = DateTime.now();
    final fromDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (canCalendar) {
      _ensureFuture(token, assignedOnly: !canSeeAllEvents, fromDate: fromDate);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        leading: navLeading(context),
        actions: navActions(context),
      ),
      body: !canCalendar
          ? const Center(child: Text('Sem permissões para ver o calendário.'))
          : RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: FutureBuilder<List<StaffEvent>>(
                future: _future,
                builder: (_, snap) {
                  if (!snap.hasData) {
                    if (snap.hasError) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              formatUiError(snap.error ?? 'Erro desconhecido'),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(
                          height: 300,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                    );
                  }
                  final events = _filterEventsForUser(snap.data!, user);
                  if (events.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Sem eventos'),
                        ),
                      ],
                    );
                  }
                  final eventsByDay = _eventsByDay(events);
                  final selected = _selectedDay ?? _focusedDay;
                  final selectedKey = _startOfDay(selected);
                  final dayEvents =
                      eventsByDay[selectedKey] ?? const <StaffEvent>[];

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TableCalendar<StaffEvent>(
                        firstDay: _calendarFirstDay(events),
                        lastDay: _calendarLastDay(events),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        eventLoader: (day) =>
                            eventsByDay[_startOfDay(day)] ??
                            const <StaffEvent>[],
                        availableGestures: AvailableGestures.all,
                        pageJumpingEnabled: true,
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                        ),
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: false,
                          todayDecoration: BoxDecoration(
                            color: Colors.orange.shade200,
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: const BoxDecoration(
                            color: Colors.deepOrange,
                            shape: BoxShape.circle,
                          ),
                          markerDecoration: const BoxDecoration(
                            color: Colors.deepOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isEmpty) return const SizedBox.shrink();
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${events.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        onPageChanged: (focusedDay) {
                          setState(() {
                            _focusedDay = focusedDay;
                          });
                        },
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Eventos do dia',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (dayEvents.isEmpty)
                        const Text('Sem eventos neste dia')
                      else
                        ...dayEvents.map(
                          (e) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(e.name),
                            subtitle: Text(
                              _formatEventDateTime(e.eventDate, e.eventTime),
                            ),
                            onTap: user.hasPermission('events.view')
                                ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          StaffEventDetailPage(event: e),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _StaffDashboardPageState extends ConsumerState<StaffDashboardPage> {
  StreamSubscription<String>? _tokenRefreshSub;
  Future<List<StaffEvent>>? _eventsFuture;
  String? _eventsToken;
  bool? _eventsAssignedOnly;
  String? _eventsFromDate;
  Future<int>? _pendingOrdersFuture;
  String? _pendingOrdersToken;

  @override
  void initState() {
    super.initState();
    saveStaffLastRoute('dashboard', userId: ref.read(staffUserProvider)?.id);
    _initPushNotifications();
  }

  void _ensureEventsFuture(
    String token, {
    required bool assignedOnly,
    String? fromDate,
  }) {
    if (_eventsFuture == null ||
        _eventsToken != token ||
        _eventsAssignedOnly != assignedOnly ||
        _eventsFromDate != fromDate) {
      _eventsToken = token;
      _eventsAssignedOnly = assignedOnly;
      _eventsFromDate = fromDate;
      _eventsFuture = ref
          .read(apiProvider)
          .staffEvents(token, assignedOnly: assignedOnly, fromDate: fromDate);
    }
  }

  void _ensurePendingOrdersFuture(String token) {
    if (_pendingOrdersFuture == null || _pendingOrdersToken != token) {
      _pendingOrdersToken = token;
      _pendingOrdersFuture = ref
          .read(apiProvider)
          .staffOrdersTotal(token, status: 'pending');
    }
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    super.dispose();
  }

  Future<void> _initPushNotifications() async {
    final apiToken = ref.read(staffTokenProvider);
    if (apiToken == null) return;
    try {
      if (Platform.isIOS) {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      if (Platform.isAndroid) {
        await Permission.notification.request();
      }
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await ref
            .read(apiProvider)
            .registerDeviceToken(
              apiToken,
              fcmToken,
              Platform.isIOS ? 'ios' : 'android',
              deviceId: await getDeviceId(),
            );
      }
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
        newToken,
      ) async {
        final apiToken = ref.read(staffTokenProvider);
        if (apiToken == null) return;
        await ref
            .read(apiProvider)
            .registerDeviceToken(
              apiToken,
              newToken,
              Platform.isIOS ? 'ios' : 'android',
              deviceId: await getDeviceId(),
            );
      });
    } catch (_) {
      // Ignore push setup errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null)
      return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    if (useDesktopLayout(context)) {
      return StaffDesktopShell(user: user, token: token);
    }
    final isWide = MediaQuery.of(context).size.width >= 900;
    final isPhotographer = _isPhotographerRole(user.role);
    final isStaffRole = false;
    final isAdmin = _isAdminRole(user.role);
    final canSeeAllEvents = _canSeeAllEvents(user);
    final canCalendar =
        user.hasPermission('events.list') || user.hasPermission('events.view');
    final now = DateTime.now();
    final fromDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (canCalendar) {
      _ensureEventsFuture(
        token,
        assignedOnly: !canSeeAllEvents,
        fromDate: fromDate,
      );
    }
    if (!isAdmin && user.hasPermission('orders.list')) {
      _ensurePendingOrdersFuture(token);
    }

    return Scaffold(
      appBar: buildNavAppBar(
        context,
        'Staff',
        actions: [
          IconButton(
            onPressed: () {
              ref.read(staffTokenProvider.notifier).state = null;
              ref.read(staffUserProvider.notifier).state = null;
              clearStaffSession();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomePage()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Terminar sessão',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Olá, ${user.name}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          if (canCalendar)
            FutureBuilder<List<StaffEvent>>(
              future: _eventsFuture,
              builder: (_, snap) {
                final events = snap.data ?? const <StaffEvent>[];
                final visibleEvents = _filterEventsForUser(events, user);
                final upcoming = _upcomingEvents(visibleEvents);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _DashboardStatCard(
                          title: 'Serviços Agendados',
                          value: upcoming.length.toString(),
                          subtitle: 'A partir de hoje',
                          icon: Icons.event_available,
                          width: isWide ? 280 : null,
                        ),
                        if (!isAdmin && user.hasPermission('orders.list'))
                          FutureBuilder<int>(
                            future: _pendingOrdersFuture,
                            builder: (_, orderSnap) {
                              final pending = orderSnap.data ?? 0;
                              return _DashboardStatCard(
                                title: 'Pedidos Pendentes',
                                value: pending.toString(),
                                subtitle: 'Aprovar pagamentos',
                                icon: Icons.receipt_long,
                                width: isWide ? 280 : null,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const StaffOrdersPage(),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Próximos 5 serviços',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (upcoming.isEmpty)
                      const Text('Sem serviços agendados')
                    else
                      ...upcoming
                          .take(5)
                          .map((e) => _UpcomingEventCard(event: e)),
                  ],
                );
              },
            ),
          const SizedBox(height: 16),
          const Divider(height: 24),
          if (canCalendar)
            _StaffMenuTile(
              title: 'Agenda',
              subtitle: 'Calendário de serviços',
              icon: Icons.calendar_month,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffAgendaPage()),
              ),
            ),
          if (user.hasPermission('events.view') && !isStaffRole)
            _StaffMenuTile(
              title: 'Eventos',
              subtitle: isPhotographer
                  ? 'Eventos associados'
                  : 'Criar/editar eventos',
              icon: Icons.event,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffEventsPage()),
              ),
            ),
          if (user.hasPermission('uploads.list'))
            _StaffMenuTile(
              title: 'Uploads',
              subtitle: 'Enviar fotos para eventos',
              icon: Icons.cloud_upload,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffUploadsPage()),
              ),
            ),
          if (user.hasPermission('photos.list'))
            _StaffMenuTile(
              title: 'Fotos',
              subtitle: 'Gerir fotos e previews',
              icon: Icons.photo_library_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffPhotosPage()),
              ),
            ),
          if (user.hasPermission('orders.list'))
            _StaffMenuTile(
              title: 'Pedidos',
              subtitle: isPhotographer
                  ? 'Aprovar pagamentos'
                  : 'Filtrar e atualizar status',
              icon: Icons.receipt_long,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffOrdersPage()),
              ),
            ),
          _StaffMenuTile(
            title: 'Definições',
            subtitle: 'Perfil e password',
            icon: Icons.settings,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StaffSettingsPage()),
            ),
          ),
          if (_isAdminRole(user.role))
            _StaffMenuTile(
              title: 'Ligações',
              subtitle: 'API e configurações runtime',
              icon: Icons.router_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffAppConfigPage()),
              ),
            ),
          if (isDesktopPlatform())
            _StaffMenuTile(
              title: 'Sessão Offline',
              subtitle: 'Servidor local para PC/iPad/staff',
              icon: Icons.wifi_tethering,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffOfflineHostPage()),
              ),
            ),
          if (user.hasPermission('users.list'))
            _StaffMenuTile(
              title: 'Utilizadores',
              subtitle: 'CRUD utilizadores e permissões',
              icon: Icons.manage_accounts,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffUsersPage()),
              ),
            ),
          if (user.hasPermission('clients.list'))
            _StaffMenuTile(
              title: 'Clientes',
              subtitle: 'Gerir clientes',
              icon: Icons.people_outline,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffClientsPage()),
              ),
            ),
          if (user.hasPermission('offline.import') ||
              ref.watch(offlineHostSessionProvider)?.isActive == true)
            _StaffMenuTile(
              title: 'Sincronizar',
              subtitle: 'Importar fotos e JSON offline',
              icon: Icons.sync,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffSyncPage()),
              ),
            ),
        ],
      ),
    );
  }
}

class _StaffMenuTile extends StatelessWidget {
  const _StaffMenuTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class DesktopNavItem {
  const DesktopNavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.subtitle,
    this.showSearch = false,
    this.actionsBuilder,
    this.visibleWhen,
  });

  final String id;
  final String label;
  final String? subtitle;
  final IconData icon;
  final Widget Function(BuildContext context, StaffUser user, String token)
  builder;
  final bool showSearch;
  final List<Widget> Function(
    BuildContext context,
    StaffUser user,
    String token,
  )?
  actionsBuilder;
  final bool Function(StaffUser user)? visibleWhen;
}

Widget _pageForDesktopSection(String id) {
  switch (id) {
    case 'agenda':
      return const StaffAgendaPage();
    case 'events':
      return const StaffEventsPage();
    case 'orders':
      return const StaffOrdersPage();
    case 'clients':
      return const StaffClientsPage();
    case 'users':
      return const StaffUsersPage();
    case 'sync':
      return const StaffSyncPage();
    case 'offline-host':
      return const StaffOfflineHostPage();
    case 'settings':
      return const StaffSettingsPage();
    default:
      return const StaffDashboardPage();
  }
}

class StaffDesktopShell extends ConsumerStatefulWidget {
  const StaffDesktopShell({
    super.key,
    required this.user,
    required this.token,
    this.initialId,
    this.overrideContent,
    this.overrideTitle,
    this.overrideSubtitle,
    this.overrideShowSearch,
    this.overrideActionsBuilder,
  });
  final StaffUser user;
  final String token;
  final String? initialId;
  final Widget Function(BuildContext context, StaffUser user, String token)?
  overrideContent;
  final String? overrideTitle;
  final String? overrideSubtitle;
  final bool? overrideShowSearch;
  final List<Widget> Function(
    BuildContext context,
    StaffUser user,
    String token,
  )?
  overrideActionsBuilder;

  @override
  ConsumerState<StaffDesktopShell> createState() => _StaffDesktopShellState();
}

class _StaffDesktopShellState extends ConsumerState<StaffDesktopShell> {
  late String _selectedId;
  final TextEditingController _searchCtrl = TextEditingController();
  final ValueNotifier<String> _searchValue = ValueNotifier('');

  void _openBaseSection(String id) {
    saveStaffLastRoute(id, userId: widget.user.id);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => _pageForDesktopSection(id)),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialId ?? 'dashboard';
    if (widget.initialId == null) {
      readStaffLastRoute(userId: widget.user.id).then((value) {
        if (!mounted) return;
        if (value != null && value.trim().isNotEmpty) {
          setState(() => _selectedId = value);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchValue.dispose();
    super.dispose();
  }

  List<DesktopNavItem> _navItems() {
    final user = widget.user;
    final hasOfflineSession =
        ref.read(offlineHostSessionProvider)?.isActive == true;
    return [
      DesktopNavItem(
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.grid_view_rounded,
        subtitle: 'Resumo operacional',
        builder: (context, user, token) => DesktopDashboardView(
          user: user,
          token: token,
          search: _searchValue,
        ),
        visibleWhen: (u) => u.hasPermission('dashboard.view'),
      ),
      DesktopNavItem(
        id: 'agenda',
        label: 'Agenda',
        icon: Icons.calendar_month_outlined,
        subtitle: 'Agenda e atribuicoes',
        builder: (context, user, token) =>
            DesktopServicesView(user: user, token: token),
        visibleWhen: (u) =>
            u.hasPermission('events.list') || u.hasPermission('events.view'),
      ),
      DesktopNavItem(
        id: 'events',
        label: 'Eventos',
        icon: Icons.event_available,
        subtitle: 'Gestao de eventos',
        showSearch: true,
        builder: (context, user, token) =>
            DesktopEventsView(user: user, token: token, search: _searchValue),
        actionsBuilder: (context, user, token) => [
          FilledButton.icon(
            onPressed: user.hasPermission('events.create')
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          StaffEventFormPage(initialEventType: 'casamento'),
                    ),
                  )
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Novo evento'),
          ),
        ],
        visibleWhen: (u) =>
            u.hasPermission('events.list') || u.hasPermission('events.view'),
      ),
      DesktopNavItem(
        id: 'orders',
        label: 'Pedidos',
        icon: Icons.receipt_long,
        subtitle: 'Pagamentos e entregas',
        showSearch: true,
        builder: (context, user, token) =>
            DesktopOrdersView(user: user, token: token, search: _searchValue),
        visibleWhen: (u) => u.hasPermission('orders.list'),
      ),
      DesktopNavItem(
        id: 'photos',
        label: 'Galeria',
        icon: Icons.photo_library_outlined,
        subtitle: 'Eventos com fotos',
        showSearch: true,
        builder: (context, user, token) =>
            DesktopPhotosView(user: user, token: token, search: _searchValue),
        visibleWhen: (u) =>
            u.hasPermission('photos.list') || u.hasPermission('uploads.list'),
      ),
      DesktopNavItem(
        id: 'clients',
        label: 'Clientes',
        icon: Icons.people_outline,
        subtitle: 'Base de clientes',
        showSearch: true,
        builder: (context, user, token) =>
            DesktopClientsView(user: user, token: token, search: _searchValue),
        visibleWhen: (u) => u.hasPermission('clients.list'),
      ),
      DesktopNavItem(
        id: 'sync',
        label: 'Sincronizacao',
        icon: Icons.sync,
        subtitle: 'Offline e importacao',
        builder: (context, user, token) =>
            DesktopSyncView(user: user, token: token),
        visibleWhen: (u) =>
            u.hasPermission('offline.import') || hasOfflineSession,
      ),
      DesktopNavItem(
        id: 'offline-host',
        label: 'Sessao Offline',
        icon: Icons.wifi_tethering,
        subtitle: 'Criar e gerir sessao local',
        builder: (context, user, token) =>
            DesktopOfflineHostView(user: user, token: token),
        visibleWhen: (u) => isDesktopPlatform(),
      ),
      DesktopNavItem(
        id: 'dossie',
        label: 'Dossiê',
        icon: Icons.folder_copy_outlined,
        subtitle: 'Arquivo por ano e mês',
        builder: (context, user, token) =>
            DesktopDossieView(user: user, token: token),
        visibleWhen: (u) => u.hasPermission('dossie.view'),
      ),
      DesktopNavItem(
        id: 'users',
        label: 'Utilizadores',
        icon: Icons.person_outline,
        subtitle: 'Gestao de equipa',
        builder: (context, user, token) =>
            DesktopUsersView(user: user, token: token),
        visibleWhen: (u) => u.hasPermission('users.list'),
      ),
      DesktopNavItem(
        id: 'settings',
        label: 'Definicoes',
        icon: Icons.settings,
        subtitle: 'Perfil e configuracoes',
        builder: (context, user, token) =>
            DesktopSettingsView(user: user, token: token),
      ),
    ].where((item) => item.visibleWhen?.call(user) ?? true).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _navItems();
    final current = items.firstWhere(
      (i) => i.id == _selectedId,
      orElse: () => items.first,
    );
    if (current.id != _selectedId && widget.overrideContent == null) {
      _selectedId = current.id;
    }
    final isCompact = MediaQuery.of(context).size.width < 900;
    final overrideKey = widget.initialId ?? 'dashboard';
    final isOverrideRoute = widget.overrideContent != null;
    final useOverride = isOverrideRoute && _selectedId == overrideKey;
    final topTitle = useOverride
        ? (widget.overrideTitle ?? current.label)
        : current.label;
    final topSubtitle = useOverride
        ? (widget.overrideSubtitle ?? current.subtitle)
        : current.subtitle;
    final topSearch = useOverride
        ? (widget.overrideShowSearch ?? false)
        : current.showSearch;
    final topActions = useOverride
        ? (widget.overrideActionsBuilder?.call(
                context,
                widget.user,
                widget.token,
              ) ??
              const <Widget>[])
        : (current.actionsBuilder?.call(context, widget.user, widget.token) ??
              const <Widget>[]);

    Widget content = Column(
      children: [
        _DesktopTopbar(
          title: topTitle,
          subtitle: topSubtitle,
          showSearch: topSearch,
          controller: _searchCtrl,
          onSearchChanged: (value) => _searchValue.value = value,
          actions: topActions,
          user: widget.user,
          onLogout: () {
            ref.read(staffTokenProvider.notifier).state = null;
            ref.read(staffUserProvider.notifier).state = null;
            clearStaffSession();
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
              (_) => false,
            );
          },
          leading: isOverrideRoute
              ? Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Voltar',
                    onPressed: () => _openBaseSection(overrideKey),
                  ),
                )
              : isCompact
              ? Builder(
                  builder: (context) => IconButton(
                    tooltip: 'Menu',
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                )
              : null,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: Container(
              key: ValueKey(current.id),
              color: kDeskBg,
              child: useOverride
                  ? widget.overrideContent!(context, widget.user, widget.token)
                  : current.builder(context, widget.user, widget.token),
            ),
          ),
        ),
      ],
    );

    if (isCompact) {
      return Scaffold(
        backgroundColor: kDeskBg,
        drawer: Drawer(
          backgroundColor: kDeskBg,
          child: SafeArea(
            child: _DesktopSidebar(
              width: double.infinity,
              items: items,
              selectedId: _selectedId,
              user: widget.user,
              onSelect: (id) {
                if (isOverrideRoute) {
                  _openBaseSection(id);
                } else {
                  saveStaffLastRoute(id, userId: widget.user.id);
                  setState(() {
                    _selectedId = id;
                    _searchCtrl.clear();
                    _searchValue.value = '';
                  });
                  Navigator.pop(context);
                }
              },
            ),
          ),
        ),
        body: SafeArea(child: content),
      );
    }

    return Scaffold(
      backgroundColor: kDeskBg,
      body: SafeArea(
        child: Row(
          children: [
            _DesktopSidebar(
              items: items,
              selectedId: _selectedId,
              user: widget.user,
              onSelect: (id) {
                if (isOverrideRoute) {
                  _openBaseSection(id);
                } else {
                  saveStaffLastRoute(id, userId: widget.user.id);
                  setState(() {
                    _selectedId = id;
                    _searchCtrl.clear();
                    _searchValue.value = '';
                  });
                }
              },
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    this.width,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    required this.user,
  });

  final double? width;
  final List<DesktopNavItem> items;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final StaffUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? kDeskSidebarWidth,
      decoration: BoxDecoration(
        color: kDeskSurface,
        border: Border(right: BorderSide(color: kBrandRose.withOpacity(0.2))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kBrandRose.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: kBrandRose),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Studio 59',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                ...items.map((item) {
                  final selected = selectedId == item.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () => onSelect(item.id),
                      borderRadius: BorderRadius.circular(14),
                      hoverColor: kBrandRose.withOpacity(0.08),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? kBrandRose.withOpacity(0.16)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? kBrandRose.withOpacity(0.6)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              color: selected ? kBrandRose : kDeskMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  color: selected
                                      ? kBrandRose
                                      : Colors.white.withOpacity(0.8),
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: kBrandRose.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: kBrandRose.withOpacity(0.2),
                  child: Text(
                    _initialsFromName(user.name).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        user.role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopTopbar extends StatelessWidget {
  const _DesktopTopbar({
    required this.title,
    required this.subtitle,
    required this.showSearch,
    required this.controller,
    required this.onSearchChanged,
    required this.actions,
    required this.user,
    required this.onLogout,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final bool showSearch;
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final List<Widget> actions;
  final StaffUser user;
  final VoidCallback onLogout;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(kDeskGutter, 16, kDeskGutter, 12),
      decoration: BoxDecoration(
        color: kDeskSurface,
        border: Border(bottom: BorderSide(color: kBrandRose.withOpacity(0.2))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;
          if (!isNarrow) {
            return Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (showSearch)
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: controller,
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Pesquisar...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: kBrandRose.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  ...actions.map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: w,
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Terminar sessao',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 6)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Terminar sessao',
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
              if (showSearch) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Pesquisar...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: kBrandRose.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DeskSectionHeader extends StatelessWidget {
  const _DeskSectionHeader(this.title, {this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _DeskCard extends StatelessWidget {
  const _DeskCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDeskCard,
        borderRadius: BorderRadius.circular(kDeskRadius),
        border: Border.all(color: kBrandRose.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: kBrandRose.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DeskKpiCard extends StatelessWidget {
  const _DeskKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.color,
  });
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? kBrandRose;
    return _DeskCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTypeBadge extends StatelessWidget {
  const _ProductTypeBadge(this.productType);
  final String productType;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final IconData icon;
    switch (productType) {
      case 'paper':
        color = Colors.orangeAccent;
        label = 'Papel';
        icon = Icons.print;
        break;
      case 'both':
        color = Colors.deepOrangeAccent;
        label = 'Digital + Papel';
        icon = Icons.print;
        break;
      default:
        color = Colors.lightBlueAccent;
        label = 'Digital';
        icon = Icons.cloud_download_outlined;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeskStatusBadge extends StatelessWidget {
  const _DeskStatusBadge(this.label, {this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = (color ?? kBrandRose).withOpacity(0.2);
    final fg = color ?? kBrandRose;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MobileActionChip extends StatelessWidget {
  const _MobileActionChip({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DeskTableColumn {
  const _DeskTableColumn(
    this.label, {
    this.flex = 1,
    this.align = CrossAxisAlignment.start,
  });
  final String label;
  final int flex;
  final CrossAxisAlignment align;
}

class _DeskTable extends StatelessWidget {
  const _DeskTable({required this.columns, required this.rows});
  final List<_DeskTableColumn> columns;
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minCellWidth = 120.0;
        final minTableWidth = columns.fold<double>(
          0,
          (sum, c) => sum + (c.flex * minCellWidth),
        );
        final tableWidth = max(constraints.maxWidth, minTableWidth);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: tableWidth),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: kDeskCardAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBrandRose.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      for (final c in columns)
                        Expanded(
                          flex: c.flex,
                          child: Column(
                            crossAxisAlignment: c.align,
                            children: [
                              Text(
                                c.label.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.6),
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                ...rows.map((cells) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: kDeskCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBrandRose.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        for (int i = 0; i < columns.length; i++)
                          Expanded(
                            flex: columns[i].flex,
                            child: Column(
                              crossAxisAlignment: columns[i].align,
                              children: [cells[i]],
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DesktopDashboardView extends ConsumerWidget {
  const DesktopDashboardView({
    super.key,
    required this.user,
    required this.token,
    required this.search,
  });
  final StaffUser user;
  final String token;
  final ValueListenable<String> search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSeeAllEvents = _canSeeAllEvents(user);
    final runtimeConfig = ref.watch(appRuntimeConfigProvider);
    final offlineSession = ref.watch(offlineHostSessionProvider);
    final isOfflineMode =
        offlineSession != null ||
        looksLikeLocalApiBaseUrl(runtimeConfig.apiBaseUrl);
    final fromDate = DateTime.now();
    final fromDateParam =
        '${fromDate.year.toString().padLeft(4, '0')}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
    final eventsFuture = ref
        .read(apiProvider)
        .staffEvents(
          token,
          assignedOnly: !canSeeAllEvents,
          fromDate: fromDateParam,
        );
    final ordersFuture = ref
        .read(apiProvider)
        .staffOrdersList(token, status: 'pending');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDeskGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<List<StaffEvent>>(
            future: eventsFuture,
            builder: (context, snap) {
              final events = snap.data ?? const <StaffEvent>[];
              final upcoming = _upcomingEvents(
                _filterEventsForUser(events, user),
              );
              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width > 1200
                      ? 4
                      : width > 900
                      ? 3
                      : 2;
                  final cardWidth = (width - (columns - 1) * 16) / columns;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _DeskKpiCard(
                          title: 'Servicos marcados',
                          value: upcoming.length.toString(),
                          subtitle: 'A partir de hoje',
                          icon: Icons.event_available,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: FutureBuilder<List<OrderListItem>>(
                          future: ordersFuture,
                          builder: (context, orderSnap) {
                            final count = orderSnap.data?.length ?? 0;
                            return _DeskKpiCard(
                              title: 'Pedidos pendentes',
                              value: count.toString(),
                              subtitle: 'A confirmar',
                              icon: Icons.receipt_long,
                              color: Colors.orangeAccent,
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _DeskKpiCard(
                          title: 'Eventos do mes',
                          value: _eventsByDay(events).length.toString(),
                          subtitle: 'Total de dias ativos',
                          icon: Icons.calendar_today,
                          color: Colors.lightBlueAccent,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final left = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DeskSectionHeader('Atividade recente'),
                  const SizedBox(height: 10),
                  const _DeskCard(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Sem atividade recente.'),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _DeskSectionHeader('Pedidos pendentes'),
                  const SizedBox(height: 10),
                  FutureBuilder<List<OrderListItem>>(
                    future: ordersFuture,
                    builder: (context, snap) {
                      final orders = snap.data ?? const <OrderListItem>[];
                      final visible = orders.take(5).toList();
                      if (visible.isEmpty) {
                        return const _DeskCard(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text('Sem pedidos pendentes.'),
                          ),
                        );
                      }
                      return Column(
                        children: visible.map((o) {
                          final statusColor = o.status == 'paid'
                              ? Colors.lightGreenAccent
                              : o.status == 'pending'
                              ? Colors.orangeAccent
                              : Colors.lightBlueAccent;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: _DeskCard(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  kDeskRadius,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        StaffOrderDetailPage(orderId: o.id),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              o.orderCode,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              o.customerName,
                                              style: const TextStyle(
                                                color: kBrandRose,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      _DeskStatusBadge(
                                        o.status.toUpperCase(),
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '€${(o.totalAmount ?? 0).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              );
              final right = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DeskSectionHeader('Proximos eventos'),
                  const SizedBox(height: 10),
                  FutureBuilder<List<StaffEvent>>(
                    future: eventsFuture,
                    builder: (context, snap) {
                      final events = snap.data ?? const <StaffEvent>[];
                      final upcoming = _upcomingEvents(
                        _filterEventsForUser(events, user),
                      ).take(5).toList();
                      if (upcoming.isEmpty) {
                        return const _DeskCard(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text('Sem eventos futuros.'),
                          ),
                        );
                      }
                      return _DeskCard(
                        child: Column(
                          children: [
                            ...upcoming.map(
                              (e) => _DesktopEventRow(
                                title: e.name.isNotEmpty
                                    ? e.name
                                    : 'Evento ${e.id}',
                                subtitle: _formatEventDateTime(
                                  e.eventDate,
                                  e.eventTime,
                                ),
                                badge: _eventTypeLabel(e),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        StaffEventDetailPage(event: e),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _DeskSectionHeader('Sincronizacao'),
                  const SizedBox(height: 10),
                  _DeskCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _DeskStatusBadge(
                              isOfflineMode ? 'OFFLINE' : 'ONLINE',
                              color: isOfflineMode
                                  ? Colors.orangeAccent
                                  : Colors.lightGreenAccent,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isOfflineMode
                                  ? 'Sessão local ativa'
                                  : 'Ligação online ativa',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isOfflineMode
                              ? (offlineSession != null
                                    ? offlineSession.lanApiBaseUrl
                                    : runtimeConfig.apiBaseUrl)
                              : runtimeConfig.apiBaseUrl,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isOfflineMode
                              ? 'Os dados aparecem quando existirem pedidos ou eventos.'
                              : 'Sem resumo adicional disponível.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [left, const SizedBox(height: 22), right],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: left),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: right),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DesktopEventRow extends StatelessWidget {
  const _DesktopEventRow({
    required this.title,
    required this.subtitle,
    required this.badge,
    this.onTap,
  });
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _DeskStatusBadge(badge, color: kBrandRose),
          ],
        ),
      ),
    );
  }
}

class DesktopEventsView extends ConsumerStatefulWidget {
  const DesktopEventsView({
    super.key,
    required this.user,
    required this.token,
    required this.search,
  });
  final StaffUser user;
  final String token;
  final ValueListenable<String> search;

  @override
  ConsumerState<DesktopEventsView> createState() => _DesktopEventsViewState();
}

class _DesktopEventsViewState extends ConsumerState<DesktopEventsView> {
  String _eventType = '';
  Future<List<StaffEvent>>? _future;
  List<StaffServiceTemplate> _serviceTemplates = const [];

  @override
  void initState() {
    super.initState();
    _loadServiceTemplates();
    _reload();
  }

  Future<void> _loadServiceTemplates() async {
    try {
      final templates = await ref
          .read(apiProvider)
          .staffServiceTemplates(widget.token);
      if (!mounted) return;
      templates.sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) return order;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      setState(() => _serviceTemplates = templates);
    } catch (_) {}
  }

  void _reload() {
    _future = ref
        .read(apiProvider)
        .staffEvents(
          widget.token,
          eventType: _eventType.isEmpty ? null : _eventType,
          assignedOnly: !_canSeeAllEvents(widget.user),
        );
  }

  List<StaffEvent> _sortEventsForDesktop(List<StaffEvent> events) {
    final today = _startOfDay(DateTime.now());
    final ordered = List<StaffEvent>.from(events);
    ordered.sort((a, b) {
      final aDate = _parseEventDate(a.eventDate);
      final bDate = _parseEventDate(b.eventDate);
      final aUpcoming = aDate != null && !aDate.isBefore(today);
      final bUpcoming = bDate != null && !bDate.isBefore(today);
      if (aUpcoming != bUpcoming) {
        return aUpcoming ? -1 : 1;
      }
      if (aDate != null && bDate != null) {
        final dateCompare = aUpcoming
            ? aDate.compareTo(bDate)
            : bDate.compareTo(aDate);
        if (dateCompare != 0) return dateCompare;
      } else if (aDate != null || bDate != null) {
        return aDate != null ? -1 : 1;
      }
      final aReport = _numericReportNumberValue(a);
      final bReport = _numericReportNumberValue(b);
      if (aReport != bReport) return bReport.compareTo(aReport);
      return b.id.compareTo(a.id);
    });
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final availableTemplates = _serviceTemplates.isNotEmpty
        ? _serviceTemplates
        : [
            StaffServiceTemplate(
              id: 0,
              slug: 'casamento',
              name: 'Casamento',
              fields: const [],
            ),
            StaffServiceTemplate(
              id: 0,
              slug: 'batizado',
              name: 'Batizado',
              fields: const [],
            ),
          ];
    final canView = widget.user.hasPermission('events.view');
    final canUpdate = widget.user.hasPermission('events.update');

    Widget buildChips() => Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _DeskStatusFilterChip(
          label: 'Todos',
          selected: _eventType.isEmpty,
          onTap: () => setState(() {
            _eventType = '';
            _reload();
          }),
        ),
        ...availableTemplates.map(
          (template) => _DeskStatusFilterChip(
            label: template.name,
            selected: _eventType == template.slug,
            onTap: () => setState(() {
              _eventType = template.slug;
              _reload();
            }),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _loadServiceTemplates();
            _reload();
          }),
          icon: const Icon(Icons.refresh),
          label: const Text('Atualizar'),
        ),
      ],
    );

    return ValueListenableBuilder<String>(
      valueListenable: widget.search,
      builder: (context, searchValue, _) {
        return FutureBuilder<List<StaffEvent>>(
          future: _future,
          builder: (context, snap) {
            Widget contentSliver;
            if (!snap.hasData) {
              contentSliver = snap.hasError
                  ? SliverToBoxAdapter(
                      child: _DeskCard(child: Text('Erro: ${snap.error}')),
                    )
                  : const SliverToBoxAdapter(
                      child: _DeskCard(
                        child: SizedBox(
                          height: 180,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('A carregar eventos...'),
                            ],
                          ),
                        ),
                      ),
                    );
            } else {
              final events = snap.data ?? const <StaffEvent>[];
              final filtered = _filterEventsForUser(events, widget.user);
              final search = searchValue.trim().toLowerCase();
              final visible = _sortEventsForDesktop(
                search.isEmpty
                    ? filtered
                    : filtered
                          .where((e) => _eventSearchBlob(e).contains(search))
                          .toList(),
              );
              if (visible.isEmpty) {
                contentSliver = const SliverToBoxAdapter(
                  child: _DeskCard(child: Text('Sem resultados.')),
                );
              } else {
                contentSliver = SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final e = visible[index];
                    final dateLabel = _formatEventDateTime(
                      e.eventDate,
                      e.eventTime,
                    );
                    final report = _displayReportNumber(e);
                    final team = _eventTeamLabel(e);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: _DeskCard(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(kDeskRadius),
                          onTap: canView
                              ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        StaffEventDetailPage(event: e),
                                  ),
                                )
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            e.name,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            dateLabel,
                                            style: const TextStyle(
                                              color: kDeskMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _DeskStatusBadge(
                                      _eventTypeLabel(e),
                                      color: Colors.lightGreenAccent,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _DeskStatusBadge(
                                      report == null || report.isEmpty
                                          ? 'Sem relatório'
                                          : 'Rel. $report',
                                    ),
                                    _DeskStatusBadge(
                                      'Fotos ${_eventPhotoCount(e)}',
                                    ),
                                    _DeskStatusBadge(
                                      'Vendas €${_eventSalesTotal(e).toStringAsFixed(0)}',
                                    ),
                                    if (team.isNotEmpty)
                                      _DeskStatusBadge('Equipa $team'),
                                  ],
                                ),
                                if ((e.location ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    e.location!.trim(),
                                    style:
                                        const TextStyle(color: kDeskMuted),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (canView)
                                      _MobileActionChip(
                                        label: 'Detalhe',
                                        color: kBrandRose,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                StaffEventDetailPage(
                                                  event: e,
                                                ),
                                          ),
                                        ),
                                      ),
                                    if (canUpdate)
                                      _MobileActionChip(
                                        label: 'Equipa',
                                        color: Colors.lightBlueAccent,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                StaffEventStaffPage(event: e),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
            }

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    kDeskGutter,
                    kDeskGutter,
                    kDeskGutter,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildChips(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    kDeskGutter,
                    0,
                    kDeskGutter,
                    kDeskGutter,
                  ),
                  sliver: contentSliver,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DeskStatusFilterChip extends StatelessWidget {
  const _DeskStatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kBrandRose.withOpacity(0.2) : kDeskCardAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? kBrandRose : kBrandRose.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? kBrandRose : Colors.white.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}

class DesktopOrdersView extends ConsumerStatefulWidget {
  const DesktopOrdersView({
    super.key,
    required this.user,
    required this.token,
    required this.search,
  });
  final StaffUser user;
  final String token;
  final ValueListenable<String> search;

  @override
  ConsumerState<DesktopOrdersView> createState() => _DesktopOrdersViewState();
}

class _DesktopOrdersViewState extends ConsumerState<DesktopOrdersView> {
  String _status = '';
  DateTime _selectedDate = _startOfDay(DateTime.now());
  int? _selectedEventId;
  Future<List<OrderListItem>>? _future;
  Future<List<StaffEvent>>? _eventsFuture;
  String? _lastOrdersKey;
  String? _lastEventsDateKey;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _loadEvents();
  }

  Future<List<StaffEvent>> _loadEvents() => ref
      .read(apiProvider)
      .staffEvents(
        widget.token,
        assignedOnly: !_canSeeAllEvents(widget.user),
        eventDate: _dateKey(_selectedDate),
      );

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<List<OrderListItem>> _loadOrders(List<StaffEvent> eventsForDate) {
    final selectedEvent = eventsForDate.where((e) => e.id == _selectedEventId);
    final singleEventId = selectedEvent.isNotEmpty
        ? selectedEvent.first.id
        : eventsForDate.length == 1
        ? eventsForDate.first.id
        : null;
    final eventIds = singleEventId == null && eventsForDate.length > 1
        ? eventsForDate.map((e) => e.id).toList()
        : null;
    return ref
        .read(apiProvider)
        .staffOrdersList(
          widget.token,
          status: _status,
          eventId: singleEventId,
          eventIds: eventIds,
          eventDate:
              singleEventId == null && (eventIds == null || eventIds.isEmpty)
              ? _dateKey(_selectedDate)
              : '',
        );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateKey = _dateKey(_selectedDate);
    if (_eventsFuture == null || _lastEventsDateKey != selectedDateKey) {
      _lastEventsDateKey = selectedDateKey;
      _eventsFuture = _loadEvents();
    }
    return FutureBuilder<List<StaffEvent>>(
      future: _eventsFuture,
      builder: (context, eventSnap) {
        if (!eventSnap.hasData) {
          if (eventSnap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(kDeskGutter),
              child: _DeskCard(child: Text('Erro: ${eventSnap.error}')),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(kDeskGutter),
            child: _DeskCard(
              child: SizedBox(
                height: 180,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('A carregar eventos desta data...'),
                  ],
                ),
              ),
            ),
          );
        }
        final events = _filterEventsForUser(eventSnap.data!, widget.user);
        final eventsForDate = events;
        final hasSelectedEvent = eventsForDate.any(
          (e) => e.id == _selectedEventId,
        );
        final effectiveSelectedEventId = hasSelectedEvent
            ? _selectedEventId
            : null;
        final ordersKey =
            '${_dateKey(_selectedDate)}|$_status|${effectiveSelectedEventId ?? 'all'}|${eventsForDate.map((e) => e.id).join(',')}';
        if (_future == null || _lastOrdersKey != ordersKey) {
          _lastOrdersKey = ordersKey;
          _future = _loadOrders(eventsForDate);
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(kDeskGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DeskCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.tonal(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020, 1, 1),
                              lastDate: DateTime(2100, 12, 31),
                            );
                            if (picked == null) return;
                            setState(() {
                              _selectedDate = _startOfDay(picked);
                              _selectedEventId = null;
                              _eventsFuture = _loadEvents();
                              _future = null;
                              _lastOrdersKey = null;
                              _lastEventsDateKey = null;
                            });
                          },
                          child: Text('Data: ${_dateLabel(_selectedDate)}'),
                        ),
                        _DeskStatusFilterChip(
                          label: 'Todos',
                          selected: _status.isEmpty,
                          onTap: () => setState(() {
                            _status = '';
                            _future = null;
                            _lastOrdersKey = null;
                          }),
                        ),
                        _DeskStatusFilterChip(
                          label: 'Pendentes',
                          selected: _status == 'pending',
                          onTap: () => setState(() {
                            _status = 'pending';
                            _future = null;
                            _lastOrdersKey = null;
                          }),
                        ),
                        _DeskStatusFilterChip(
                          label: 'Pagos',
                          selected: _status == 'paid',
                          onTap: () => setState(() {
                            _status = 'paid';
                            _future = null;
                            _lastOrdersKey = null;
                          }),
                        ),
                        _DeskStatusFilterChip(
                          label: 'Entregues',
                          selected: _status == 'delivered',
                          onTap: () => setState(() {
                            _status = 'delivered';
                            _future = null;
                            _lastOrdersKey = null;
                          }),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _selectedEventId = null;
                            _eventsFuture = _loadEvents();
                            _future = null;
                            _lastOrdersKey = null;
                            _lastEventsDateKey = null;
                          }),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Atualizar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (eventsForDate.isEmpty)
                      const Text(
                        'Sem eventos nesta data.',
                        style: TextStyle(color: kDeskMuted),
                      )
                    else if (eventsForDate.length == 1)
                      _DeskStatusBadge(eventsForDate.first.name)
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _DeskStatusFilterChip(
                            label: 'Todos os eventos',
                            selected: effectiveSelectedEventId == null,
                            onTap: () => setState(() {
                              _selectedEventId = null;
                              _future = null;
                              _lastOrdersKey = null;
                            }),
                          ),
                          ...eventsForDate.map(
                            (event) => _DeskStatusFilterChip(
                              label: event.name,
                              selected: effectiveSelectedEventId == event.id,
                              onTap: () => setState(() {
                                _selectedEventId = event.id;
                                _future = null;
                                _lastOrdersKey = null;
                              }),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<String>(
                valueListenable: widget.search,
                builder: (context, value, _) {
                  return FutureBuilder<List<OrderListItem>>(
                    future: _future,
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        if (snap.hasError) {
                          return _DeskCard(
                            child: Text('Erro: ${snap.error}'),
                          );
                        }
                        return const _DeskCard(
                          child: SizedBox(
                            height: 180,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text('A carregar pedidos...'),
                              ],
                            ),
                          ),
                        );
                      }
                      final orders = snap.data ?? const <OrderListItem>[];
                      final query = value.trim().toLowerCase();
                      final isPhotographer = _isPhotographerRole(
                        widget.user.role,
                      );
                      final canUpdate = widget.user.hasPermission(
                        'orders.update',
                      );
                      final canDownload =
                          widget.user.hasPermission('orders.download') &&
                          !isPhotographer;
                      final visible = query.isEmpty
                          ? orders
                          : orders
                                .where(
                                  (o) =>
                                      o.orderCode.toLowerCase().contains(
                                        query,
                                      ) ||
                                      o.customerName.toLowerCase().contains(
                                        query,
                                      ) ||
                                      (o.eventName ?? '')
                                          .toLowerCase()
                                          .contains(query),
                                )
                                .toList();
                      if (visible.isEmpty) {
                        return const _DeskCard(child: Text('Sem pedidos.'));
                      }
                      return Column(
                        children: visible.map((o) {
                          final statusColor = o.status == 'paid'
                              ? Colors.lightGreenAccent
                              : o.status == 'pending'
                              ? Colors.orangeAccent
                              : Colors.lightBlueAccent;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: _DeskCard(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  kDeskRadius,
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          StaffOrderDetailPage(orderId: o.id),
                                    ),
                                  );
                                  if (!context.mounted) return;
                                  setState(() {
                                    _future = null;
                                    _lastOrdersKey = null;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  o.orderCode,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  o.customerName,
                                                  style: const TextStyle(
                                                    color: kBrandRose,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              _DeskStatusBadge(
                                                o.status.toUpperCase(),
                                                color: statusColor,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '€${(o.totalAmount ?? 0).toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 8,
                                        children: [
                                          if ((o.eventName ?? '')
                                              .trim()
                                              .isNotEmpty)
                                            _DeskStatusBadge(
                                              o.eventName!.trim(),
                                            ),
                                          if (o.paymentMethod.trim().isNotEmpty)
                                            _DeskStatusBadge(
                                              o.paymentMethod.toUpperCase(),
                                            ),
                                          if (o.cashReceivedAmount != null)
                                            _DeskStatusBadge(
                                              'Entregue €${formatEuroAmount(o.cashReceivedAmount!)}',
                                            ),
                                          if ((o.cashChangeAmount ?? 0) > 0)
                                            _DeskStatusBadge(
                                              o.cashChangeGiven
                                                  ? 'Troco entregue €${formatEuroAmount(o.cashChangeAmount!)}'
                                                  : 'Troco €${formatEuroAmount(o.cashChangeAmount!)}',
                                              color: o.cashChangeGiven
                                                  ? Colors.lightGreenAccent
                                                  : Colors.orangeAccent,
                                            ),
                                          if ((o.cashDueAmount ?? 0) > 0)
                                            _DeskStatusBadge(
                                              'Deve €${formatEuroAmount(o.cashDueAmount!)}',
                                              color: Colors.redAccent,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _MobileActionChip(
                                            label: 'Abrir',
                                            color: kBrandRose,
                                            onTap: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      StaffOrderDetailPage(
                                                        orderId: o.id,
                                                      ),
                                                ),
                                              );
                                              if (!context.mounted) return;
                                              setState(() {
                                                _future = null;
                                                _lastOrdersKey = null;
                                              });
                                            },
                                          ),
                                          if (canUpdate &&
                                              o.status != 'paid' &&
                                              o.status != 'delivered')
                                            _MobileActionChip(
                                              label: 'Pagar',
                                              color: Colors.lightGreenAccent,
                                              onTap: () async {
                                                final settlement =
                                                    await promptCashSettlement(
                                                      context,
                                                      totalAmount:
                                                          o.totalAmount ?? 0,
                                                    );
                                                if (settlement == null) return;
                                                await ref
                                                    .read(apiProvider)
                                                    .markOrderPaid(
                                                      widget.token,
                                                      o.id,
                                                      eventId: o.eventId,
                                                      cashReceivedAmount:
                                                          settlement
                                                              .receivedAmount,
                                                      cashChangeAmount:
                                                          settlement
                                                              .changeAmount,
                                                      cashChangeGiven:
                                                          settlement
                                                              .changeGiven,
                                                      cashDueAmount:
                                                          settlement.dueAmount,
                                                      notes: settlement.notes,
                                                    );
                                                if (!context.mounted) return;
                                                setState(() {
                                                  _future = null;
                                                  _lastOrdersKey = null;
                                                });
                                              },
                                            ),
                                          if (canUpdate &&
                                              o.paymentMethod == 'cash')
                                            _MobileActionChip(
                                              label: 'Editar €',
                                              color: Colors.amberAccent,
                                              onTap: () async {
                                                final edit =
                                                    await promptCashOrderEdit(
                                                      context,
                                                      totalAmount:
                                                          o.totalAmount ?? 0,
                                                      currentStatus: o.status,
                                                      currentReceived:
                                                          o.cashReceivedAmount,
                                                      currentChangeGiven:
                                                          o.cashChangeGiven,
                                                    );
                                                if (edit == null ||
                                                    !context.mounted)
                                                  return;
                                                await ref
                                                    .read(apiProvider)
                                                    .updateOrder(
                                                      widget.token,
                                                      o.id,
                                                      StaffOrderUpdatePayload(
                                                        customerName:
                                                            o.customerName,
                                                        status: edit.status,
                                                        paymentMethod:
                                                            o.paymentMethod,
                                                        notes: edit.notes,
                                                        cashReceivedAmount:
                                                            edit.receivedAmount,
                                                        cashChangeAmount:
                                                            edit.changeAmount,
                                                        cashChangeGiven:
                                                            edit.changeGiven,
                                                        cashDueAmount:
                                                            edit.dueAmount,
                                                      ),
                                                    );
                                                if (!context.mounted) return;
                                                setState(() {
                                                  _future = null;
                                                  _lastOrdersKey = null;
                                                });
                                              },
                                            ),
                                          if (canDownload)
                                            _MobileActionChip(
                                              label: 'Enviar link',
                                              color: kBrandRose,
                                              onTap: () async {
                                                await ref
                                                    .read(apiProvider)
                                                    .staffSendDownloadLink(
                                                      widget.token,
                                                      o.id,
                                                    );
                                                if (!context.mounted) return;
                                                setState(() {
                                                  _future = null;
                                                  _lastOrdersKey = null;
                                                });
                                              },
                                            ),
                                          if (canDownload)
                                            _MobileActionChip(
                                              label: 'ZIP',
                                              color: kDeskMuted,
                                              onTap: () async {
                                                final path = await ref
                                                    .read(apiProvider)
                                                    .staffDownloadAll(
                                                      widget.token,
                                                      o.id,
                                                    );
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'ZIP guardado: $path',
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class DesktopPhotosView extends ConsumerStatefulWidget {
  const DesktopPhotosView({
    super.key,
    required this.user,
    required this.token,
    required this.search,
  });
  final StaffUser user;
  final String token;
  final ValueListenable<String> search;

  @override
  ConsumerState<DesktopPhotosView> createState() => _DesktopPhotosViewState();
}

class _DesktopPhotosViewState extends ConsumerState<DesktopPhotosView> {
  Future<List<StaffEvent>>? _future;
  bool _historyAll = false;

  Future<List<StaffEvent>> _loadEvents() => ref
      .read(apiProvider)
      .staffEvents(
        widget.token,
        assignedOnly: !_canSeeAllEvents(widget.user),
        fromDate: _historyAll
            ? null
            : '${DateTime.now().year.toString().padLeft(4, '0')}-01-01',
      );

  @override
  Widget build(BuildContext context) {
    _future ??= _loadEvents();
    return ValueListenableBuilder<String>(
      valueListenable: widget.search,
      builder: (context, value, _) {
        return FutureBuilder<List<StaffEvent>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(kDeskGutter),
                  child: _DeskCard(child: Text('Erro: ${snap.error}')),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(kDeskGutter),
                child: _DeskCard(
                  child: SizedBox(
                    height: 180,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          _historyAll
                              ? 'A carregar galeria completa...'
                              : 'A carregar galeria do ano atual...',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            final query = value.trim().toLowerCase();
            final events = _filterEventsForUser(snap.data!, widget.user);
            final visible = query.isEmpty
                ? events
                : events
                      .where((event) => _eventSearchBlob(event).contains(query))
                      .toList();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(kDeskGutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _DeskSectionHeader('Galeria'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DeskStatusFilterChip(
                        label: 'Ano atual',
                        selected: !_historyAll,
                        onTap: () => setState(() {
                          _historyAll = false;
                          _future = _loadEvents();
                        }),
                      ),
                      _DeskStatusFilterChip(
                        label: 'Histórico completo',
                        selected: _historyAll,
                        onTap: () => setState(() {
                          _historyAll = true;
                          _future = _loadEvents();
                        }),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _future = _loadEvents();
                        }),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Atualizar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    const _DeskCard(child: Text('Sem eventos com fotos.'))
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final columns = width > 1200
                            ? 4
                            : width > 900
                            ? 3
                            : 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.28,
                              ),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final event = visible[index];
                            final typeLabel = _eventTypeLabel(event);
                            final dateLabel = event.eventDate.trim().isNotEmpty
                                ? event.eventDate.trim()
                                : 'Sem data';
                            return _DeskCard(
                              padding: const EdgeInsets.all(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  kDeskRadius,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        _StaffEventGalleryPage(event: event),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 96,
                                      decoration: BoxDecoration(
                                        color: kDeskCardAlt,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.photo_library_outlined,
                                          size: 34,
                                          color: kBrandRose.withOpacity(0.55),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      event.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dateLabel,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (typeLabel.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        typeLabel,
                                        style: const TextStyle(
                                          color: kBrandRose,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class DesktopClientsView extends ConsumerStatefulWidget {
  const DesktopClientsView({
    super.key,
    required this.user,
    required this.token,
    required this.search,
  });
  final StaffUser user;
  final String token;
  final ValueListenable<String> search;

  @override
  ConsumerState<DesktopClientsView> createState() => _DesktopClientsViewState();
}

class _DesktopClientsViewState extends ConsumerState<DesktopClientsView> {
  Future<List<StaffClient>>? _future;
  String? _lastKey;

  Future<List<StaffClient>> _loadClients(String query) =>
      ref.read(apiProvider).staffClients(widget.token, q: query);

  Future<void> _showClientDialog(StaffClient client) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(client.name),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Email: ${client.email?.trim().isNotEmpty == true ? client.email : '-'}',
              ),
              const SizedBox(height: 8),
              Text(
                'Telefone: ${client.phone?.trim().isNotEmpty == true ? client.phone : '-'}',
              ),
              const SizedBox(height: 8),
              Text('Marketing: ${client.marketingConsent ? 'Sim' : 'Não'}'),
              const SizedBox(height: 8),
              Text(
                'Notas: ${client.notes?.trim().isNotEmpty == true ? client.notes : '-'}',
              ),
            ],
          ),
        ),
        actions: [
          if (widget.user.hasPermission('clients.update'))
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StaffClientFormPage(client: client),
                  ),
                );
                if (mounted) setState(() => _future = null);
              },
              child: const Text('Editar'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: widget.search,
      builder: (context, value, _) {
        final query = value.trim();
        final key = '${widget.token}|$query';
        if (_future == null || _lastKey != key) {
          _lastKey = key;
          _future = _loadClients(query);
        }
        return FutureBuilder<List<StaffClient>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(kDeskGutter),
                  child: _DeskCard(child: Text('Erro: ${snap.error}')),
                );
              }
              return const Center(child: CircularProgressIndicator());
            }
            final clients = snap.data!;
            final rows = clients
                .map(
                  (client) => <Widget>[
                    Text(client.name),
                    Text(
                      client.email?.trim().isNotEmpty == true
                          ? client.email!
                          : '-',
                    ),
                    Text(
                      client.phone?.trim().isNotEmpty == true
                          ? client.phone!
                          : '-',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (widget.user.hasPermission('clients.view') ||
                            widget.user.hasPermission('clients.update'))
                          TextButton(
                            onPressed: () => _showClientDialog(client),
                            child: const Text('Ver'),
                          ),
                        if (widget.user.hasPermission('clients.update'))
                          TextButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      StaffClientFormPage(client: client),
                                ),
                              );
                              if (mounted) setState(() => _future = null);
                            },
                            child: const Text('Editar'),
                          ),
                        if (widget.user.hasPermission('clients.delete'))
                          TextButton(
                            onPressed: () async {
                              final ok = await _confirm(
                                context,
                                'Remover cliente?',
                                client.name,
                              );
                              if (!ok) return;
                              await ref
                                  .read(apiProvider)
                                  .deleteClient(widget.token, client.id);
                              if (mounted) setState(() => _future = null);
                            },
                            child: const Text('Apagar'),
                          ),
                      ],
                    ),
                  ],
                )
                .toList();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(kDeskGutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _DeskSectionHeader('Clientes'),
                  const SizedBox(height: 12),
                  if (clients.isEmpty)
                    const _DeskCard(child: Text('Sem clientes.'))
                  else
                    _DeskTable(
                      columns: const [
                        _DeskTableColumn('Cliente', flex: 2),
                        _DeskTableColumn('Email', flex: 2),
                        _DeskTableColumn('Telefone', flex: 2),
                        _DeskTableColumn('Ações', flex: 2),
                      ],
                      rows: rows,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class DesktopSyncView extends StatelessWidget {
  const DesktopSyncView({super.key, required this.user, required this.token});
  final StaffUser user;
  final String token;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDeskGutter),
      child: const OfflineSyncPanel(embedded: true),
    );
  }
}

class DesktopReportsView extends StatelessWidget {
  const DesktopReportsView({
    super.key,
    required this.user,
    required this.token,
  });
  final StaffUser user;
  final String token;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDeskGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeskSectionHeader('Relatorios e metricas'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DeskKpiCard(
                  title: 'Vendas',
                  value: '€12 400',
                  subtitle: 'Ultimos 30 dias',
                  icon: Icons.insights,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DeskKpiCard(
                  title: 'Pedidos',
                  value: '214',
                  subtitle: 'Ultimos 30 dias',
                  icon: Icons.receipt_long,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DeskKpiCard(
                  title: 'Fotos',
                  value: '6 820',
                  subtitle: 'Entregues',
                  icon: Icons.photo_library,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DeskCard(
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: kDeskCardAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('Grafico de vendas (placeholder)'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dossiê ────────────────────────────────────────────────────────────────

class DesktopDossieView extends ConsumerStatefulWidget {
  const DesktopDossieView({super.key, required this.user, required this.token});
  final StaffUser user;
  final String token;

  @override
  ConsumerState<DesktopDossieView> createState() => _DesktopDossieViewState();
}

class _DesktopDossieViewState extends ConsumerState<DesktopDossieView> {
  Future<List<StaffEvent>>? _future;
  int? _selectedYear;
  int? _selectedMonth;

  static const List<String> _monthNames = [
    '',
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).staffEvents(widget.token);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StaffEvent>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(kDeskGutter),
              child: _DeskCard(child: Text('Erro: ${snap.error}')),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }

        final allEvents = snap.data!
          ..sort((a, b) => b.eventDate.compareTo(a.eventDate));

        final Map<int, Map<int, List<StaffEvent>>> byYearMonth = {};
        for (final e in allEvents) {
          if (e.eventDate.isEmpty) continue;
          final parts = e.eventDate.split('-');
          if (parts.length < 2) continue;
          final year = int.tryParse(parts[0]) ?? 0;
          final month = int.tryParse(parts[1]) ?? 0;
          byYearMonth.putIfAbsent(year, () => {});
          byYearMonth[year]!.putIfAbsent(month, () => []);
          byYearMonth[year]![month]!.add(e);
        }

        final years = byYearMonth.keys.toList()..sort((a, b) => b.compareTo(a));

        return Padding(
          padding: const EdgeInsets.all(kDeskGutter),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Year column
              SizedBox(
                width: 100,
                child: _DeskCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _DeskSectionHeader('Ano'),
                      const SizedBox(height: 8),
                      ...years.map(
                        (y) => _DossieYearTile(
                          year: y,
                          selected: _selectedYear == y,
                          onTap: () => setState(() {
                            _selectedYear = y;
                            _selectedMonth = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Month column
              if (_selectedYear != null) ...[
                SizedBox(
                  width: 140,
                  child: _DeskCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DeskSectionHeader('$_selectedYear'),
                        const SizedBox(height: 8),
                        ...(byYearMonth[_selectedYear]?.keys.toList()
                                  ?..sort((a, b) => b.compareTo(a)))
                                ?.map((m) {
                                  final count =
                                      byYearMonth[_selectedYear]![m]!.length;
                                  return _DossieMonthTile(
                                    label: _monthNames[m],
                                    count: count,
                                    selected: _selectedMonth == m,
                                    onTap: () =>
                                        setState(() => _selectedMonth = m),
                                  );
                                }) ??
                            [],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              // Events column
              if (_selectedYear != null && _selectedMonth != null)
                Expanded(
                  child: _DeskCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DeskSectionHeader(
                          '${_monthNames[_selectedMonth!]} $_selectedYear',
                        ),
                        const SizedBox(height: 8),
                        ...(byYearMonth[_selectedYear]![_selectedMonth]!).map(
                          (e) => _DossieEventRow(
                            event: e,
                            token: widget.token,
                            commissionRate: ref
                                .read(appRuntimeConfigProvider)
                                .commissionRate,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_selectedYear != null)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'Seleciona um mês',
                        style: TextStyle(color: kDeskMuted),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'Seleciona um ano',
                        style: TextStyle(color: kDeskMuted),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DossieYearTile extends StatelessWidget {
  const _DossieYearTile({
    required this.year,
    required this.selected,
    required this.onTap,
  });
  final int year;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: selected
            ? BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Text(
          '$year',
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            color: selected ? Colors.white : kDeskMuted,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _DossieMonthTile extends StatelessWidget {
  const _DossieMonthTile({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: selected
            ? BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  color: selected ? Colors.white : kDeskMuted,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(fontSize: 10, color: kDeskMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DossieEventRow extends ConsumerStatefulWidget {
  const _DossieEventRow({
    required this.event,
    required this.token,
    required this.commissionRate,
  });
  final StaffEvent event;
  final String token;
  final double commissionRate;

  @override
  ConsumerState<_DossieEventRow> createState() => _DossieEventRowState();
}

class _DossieEventRowState extends ConsumerState<_DossieEventRow> {
  bool _busy = false;

  Future<void> _download(Future<String> Function() action, String label) async {
    setState(() => _busy = true);
    try {
      final path = await action();
      if (!mounted) return;
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label guardado: $path')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final api = ref.read(apiProvider);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x15FFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${e.eventDate}${e.location != null ? ' · ${e.location}' : ''}',
                  style: TextStyle(fontSize: 11, color: kDeskMuted),
                ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Wrap(
              spacing: 6,
              children: [
                _DossieActionButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Galeria',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StaffEventPhotosPage(
                        eventId: e.id,
                        eventName: e.name,
                      ),
                    ),
                  ),
                ),
                _DossieActionButton(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'PDF Pedidos',
                  onTap: () => _download(
                    () => api.staffExportOrdersPdf(widget.token, e.id),
                    'PDF pedidos',
                  ),
                ),
                _DossieActionButton(
                  icon: Icons.bar_chart,
                  label: 'PDF Vendas',
                  onTap: () => _download(
                    () => api.staffExportSalesPdf(
                      widget.token,
                      e.id,
                      commissionRate: widget.commissionRate,
                    ),
                    'PDF vendas',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DossieActionButton extends StatelessWidget {
  const _DossieActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: kDeskMuted),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: kDeskMuted)),
          ],
        ),
      ),
    );
  }
}

// ─── StaffEventPhotosPage (used from Dossiê) ──────────────────────────────

class StaffEventPhotosPage extends ConsumerStatefulWidget {
  const StaffEventPhotosPage({
    super.key,
    required this.eventId,
    required this.eventName,
  });
  final int eventId;
  final String eventName;

  @override
  ConsumerState<StaffEventPhotosPage> createState() =>
      _StaffEventPhotosPageState();
}

class _StaffEventPhotosPageState extends ConsumerState<StaffEventPhotosPage> {
  Future<List<StaffPhoto>>? _future;

  @override
  void initState() {
    super.initState();
    final token = ref.read(staffTokenProvider);
    if (token != null) {
      _future = ref
          .read(apiProvider)
          .staffEventPhotos(token, widget.eventId, '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.eventName)),
      body: FutureBuilder<List<StaffPhoto>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.hasError) {
              return Center(child: Text('Erro: ${snap.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final photos = snap.data!;
          if (photos.isEmpty) {
            return const Center(child: Text('Sem fotos neste evento.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: photos.length,
            itemBuilder: (context, i) {
              final photo = photos[i];
              return Column(
                children: [
                  Expanded(
                    child: photo.previewUrl != null
                        ? Image.network(photo.previewUrl!, fit: BoxFit.cover)
                        : Container(
                            color: kDeskCard,
                            child: const Icon(Icons.image_not_supported),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(photo.number, style: const TextStyle(fontSize: 10)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Users view ─────────────────────────────────────────────────────────────
class DesktopUsersView extends ConsumerStatefulWidget {
  const DesktopUsersView({super.key, required this.user, required this.token});
  final StaffUser user;
  final String token;

  @override
  ConsumerState<DesktopUsersView> createState() => _DesktopUsersViewState();
}

class _DesktopUsersViewState extends ConsumerState<DesktopUsersView> {
  Future<List<StaffUser>>? _future;
  final TextEditingController _queryCtrl = TextEditingController();

  Future<List<StaffUser>> _loadUsers() =>
      ref.read(apiProvider).staffUsers(widget.token);

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _future ??= _loadUsers();
    return FutureBuilder<List<StaffUser>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(kDeskGutter),
              child: _DeskCard(child: Text('Erro: ${snap.error}')),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }
        final users = snap.data!;
        final query = _queryCtrl.text.trim().toLowerCase();
        final visible = query.isEmpty
            ? users
            : users.where((staffUser) {
                final blob = [
                  staffUser.name,
                  staffUser.username ?? '',
                  staffUser.email,
                  staffUser.role,
                ].join(' ').toLowerCase();
                return blob.contains(query);
              }).toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(kDeskGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: _DeskSectionHeader('Utilizadores')),
                  if (widget.user.hasPermission('users.create'))
                    FilledButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StaffUserFormPage(),
                          ),
                        );
                        if (mounted) setState(() => _future = null);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Novo utilizador'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _queryCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Pesquisar nome, email, username ou role',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (users.isEmpty)
                const _DeskCard(child: Text('Sem utilizadores.'))
              else if (visible.isEmpty)
                const _DeskCard(child: Text('Sem resultados.'))
              else
                ...visible.map((staffUser) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DeskCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: kBrandRose.withOpacity(0.18),
                            foregroundColor: kBrandRose,
                            child: Text(
                              _initialsFromName(staffUser.name).toUpperCase(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  staffUser.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if ((staffUser.username ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      _DeskStatusBadge(
                                        '@${staffUser.username!.trim()}',
                                      ),
                                    _DeskStatusBadge(
                                      staffUser.role.toUpperCase(),
                                      color: Colors.lightBlueAccent,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  staffUser.email,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.72),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (widget.user.hasPermission('users.update'))
                                _MobileActionChip(
                                  label: 'Editar',
                                  color: kBrandRose,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StaffUserFormPage(user: staffUser),
                                      ),
                                    );
                                    if (mounted) setState(() => _future = null);
                                  },
                                ),
                              if (widget.user.hasPermission('users.delete'))
                                _MobileActionChip(
                                  label: 'Apagar',
                                  color: Colors.redAccent,
                                  onTap: () async {
                                    final ok = await _confirm(
                                      context,
                                      'Apagar utilizador?',
                                      staffUser.email,
                                    );
                                    if (!ok) return;
                                    await ref
                                        .read(apiProvider)
                                        .deleteUser(widget.token, staffUser.id);
                                    if (mounted) {
                                      setState(() => _future = null);
                                    }
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class DesktopSettingsView extends ConsumerStatefulWidget {
  const DesktopSettingsView({
    super.key,
    required this.user,
    required this.token,
  });
  final StaffUser user;
  final String token;

  @override
  ConsumerState<DesktopSettingsView> createState() =>
      _DesktopSettingsViewState();
}

class _DesktopSettingsViewState extends ConsumerState<DesktopSettingsView> {
  late final TextEditingController nameCtrl;
  late final TextEditingController usernameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController passwordCtrl;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.user.name);
    usernameCtrl = TextEditingController(text: widget.user.username ?? '');
    emailCtrl = TextEditingController(text: widget.user.email);
    passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdminRole(widget.user.role);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDeskGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DeskSectionHeader('Definicoes do perfil'),
          const SizedBox(height: 12),
          _DeskCard(
            child: Column(
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username (opcional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nova password (opcional)',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Spacer(),
                    FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              final email = emailCtrl.text.trim();
                              if (name.isEmpty || email.isEmpty) return;
                              setState(() => saving = true);
                              try {
                                final updated = await ref
                                    .read(apiProvider)
                                    .updateProfile(
                                      widget.token,
                                      name: name,
                                      email: email,
                                      username: usernameCtrl.text.trim(),
                                      password: passwordCtrl.text.trim(),
                                    );
                                ref.read(staffUserProvider.notifier).state =
                                    updated;
                                passwordCtrl.clear();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Definições atualizadas.'),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erro: $e')),
                                );
                              } finally {
                                if (mounted) setState(() => saving = false);
                              }
                            },
                      child: Text(saving ? 'A guardar...' : 'Guardar'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(staffTokenProvider.notifier).state = null;
                      ref.read(staffUserProvider.notifier).state = null;
                      clearStaffSession();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomePage()),
                        (_) => false,
                      );
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Terminar sessão'),
                  ),
                ),
              ],
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 24),
            const AppRuntimeConfigForm(embedded: true),
          ],
        ],
      ),
    );
  }
}

class DesktopAppConfigView extends StatelessWidget {
  const DesktopAppConfigView({
    super.key,
    required this.user,
    required this.token,
  });
  final StaffUser user;
  final String token;

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(kDeskGutter),
      child: AppRuntimeConfigForm(embedded: true),
    );
  }
}

class DesktopServicesView extends ConsumerStatefulWidget {
  const DesktopServicesView({
    super.key,
    required this.user,
    required this.token,
  });
  final StaffUser user;
  final String token;

  @override
  ConsumerState<DesktopServicesView> createState() =>
      _DesktopServicesViewState();
}

class _DesktopServicesViewState extends ConsumerState<DesktopServicesView> {
  Future<List<StaffEvent>>? _future;
  String? _token;
  bool? _assignedOnly;
  String? _fromDate;
  DateTime _focusedDay = _startOfDay(DateTime.now());
  DateTime? _selectedDay;

  void _ensureFuture(
    String token, {
    required bool assignedOnly,
    String? fromDate,
  }) {
    if (_future == null ||
        _token != token ||
        _assignedOnly != assignedOnly ||
        _fromDate != fromDate) {
      _token = token;
      _assignedOnly = assignedOnly;
      _fromDate = fromDate;
      _future = ref
          .read(apiProvider)
          .staffEvents(token, assignedOnly: assignedOnly, fromDate: fromDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCalendar =
        widget.user.hasPermission('events.list') ||
        widget.user.hasPermission('events.view');
    final canSeeAllEvents = _canSeeAllEvents(widget.user);
    final now = DateTime.now();
    final fromDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (canCalendar) {
      _ensureFuture(
        widget.token,
        assignedOnly: !canSeeAllEvents,
        fromDate: fromDate,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDeskGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeskSectionHeader('Agenda'),
          const SizedBox(height: 12),
          if (!canCalendar)
            const _DeskCard(child: Text('Sem permissões para ver a agenda.'))
          else
            FutureBuilder<List<StaffEvent>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const _DeskCard(
                    child: SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                final events = _filterEventsForUser(
                  snap.data ?? const <StaffEvent>[],
                  widget.user,
                );
                if (events.isEmpty) {
                  return const _DeskCard(
                    child: Text('Sem eventos disponíveis.'),
                  );
                }
                final eventsByDay = _eventsByDay(events);
                final selected = _selectedDay ?? _focusedDay;
                final selectedKey = _startOfDay(selected);
                final dayEvents =
                    eventsByDay[selectedKey] ?? const <StaffEvent>[];

                final weekStart = selectedKey.subtract(
                  Duration(days: selectedKey.weekday % 7),
                );
                final weekEnd = weekStart.add(const Duration(days: 6));
                final weekCount = events.where((e) {
                  final date = _parseEventDate(e.eventDate);
                  if (date == null) return false;
                  return !date.isBefore(weekStart) &&
                      !date.isAfter(weekEnd) &&
                      date.month == selectedKey.month &&
                      date.year == selectedKey.year;
                }).length;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _DeskCard(
                        child: Column(
                          children: [
                            TableCalendar<StaffEvent>(
                              firstDay: _calendarFirstDay(events),
                              lastDay: _calendarLastDay(events),
                              focusedDay: _focusedDay,
                              selectedDayPredicate: (day) =>
                                  isSameDay(_selectedDay, day),
                              eventLoader: (day) =>
                                  eventsByDay[_startOfDay(day)] ??
                                  const <StaffEvent>[],
                              availableGestures: AvailableGestures.all,
                              pageJumpingEnabled: true,
                              headerStyle: const HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                              ),
                              calendarStyle: CalendarStyle(
                                outsideDaysVisible: false,
                                todayDecoration: BoxDecoration(
                                  color: kBrandRose.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                                selectedDecoration: const BoxDecoration(
                                  color: kBrandRose,
                                  shape: BoxShape.circle,
                                ),
                                markerDecoration: const BoxDecoration(
                                  color: kBrandRose,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              calendarBuilders: CalendarBuilders(
                                markerBuilder: (context, date, events) {
                                  if (events.isEmpty)
                                    return const SizedBox.shrink();
                                  return Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: kBrandRose,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${events.length}',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              onPageChanged: (focusedDay) {
                                setState(() {
                                  _focusedDay = focusedDay;
                                });
                              },
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Eventos do dia',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (dayEvents.isEmpty)
                              const Text('Sem eventos neste dia')
                            else
                              ...dayEvents.map(
                                (e) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(e.name),
                                  subtitle: Text(
                                    _formatEventDateTime(
                                      e.eventDate,
                                      e.eventTime,
                                    ),
                                  ),
                                  trailing: Wrap(
                                    spacing: 8,
                                    children: [
                                      if (widget.user.hasPermission(
                                        'events.view',
                                      ))
                                        TextButton(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  StaffEventDetailPage(
                                                    event: e,
                                                  ),
                                            ),
                                          ),
                                          child: const Text('Detalhe'),
                                        ),
                                      if (widget.user.hasPermission(
                                        'events.update',
                                      ))
                                        TextButton(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  StaffEventStaffPage(event: e),
                                            ),
                                          ),
                                          child: const Text('Equipe'),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _DeskCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resumo da agenda',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Servicos esta semana: $weekCount',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Eventos totais: ${events.length}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Selecionado: ${_formatEventDateTime(selectedKey.toIso8601String(), '')}'
                                  .split(' ')
                                  .first,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class StaffEventsPage extends ConsumerStatefulWidget {
  const StaffEventsPage({super.key});

  @override
  ConsumerState<StaffEventsPage> createState() => _StaffEventsPageState();
}

class _StaffEventsPageState extends ConsumerState<StaffEventsPage> {
  Future<List<StaffEvent>>? _future;
  String? _lastToken;
  String? _lastEventType;
  String _eventType = '';
  List<StaffServiceTemplate> _serviceTemplates = const [];
  List<StaffEvent> _orderEvents(List<StaffEvent> events) {
    final ordered = List<StaffEvent>.from(events);
    ordered.sort((a, b) {
      final aNum = _numericReportNumberValue(a);
      final bNum = _numericReportNumberValue(b);
      if (aNum == bNum) {
        final aDate = _parseEventDate(a.eventDate);
        final bDate = _parseEventDate(b.eventDate);
        if (aDate != null && bDate != null) {
          return bDate.compareTo(aDate);
        }
        return b.id.compareTo(a.id);
      }
      return bNum.compareTo(aNum);
    });
    return ordered;
  }

  @override
  void initState() {
    super.initState();
    saveStaffLastRoute('events', userId: ref.read(staffUserProvider)?.id);
    _loadServiceTemplates();
    _reload();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _openPdf(BuildContext context, StaffEvent event) async {
    final token = ref.read(staffTokenProvider);
    if (token == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
    try {
      final bytes = await ref.read(apiProvider).staffEventPdf(token, event.id);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/evento-${event.id}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      if (!context.mounted) return;
      await OpenFilex.open(file.path);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro a gerar PDF: $e')));
    } finally {
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _reload() {
    final token = ref.read(staffTokenProvider);
    if (token == null) return;
    final user = ref.read(staffUserProvider);
    final assignedOnly = user?.role != 'admin';
    _lastToken = token;
    _lastEventType = _eventType;
    _future = ref
        .read(apiProvider)
        .staffEvents(
          token,
          eventType: _eventType.isEmpty ? null : _eventType,
          assignedOnly: assignedOnly,
        );
    setState(() {});
  }

  Future<void> _loadServiceTemplates() async {
    final token = ref.read(staffTokenProvider);
    if (token == null) return;
    try {
      final templates = await ref.read(apiProvider).staffServiceTemplates(token);
      if (!mounted) return;
      templates.sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) return order;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      setState(() => _serviceTemplates = templates);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null)
      return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    if (useDesktopLayout(context)) {
      return StaffDesktopShell(user: user, token: token, initialId: 'events');
    }
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (_future == null ||
        _lastToken != token ||
        _lastEventType != _eventType) {
      _lastToken = token;
      _lastEventType = _eventType;
      final assignedOnly = user.role != 'admin';
      _future = ref
          .read(apiProvider)
          .staffEvents(
            token,
            eventType: _eventType.isEmpty ? null : _eventType,
            assignedOnly: assignedOnly,
          );
    }

    final availableTemplates = _serviceTemplates.isNotEmpty
        ? _serviceTemplates
        : [
            StaffServiceTemplate(
              id: 0,
              slug: 'casamento',
              name: 'Casamento',
              fields: const [],
            ),
            StaffServiceTemplate(
              id: 0,
              slug: 'batizado',
              name: 'Batizado',
              fields: const [],
            ),
          ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos'),
        leading: navLeading(context),
        actions: navActions(context),
      ),
      floatingActionButton: (!isWide && user.hasPermission('events.create'))
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StaffEventFormPage(initialEventType: _eventType),
                  ),
                );
                _reload();
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<StaffEvent>>(
          future: _future,
          builder: (_, snap) {
            if (!snap.hasData) {
              if (snap.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Erro: ${snap.error}'),
                    ),
                  ],
                );
              }
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            final events = _orderEvents(_filterEventsForUser(snap.data!, user));
            Widget filters() {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('TODOS'),
                          selected: _eventType.isEmpty,
                          onSelected: (v) {
                            if (!v) return;
                            setState(() => _eventType = '');
                            _reload();
                          },
                          selectedColor: kBrandRose,
                          labelStyle: TextStyle(
                            color: _eventType.isEmpty
                                ? kBrandBlack
                                : kBrandRose,
                          ),
                          side: BorderSide(
                            color: kBrandRose.withOpacity(0.8),
                          ),
                        ),
                        ...availableTemplates.map(
                          (template) => ChoiceChip(
                            label: Text(template.name.toUpperCase()),
                            selected: _eventType == template.slug,
                            onSelected: (v) {
                              if (!v) return;
                              setState(() => _eventType = template.slug);
                              _reload();
                            },
                            selectedColor: kBrandRose,
                            labelStyle: TextStyle(
                              color: _eventType == template.slug
                                  ? kBrandBlack
                                  : kBrandRose,
                            ),
                            side: BorderSide(
                              color: kBrandRose.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            _loadServiceTemplates();
                            _reload();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Atualizar'),
                        ),
                        if (isWide && user.hasPermission('events.create'))
                          FilledButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StaffEventFormPage(
                                    initialEventType: _eventType,
                                  ),
                                ),
                              );
                              _reload();
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Novo'),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }
            if (events.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  filters(),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sem eventos'),
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: events.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return filters();
                }
                final e = events[i - 1];
                final report = _displayReportNumber(e);
                final subtitleParts = <String>[
                  if (report != null && report.isNotEmpty) 'Nº $report',
                  if (e.eventDate.isNotEmpty)
                    _formatEventDateTime(e.eventDate, e.eventTime),
                  if (e.location != null && e.location!.isNotEmpty) e.location!,
                ];
                final subtitle = subtitleParts.isEmpty
                    ? ''
                    : subtitleParts.join(' • ');
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: InkWell(
                    onTap: user.hasPermission('events.view')
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StaffEventDetailPage(event: e),
                            ),
                          )
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: kBrandBlack,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBrandRose),
                        boxShadow: [
                          BoxShadow(
                            color: kBrandRose.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: kBrandRose.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (e.qrToken != null && e.qrToken!.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.qr_code_2),
                                  onPressed: () {
                                    final url = ref
                                        .read(apiProvider)
                                        .publicQrUrl(e.qrToken!);
                                    showQrDialog(
                                      context,
                                      title: 'QR Code do Evento',
                                      url: url,
                                    );
                                  },
                                ),
                              if (user.hasPermission('events.update'))
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StaffEventFormPage(event: e),
                                      ),
                                    );
                                    _reload();
                                  },
                                ),
                              if (user.hasPermission('events.delete'))
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final ok = await _confirm(
                                      context,
                                      'Apagar evento?',
                                      'Isto remove fotos e uploads.',
                                    );
                                    if (!ok) return;
                                    await ref
                                        .read(apiProvider)
                                        .deleteEvent(token, e.id);
                                    if (!mounted) return;
                                    _reload();
                                  },
                                ),
                              if (user.hasPermission('events.view'))
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf),
                                  onPressed: () => _openPdf(context, e),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class StaffEventFormPage extends ConsumerStatefulWidget {
  const StaffEventFormPage({super.key, this.event, this.initialEventType});
  final StaffEvent? event;
  final String? initialEventType;

  @override
  ConsumerState<StaffEventFormPage> createState() => _StaffEventFormPageState();
}

class StaffEventDetailPage extends ConsumerWidget {
  const StaffEventDetailPage({super.key, required this.event});
  final StaffEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = event.eventMeta ?? {};
    final user = ref.watch(staffUserProvider);
    final canViewPricing = _canViewEventPricing(user);
    final canViewInternal = _canViewEventInternal(user);
    final token = ref.watch(staffTokenProvider);
    if (useDesktopLayout(context) && user != null && token != null) {
      return StaffDesktopShell(
        user: user,
        token: token,
        initialId: 'events',
        overrideTitle: 'Detalhe do Evento',
        overrideSubtitle: event.name,
        overrideShowSearch: false,
        overrideContent: (ctx, u, t) => DesktopEventDetailView(
          event: event,
          canViewPricing: canViewPricing,
          canViewInternal: canViewInternal,
        ),
      );
    }
    return Scaffold(
      appBar: buildNavAppBar(context, 'Detalhe do Evento'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EventHeroCard(event: event, canViewInternal: canViewInternal),
          const SizedBox(height: 16),
          _EventStatsGrid(
            event: event,
            canViewPricing: canViewPricing,
            canViewInternal: canViewInternal,
          ),
          if (event.notes != null && event.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _DeskCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notas',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(event.notes!.trim()),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _EventActionCard(event: event, user: user, token: token),
          const SizedBox(height: 16),
          if (_eventMetaEntries(meta, user).isNotEmpty) ...[
            _DeskCard(child: _EventMetaSection(meta: meta, user: user)),
          ],
        ],
      ),
    );
  }
}

class DesktopEventDetailView extends ConsumerWidget {
  const DesktopEventDetailView({
    super.key,
    required this.event,
    required this.canViewPricing,
    required this.canViewInternal,
  });
  final StaffEvent event;
  final bool canViewPricing;
  final bool canViewInternal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = event.eventMeta ?? {};
    final user = ref.watch(staffUserProvider);
    final token = ref.watch(staffTokenProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDeskGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeskSectionHeader('Resumo'),
          const SizedBox(height: 12),
          _EventHeroCard(event: event, canViewInternal: canViewInternal),
          const SizedBox(height: 20),
          _DeskSectionHeader('Informação'),
          const SizedBox(height: 12),
          _EventStatsGrid(
            event: event,
            canViewPricing: canViewPricing,
            canViewInternal: canViewInternal,
          ),
          if (event.notes != null && event.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            _DeskSectionHeader('Notas'),
            const SizedBox(height: 12),
            _DeskCard(child: Text(event.notes!.trim())),
          ],
          const SizedBox(height: 20),
          _DeskSectionHeader('Ações'),
          const SizedBox(height: 12),
          _EventActionCard(event: event, user: user, token: token),
          if (_eventMetaEntries(meta, user).isNotEmpty) ...[
            const SizedBox(height: 20),
            _DeskSectionHeader('Detalhes'),
            const SizedBox(height: 12),
            _DeskCard(child: _EventMetaSection(meta: meta, user: user)),
          ],
        ],
      ),
    );
  }
}

class _EventHeroCard extends StatelessWidget {
  const _EventHeroCard({
    required this.event,
    required this.canViewInternal,
  });

  final StaffEvent event;
  final bool canViewInternal;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _EventBadge(
        icon: Icons.event_outlined,
        label: _formatEventDateTime(event.eventDate, event.eventTime),
      ),
      if ((event.eventType ?? '').trim().isNotEmpty)
        _EventBadge(
          icon: Icons.auto_awesome_mosaic_outlined,
          label: event.eventType!.trim(),
        ),
      if (_displayReportNumber(event) != null)
        _EventBadge(
          icon: Icons.confirmation_number_outlined,
          label: 'Rpt. ${_displayReportNumber(event)}',
        ),
      if (canViewInternal && (event.accessPin ?? '').trim().isNotEmpty)
        _EventBadge(
          icon: Icons.lock_outline,
          label: 'PIN ${event.accessPin!.trim()}',
        ),
    ];

    return _DeskCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          if ((event.location ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                event.location!.trim(),
                style: const TextStyle(color: kDeskMuted, fontSize: 15),
              ),
            ),
          Wrap(spacing: 10, runSpacing: 10, children: chips),
        ],
      ),
    );
  }
}

class _EventStatsGrid extends StatelessWidget {
  const _EventStatsGrid({
    required this.event,
    required this.canViewPricing,
    required this.canViewInternal,
  });

  final StaffEvent event;
  final bool canViewPricing;
  final bool canViewInternal;

  @override
  Widget build(BuildContext context) {
    final cards = <_EventInfoCardData>[
      if (canViewPricing)
        _EventInfoCardData(
          icon: Icons.sell_outlined,
          title: 'Preço por foto',
          value: _formatEventMoney(event.pricePerPhoto),
        ),
      if (canViewPricing && event.basePrice != null)
        _EventInfoCardData(
          icon: Icons.payments_outlined,
          title: 'Preço base',
          value: _formatEventMoney(event.basePrice!),
        ),
      if (canViewInternal)
        _EventInfoCardData(
          icon: Icons.badge_outlined,
          title: 'Estado',
          value: event.isLocked ? 'Fechado' : 'Ativo',
        ),
      _EventInfoCardData(
        icon: Icons.category_outlined,
        title: 'Tipo',
        value: (event.eventType ?? '').trim().isEmpty
            ? '-'
            : event.eventType!.trim(),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 620
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (card) => SizedBox(
                  width: width,
                  child: _EventInfoCard(data: card),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _EventActionCard extends ConsumerWidget {
  const _EventActionCard({
    required this.event,
    required this.user,
    required this.token,
  });

  final StaffEvent event;
  final StaffUser? user;
  final String? token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _DeskCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fullWidth = constraints.maxWidth < 620;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (user != null && user!.hasPermission('events.update'))
                SizedBox(
                  width: fullWidth ? constraints.maxWidth : null,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StaffEventStaffPage(event: event),
                        ),
                      );
                    },
                    icon: const Icon(Icons.groups_2_outlined),
                    label: const Text('Gerir staff do evento'),
                  ),
                ),
              if (isDesktopPlatform())
                SizedBox(
                  width: fullWidth ? constraints.maxWidth : null,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              StaffOfflineHostPage(seedEvent: event),
                        ),
                      );
                    },
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('Abrir sessão offline'),
                  ),
                ),
              SizedBox(
                width: fullWidth ? constraints.maxWidth : null,
                child: FilledButton.tonalIcon(
                  onPressed: token == null
                      ? null
                      : () => _openEventPdf(context, ref, token!, event),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Abrir PDF'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EventMetaSection extends StatelessWidget {
  const _EventMetaSection({required this.meta, required this.user});

  final Map<String, dynamic> meta;
  final StaffUser? user;

  @override
  Widget build(BuildContext context) {
    final groups = _eventMetaGroups(meta, user);
    if (groups.isEmpty) {
      return const Text('Sem detalhes adicionais.');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 760;
        final width = narrow
            ? constraints.maxWidth
            : (constraints.maxWidth - 16) / 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalhes',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: groups
                  .map(
                    (group) => SizedBox(
                      width: width,
                      child: _EventMetaGroupCard(group: group),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}

class _EventMetaGroup {
  const _EventMetaGroup({
    required this.title,
    required this.icon,
    required this.entries,
  });

  final String title;
  final IconData icon;
  final List<MapEntry<String, String>> entries;
}

class _EventMetaGroupCard extends StatelessWidget {
  const _EventMetaGroupCard({required this.group});

  final _EventMetaGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDeskCardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBrandRose.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(group.icon, size: 18, color: kBrandRose),
              const SizedBox(width: 8),
              Text(
                group.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...group.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: kDeskMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(entry.value, style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventInfoCardData {
  const _EventInfoCardData({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;
}

class _EventInfoCard extends StatelessWidget {
  const _EventInfoCard({required this.data});

  final _EventInfoCardData data;

  @override
  Widget build(BuildContext context) {
    return _DeskCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kBrandRose.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: kBrandRose),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: kDeskMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventBadge extends StatelessWidget {
  const _EventBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: kDeskCardAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBrandRose.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: kBrandRose),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

Future<void> _openEventPdf(
  BuildContext context,
  WidgetRef ref,
  String token,
  StaffEvent event,
) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      ),
    ),
  );
  try {
    final bytes = await ref.read(apiProvider).staffEventPdf(token, event.id);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/evento-${event.id}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    if (!context.mounted) return;
    await OpenFilex.open(file.path);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Erro a gerar PDF: $e')));
  } finally {
    if (context.mounted) Navigator.pop(context);
  }
}

List<MapEntry<String, String>> _eventMetaEntries(
  Map<String, dynamic> meta,
  StaffUser? user,
) {
  return meta.entries
      .map((entry) {
        if (!_shouldShowEventMetaKey(entry.key, user)) return null;
        final value = _normalizeEventMetaValue(entry.value);
        if (value == null) return null;
        return MapEntry(_prettyMetaKey(entry.key), value);
      })
      .whereType<MapEntry<String, String>>()
      .toList();
}

List<_EventMetaGroup> _eventMetaGroups(
  Map<String, dynamic> meta,
  StaffUser? user,
) {
  final buckets = <String, List<MapEntry<String, String>>>{
    'Casal': [],
    'Família': [],
    'Locais': [],
    'Horários': [],
    'Evento': [],
    'Outros': [],
  };

  for (final entry in meta.entries) {
    if (!_shouldShowEventMetaKey(entry.key, user)) continue;
    final value = _normalizeEventMetaValue(entry.value);
    if (value == null) continue;
    final label = _prettyMetaKey(entry.key);
    buckets[_eventMetaBucket(entry.key)]!.add(MapEntry(label, value));
  }

  const icons = <String, IconData>{
    'Casal': Icons.favorite_border,
    'Família': Icons.people_outline,
    'Locais': Icons.place_outlined,
    'Horários': Icons.schedule_outlined,
    'Evento': Icons.celebration_outlined,
    'Outros': Icons.notes_outlined,
  };

  return buckets.entries
      .where((entry) => entry.value.isNotEmpty)
      .map(
        (entry) => _EventMetaGroup(
          title: entry.key,
          icon: icons[entry.key] ?? Icons.notes_outlined,
          entries: entry.value,
        ),
      )
      .toList();
}

bool _shouldShowEventMetaKey(String key, StaffUser? user) {
  final normalized = _normalizeEventMetaVisibilityKey(key);

  const hiddenForEveryone = {
    'sourcefiles',
    'servicode',
    'serviceraw',
    'noivo',
    'noiva',
    'bebe',
    'pai',
    'mae',
    'padrinho',
    'madrinha',
    'clientenoivonum',
    'clientenoivanum',
    'clientebatizadonum',
  };

  if (hiddenForEveryone.contains(normalized)) {
    return false;
  }

  if (user != null && !_isAdminRole(user.role)) {
    if (normalized.contains('raw')) {
      return false;
    }

    const hiddenForPhotographers = {
      'cliente',
      'dataentrega',
      'extra',
      'preco',
      'precobase',
      'valorcontrato',
      'reportagemn',
    };

    if (hiddenForPhotographers.contains(normalized)) {
      return false;
    }
  }

  return true;
}

String _normalizeEventMetaVisibilityKey(String key) {
  final lower = key.trim().toLowerCase();
  final stripped = lower
      .replaceAll(RegExp(r'[áàâãä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòôõö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ç', 'c');
  return stripped.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String _eventMetaBucket(String key) {
  if (key.contains('noivo_') || key.contains('noiva_')) return 'Casal';
  if (key.contains('pai') ||
      key.contains('mae') ||
      key.contains('padrinho') ||
      key.contains('madrinha') ||
      key.contains('filho_de')) {
    return 'Família';
  }
  if (key.contains('morada') ||
      key.contains('igreja') ||
      key.contains('quinta') ||
      key.contains('localidade') ||
      key.contains('casa_')) {
    return 'Locais';
  }
  if (key.contains('hora') ||
      key.contains('chegada') ||
      key.contains('saida') ||
      key.contains('entrega') ||
      key.contains('loja')) {
    return 'Horários';
  }
  if (key.contains('convidados') ||
      key.contains('equipa') ||
      key.contains('pacote') ||
      key.contains('bebe') ||
      key == 'contacto_pais') {
    return 'Evento';
  }
  return 'Outros';
}

String? _normalizeEventMetaValue(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  if (text.toLowerCase() == 'null') return null;
  return text;
}

String _formatEventMoney(num value) {
  final amount = value.toDouble();
  if (amount == amount.roundToDouble()) {
    return '${amount.toStringAsFixed(0)}€';
  }
  return '${amount.toStringAsFixed(2)}€';
}

String _prettyMetaKey(String key) {
  switch (key) {
    case 'noivo_nome':
      return 'Nome do noivo';
    case 'noiva_nome':
      return 'Nome da noiva';
    case 'noivo_contacto':
      return 'Contacto do noivo';
    case 'noiva_contacto':
      return 'Contacto da noiva';
    case 'noivo_profissao':
      return 'Profissão do noivo';
    case 'noiva_profissao':
      return 'Profissão da noiva';
    case 'noivo_instagram':
      return 'Instagram do noivo';
    case 'noiva_instagram':
      return 'Instagram da noiva';
    case 'noivo_filho_de_1':
      return 'Filho de (pai)';
    case 'noivo_filho_de_2':
      return 'Filho de (mãe)';
    case 'noiva_filho_de_1':
      return 'Filha de (pai)';
    case 'noiva_filho_de_2':
      return 'Filha de (mãe)';
    case 'noivo_morada':
      return 'Morada do noivo';
    case 'noiva_morada':
      return 'Morada da noiva';
    case 'noivo_coordenadas':
      return 'Coordenadas do noivo';
    case 'noiva_coordenadas':
      return 'Coordenadas da noiva';
    case 'missa_hora':
      return 'Hora da missa';
    case 'casa_noivo_chegada':
      return 'Casa do noivo: chegada';
    case 'casa_noivo_saida':
      return 'Casa do noivo: saída';
    case 'casa_noiva_chegada':
      return 'Casa da noiva: chegada';
    case 'casa_noiva_saida':
      return 'Casa da noiva: saída';
    case 'igreja_local':
      return 'Igreja';
    case 'igreja_localidade':
      return 'Localidade (igreja)';
    case 'quinta_local':
      return 'Quinta';
    case 'almoco_localidade':
      return 'Localidade do almoço';
    case 'instagram_noivos':
      return 'Instagram dos noivos';
    case 'instagram_pais':
      return 'Instagram dos pais';
    case 'numero_convidados':
      return 'Número de convidados';
    case 'data_entrega':
      return 'Data de entrega';
    case 'estar_na_loja_as':
      return 'Estar na loja às';
    case 'equipa_de_trabalho':
      return 'Equipa de trabalho';
    case 'tipo_pacote':
      return 'Tipo de pacote';
    case 'bebe_nome':
      return 'Nome do bebé';
    case 'pai_nome':
      return 'Nome do pai';
    case 'mae_nome':
      return 'Nome da mãe';
    case 'padrinho_nome':
      return 'Nome do padrinho';
    case 'madrinha_nome':
      return 'Nome da madrinha';
    case 'contacto_pais':
      return 'Contacto dos pais';
    case 'morada':
      return 'Morada';
    default:
      return key.replaceAll('_', ' ');
  }
}

class _StaffEventFormPageState extends ConsumerState<StaffEventFormPage> {
  late final TextEditingController reportNumberCtrl;
  late final TextEditingController basePriceCtrl;
  late final TextEditingController dateCtrl;
  late final TextEditingController timeCtrl;
  late final TextEditingController locationCtrl;
  late final TextEditingController cityCtrl;
  late final TextEditingController addressCtrl;
  late final TextEditingController address2Ctrl;
  late final TextEditingController deliveryDateEventCtrl;
  late final TextEditingController guestCountEventCtrl;
  late final TextEditingController pinCtrl;
  late final TextEditingController priceCtrl;
  late final TextEditingController notesCtrl;
  late final TextEditingController noivoNomeCtrl;
  late final TextEditingController noivaNomeCtrl;
  late final TextEditingController noivoContactoCtrl;
  late final TextEditingController noivaContactoCtrl;
  late final TextEditingController noivoProfissaoCtrl;
  late final TextEditingController noivaProfissaoCtrl;
  late final TextEditingController noivoMoradaCtrl;
  late final TextEditingController noivaMoradaCtrl;
  late final TextEditingController noivoInstagramCtrl;
  late final TextEditingController noivaInstagramCtrl;
  late final TextEditingController noivoFilhoDe1Ctrl;
  late final TextEditingController noivoFilhoDe2Ctrl;
  late final TextEditingController noivaFilhoDe1Ctrl;
  late final TextEditingController noivaFilhoDe2Ctrl;
  late final TextEditingController noivoCoordenadasCtrl;
  late final TextEditingController noivaCoordenadasCtrl;
  late final TextEditingController missaHoraCtrl;
  late final TextEditingController igrejaLocalidadeCtrl;
  late final TextEditingController almocoLocalidadeCtrl;
  late final TextEditingController numeroConvidadosCtrl;
  late final TextEditingController instagramPaisCtrl;
  late final TextEditingController casaNoivoChegadaCtrl;
  late final TextEditingController casaNoivoSaidaCtrl;
  late final TextEditingController casaNoivaChegadaCtrl;
  late final TextEditingController casaNoivaSaidaCtrl;
  late final TextEditingController dataEntregaCtrl;
  late final TextEditingController equipaTrabalhoCtrl;
  late final TextEditingController teamCountCtrl;
  late final TextEditingController bebeNomeCtrl;
  late final TextEditingController paiNomeCtrl;
  late final TextEditingController maeNomeCtrl;
  late final TextEditingController padrinhoNomeCtrl;
  late final TextEditingController madrinhaNomeCtrl;
  late final TextEditingController contactoPaisCtrl;
  late final TextEditingController batizadoMoradaCtrl;
  late final TextEditingController servicoTelaCtrl;
  late final TextEditingController servicoUsbCtrl;
  late final TextEditingController servicoCondicoesCtrl;
  late final TextEditingController servicoMusicasCtrl;
  late final TextEditingController servicoExtrasCtrl;
  bool saving = false;
  String eventType = '';
  String igrejaTipo = '';
  String refeicaoTipo = '';
  bool isLocked = false;
  bool servicoSaveTheDate = false;
  bool servicoFotosLoveStory = false;
  bool servicoVideoLoveStory = false;
  bool servicoProjectarLoveStory = false;
  bool servicoComboBelezaLoveStory = false;
  bool servicoAlbumDigital305 = false;
  bool servicoComboBelezaTtd = false;
  bool servicoAlbumDigital = false;
  bool servicoAlbumConvidados = false;
  bool servicoAlbuns4020 = false;
  bool servicoSameDayEdit = false;
  bool servicoProjectarSameDayEdit = false;
  bool servicoGaleriaDigitalConvidados = false;
  bool servicoFotoLembrancaQr = false;
  bool servicoImpressao100 = false;
  bool servicoVideoDepoisDoSim = false;
  bool servicoDrone = false;
  List<StaffUser> _teamUsers = [];
  List<StaffUser> _matchedTeamUsers = [];
  List<String> _unknownTeamTokens = [];
  int _teamCount = 0;
  List<StaffServiceTemplate> _serviceTemplates = const [];
  final Map<String, TextEditingController> _dynamicControllers = {};

  @override
  void initState() {
    super.initState();
    reportNumberCtrl = TextEditingController(
      text: widget.event != null
          ? (_displayReportNumber(widget.event!) ?? '')
          : '',
    );
    basePriceCtrl = TextEditingController(
      text: widget.event?.basePrice != null
          ? widget.event!.basePrice!.toString()
          : '0',
    );
    dateCtrl = TextEditingController(text: widget.event?.eventDate ?? '');
    timeCtrl = TextEditingController(text: widget.event?.eventTime ?? '');
    locationCtrl = TextEditingController(text: widget.event?.location ?? '');
    cityCtrl = TextEditingController(text: widget.event?.city ?? '');
    addressCtrl = TextEditingController(text: widget.event?.address ?? '');
    address2Ctrl = TextEditingController(text: widget.event?.address2 ?? '');
    deliveryDateEventCtrl = TextEditingController(
      text: widget.event?.deliveryDate ?? '',
    );
    guestCountEventCtrl = TextEditingController(
      text: widget.event?.guestCount?.toString() ?? '',
    );
    pinCtrl = TextEditingController(
      text: widget.event?.accessPin?.isNotEmpty == true
          ? widget.event!.accessPin!
          : '',
    );
    priceCtrl = TextEditingController(
      text: widget.event?.pricePerPhoto.toString() ?? '5',
    );
    notesCtrl = TextEditingController(text: widget.event?.notes ?? '');
    eventType = widget.event?.eventType ?? widget.initialEventType ?? '';
    isLocked = widget.event?.isLocked ?? false;
    final meta = widget.event?.eventMeta ?? {};
    noivoNomeCtrl = TextEditingController(
      text: meta['noivo_nome']?.toString() ?? '',
    );
    noivaNomeCtrl = TextEditingController(
      text: meta['noiva_nome']?.toString() ?? '',
    );
    noivoContactoCtrl = TextEditingController(
      text: meta['noivo_contacto']?.toString() ?? '',
    );
    noivaContactoCtrl = TextEditingController(
      text: meta['noiva_contacto']?.toString() ?? '',
    );
    noivoProfissaoCtrl = TextEditingController(
      text: meta['noivo_profissao']?.toString() ?? '',
    );
    noivaProfissaoCtrl = TextEditingController(
      text: meta['noiva_profissao']?.toString() ?? '',
    );
    noivoMoradaCtrl = TextEditingController(
      text: meta['noivo_morada']?.toString() ?? '',
    );
    noivaMoradaCtrl = TextEditingController(
      text: meta['noiva_morada']?.toString() ?? '',
    );
    noivoInstagramCtrl = TextEditingController(
      text:
          meta['noivo_instagram']?.toString() ??
          meta['instagram_noivos']?.toString() ??
          '',
    );
    noivaInstagramCtrl = TextEditingController(
      text: meta['noiva_instagram']?.toString() ?? '',
    );
    noivoFilhoDe1Ctrl = TextEditingController(
      text: meta['noivo_filho_de_1']?.toString() ?? '',
    );
    noivoFilhoDe2Ctrl = TextEditingController(
      text: meta['noivo_filho_de_2']?.toString() ?? '',
    );
    noivaFilhoDe1Ctrl = TextEditingController(
      text: meta['noiva_filho_de_1']?.toString() ?? '',
    );
    noivaFilhoDe2Ctrl = TextEditingController(
      text: meta['noiva_filho_de_2']?.toString() ?? '',
    );
    noivoCoordenadasCtrl = TextEditingController(
      text: meta['noivo_coordenadas']?.toString() ?? '',
    );
    noivaCoordenadasCtrl = TextEditingController(
      text: meta['noiva_coordenadas']?.toString() ?? '',
    );
    missaHoraCtrl = TextEditingController(
      text: meta['missa_hora']?.toString() ?? '',
    );
    igrejaTipo = _normalizeCerimoniaTipo(meta['igreja_local']?.toString());
    igrejaLocalidadeCtrl = TextEditingController(
      text: _resolveCerimoniaLocal(meta),
    );
    refeicaoTipo = _normalizeRefeicaoTipo(meta['quinta_local']?.toString());
    almocoLocalidadeCtrl = TextEditingController(
      text: _resolveRefeicaoLocal(meta),
    );
    numeroConvidadosCtrl = TextEditingController(
      text: meta['numero_convidados']?.toString() ?? '',
    );
    instagramPaisCtrl = TextEditingController(
      text: meta['instagram_pais']?.toString() ?? '',
    );
    casaNoivoChegadaCtrl = TextEditingController(
      text: meta['casa_noivo_chegada']?.toString() ?? '',
    );
    casaNoivoSaidaCtrl = TextEditingController(
      text: meta['casa_noivo_saida']?.toString() ?? '',
    );
    casaNoivaChegadaCtrl = TextEditingController(
      text: meta['casa_noiva_chegada']?.toString() ?? '',
    );
    casaNoivaSaidaCtrl = TextEditingController(
      text: meta['casa_noiva_saida']?.toString() ?? '',
    );
    dataEntregaCtrl = TextEditingController(
      text: meta['data_entrega']?.toString() ?? '',
    );
    equipaTrabalhoCtrl = TextEditingController(
      text: meta['equipa_de_trabalho']?.toString() ?? '',
    );
    teamCountCtrl = TextEditingController(
      text: meta['servico_num_profissionais']?.toString() ?? '',
    );
    bebeNomeCtrl = TextEditingController(
      text: meta['bebe_nome']?.toString() ?? '',
    );
    paiNomeCtrl = TextEditingController(
      text: meta['pai_nome']?.toString() ?? '',
    );
    maeNomeCtrl = TextEditingController(
      text: meta['mae_nome']?.toString() ?? '',
    );
    padrinhoNomeCtrl = TextEditingController(
      text: meta['padrinho_nome']?.toString() ?? '',
    );
    madrinhaNomeCtrl = TextEditingController(
      text: meta['madrinha_nome']?.toString() ?? '',
    );
    contactoPaisCtrl = TextEditingController(
      text: meta['contacto_pais']?.toString() ?? '',
    );
    batizadoMoradaCtrl = TextEditingController(
      text: meta['morada']?.toString() ?? '',
    );
    servicoTelaCtrl = TextEditingController(
      text: meta['servico_tela']?.toString() ?? '',
    );
    servicoUsbCtrl = TextEditingController(
      text: meta['servico_usb']?.toString() ?? '',
    );
    servicoCondicoesCtrl = TextEditingController(
      text: meta['servico_condicoes_minimas']?.toString() ?? '',
    );
    servicoMusicasCtrl = TextEditingController(
      text: meta['servico_musicas']?.toString() ?? '',
    );
    servicoExtrasCtrl = TextEditingController(
      text: meta['servico_extras']?.toString() ?? '',
    );
    servicoSaveTheDate = _metaFlag(meta, 'servico_save_the_date');
    servicoFotosLoveStory = _metaFlag(meta, 'servico_fotos_love_story');
    servicoVideoLoveStory = _metaFlag(meta, 'servico_video_love_story');
    servicoProjectarLoveStory = _metaFlag(meta, 'servico_projectar_love_story');
    servicoComboBelezaLoveStory = _metaFlag(
      meta,
      'servico_combo_beleza_love_story',
    );
    servicoAlbumDigital305 = _metaFlag(meta, 'servico_album_digital_30_5');
    servicoComboBelezaTtd = _metaFlag(meta, 'servico_combo_beleza_ttd');
    servicoAlbumDigital = _metaFlag(meta, 'servico_album_digital');
    servicoAlbumConvidados = _metaFlag(meta, 'servico_album_convidados');
    servicoAlbuns4020 = _metaFlag(meta, 'servico_albuns_40_20');
    servicoSameDayEdit = _metaFlag(meta, 'servico_same_day_edit');
    servicoProjectarSameDayEdit = _metaFlag(
      meta,
      'servico_projectar_same_day_edit',
    );
    servicoGaleriaDigitalConvidados = _metaFlag(
      meta,
      'servico_galeria_digital_convidados',
    );
    servicoFotoLembrancaQr = _metaFlag(meta, 'servico_foto_lembranca_qr');
    servicoImpressao100 = _metaFlag(meta, 'servico_impressao_100_11x22_7');
    servicoVideoDepoisDoSim = _metaFlag(meta, 'servico_video_depois_do_sim');
    servicoDrone = _metaFlag(meta, 'servico_drone');
    equipaTrabalhoCtrl.addListener(_updateTeamPreview);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTeamUsers());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadServiceTemplates());
    if (widget.event == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadNextReportNumber(),
      );
    }
  }

  bool _metaFlag(Map<String, dynamic> meta, String key) {
    final value = meta[key];
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'sim' || text == 'yes';
  }

  String _normalizeCerimoniaTipo(String? raw) {
    final text = (raw ?? '').trim().toLowerCase();
    if (text.contains('civil')) return 'Civil';
    if (text.contains('igreja')) return 'Igreja';
    return '';
  }

  String _normalizeRefeicaoTipo(String? raw) {
    final text = (raw ?? '').trim().toLowerCase();
    if (text.contains('jantar')) return 'Jantar';
    if (text.contains('almoço') || text.contains('almoco')) return 'Almoço';
    return '';
  }

  bool _isCerimoniaTipo(String raw) => _normalizeCerimoniaTipo(raw).isNotEmpty;

  bool _isRefeicaoTipo(String raw) => _normalizeRefeicaoTipo(raw).isNotEmpty;

  String _resolveCerimoniaLocal(Map<String, dynamic> meta) {
    final legacy = meta['igreja_local']?.toString() ?? '';
    if (legacy.isNotEmpty && !_isCerimoniaTipo(legacy)) return legacy;
    final localidade = meta['igreja_localidade']?.toString() ?? '';
    if (localidade.isNotEmpty) return localidade;
    return '';
  }

  String _resolveRefeicaoLocal(Map<String, dynamic> meta) {
    final legacy = meta['quinta_local']?.toString() ?? '';
    if (legacy.isNotEmpty && !_isRefeicaoTipo(legacy)) return legacy;
    final localidade = meta['almoco_localidade']?.toString() ?? '';
    if (localidade.isNotEmpty) return localidade;
    return '';
  }

  Future<void> _loadTeamUsers() async {
    final token = ref.read(staffTokenProvider);
    if (token == null) return;
    try {
      final users = await ref.read(apiProvider).staffUsers(token);
      if (!mounted) return;
      _teamUsers = users
          .where((u) => (u.username ?? '').trim().isNotEmpty)
          .toList();
      _updateTeamPreview();
    } catch (_) {
      if (!mounted) return;
      _updateTeamPreview();
    }
  }

  Future<void> _loadServiceTemplates() async {
    final token = ref.read(staffTokenProvider);
    if (token == null) return;
    try {
      final templates = await ref.read(apiProvider).staffServiceTemplates(token);
      if (!mounted) return;
      templates.sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) return order;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      _serviceTemplates = templates;
      if (eventType.isEmpty && templates.isNotEmpty) {
        eventType = widget.initialEventType ?? templates.first.slug;
      }
      _primeDynamicControllers();
      _updateTeamPreview();
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() {});
    }
  }

  static const Set<String> _legacyTemplateSlugs = {'casamento', 'batizado'};

  bool get _isLegacyEventType => _legacyTemplateSlugs.contains(eventType);

  StaffServiceTemplate? get _activeTemplate {
    for (final template in _serviceTemplates) {
      if (template.slug == eventType) return template;
    }
    return null;
  }

  void _primeDynamicControllers() {
    final template = _activeTemplate;
    if (template == null) return;
    for (final field in template.fields.where((f) => f.showInForm)) {
      _controllerForTemplateField(field);
    }
  }

  TextEditingController _controllerForTemplateField(StaffServiceTemplateField field) {
    final existing = _knownControllerForKey(field.key);
    if (existing != null) return existing;
    return _dynamicControllers.putIfAbsent(field.key, () {
      final initial = field.source == 'event'
          ? _eventSourceValue(field.key)
          : _metaSourceValue(field.key);
      return TextEditingController(text: initial);
    });
  }

  TextEditingController? _knownControllerForKey(String key) {
    switch (key) {
      case 'noivo_nome':
        return noivoNomeCtrl;
      case 'noiva_nome':
        return noivaNomeCtrl;
      case 'noivo_contacto':
        return noivoContactoCtrl;
      case 'noiva_contacto':
        return noivaContactoCtrl;
      case 'noivo_profissao':
        return noivoProfissaoCtrl;
      case 'noiva_profissao':
        return noivaProfissaoCtrl;
      case 'noivo_morada':
        return noivoMoradaCtrl;
      case 'noiva_morada':
        return noivaMoradaCtrl;
      case 'noivo_instagram':
        return noivoInstagramCtrl;
      case 'noiva_instagram':
        return noivaInstagramCtrl;
      case 'noivo_filho_de_1':
        return noivoFilhoDe1Ctrl;
      case 'noivo_filho_de_2':
        return noivoFilhoDe2Ctrl;
      case 'noiva_filho_de_1':
        return noivaFilhoDe1Ctrl;
      case 'noiva_filho_de_2':
        return noivaFilhoDe2Ctrl;
      case 'noivo_coordenadas':
        return noivoCoordenadasCtrl;
      case 'noiva_coordenadas':
        return noivaCoordenadasCtrl;
      case 'missa_hora':
        return missaHoraCtrl;
      case 'igreja_localidade':
        return igrejaLocalidadeCtrl;
      case 'almoco_localidade':
        return almocoLocalidadeCtrl;
      case 'numero_convidados':
        return numeroConvidadosCtrl;
      case 'instagram_pais':
        return instagramPaisCtrl;
      case 'casa_noivo_chegada':
        return casaNoivoChegadaCtrl;
      case 'casa_noivo_saida':
        return casaNoivoSaidaCtrl;
      case 'casa_noiva_chegada':
        return casaNoivaChegadaCtrl;
      case 'casa_noiva_saida':
        return casaNoivaSaidaCtrl;
      case 'data_entrega':
        return dataEntregaCtrl;
      case 'equipa_de_trabalho':
        return equipaTrabalhoCtrl;
      case 'servico_num_profissionais':
        return teamCountCtrl;
      case 'bebe_nome':
        return bebeNomeCtrl;
      case 'pai_nome':
        return paiNomeCtrl;
      case 'mae_nome':
        return maeNomeCtrl;
      case 'padrinho_nome':
        return padrinhoNomeCtrl;
      case 'madrinha_nome':
        return madrinhaNomeCtrl;
      case 'contacto_pais':
        return contactoPaisCtrl;
      case 'morada':
        return batizadoMoradaCtrl;
      case 'servico_tela':
        return servicoTelaCtrl;
      case 'servico_usb':
        return servicoUsbCtrl;
      case 'servico_condicoes_minimas':
        return servicoCondicoesCtrl;
      case 'servico_musicas':
        return servicoMusicasCtrl;
      case 'servico_extras':
        return servicoExtrasCtrl;
      case 'location':
        return locationCtrl;
      case 'city':
        return cityCtrl;
      case 'address':
        return addressCtrl;
      case 'address2':
        return address2Ctrl;
      case 'delivery_date':
        return deliveryDateEventCtrl;
      case 'guest_count':
        return guestCountEventCtrl;
    }
    return null;
  }

  String _metaSourceValue(String key) {
    final meta = widget.event?.eventMeta ?? {};
    return meta[key]?.toString() ?? '';
  }

  String _eventSourceValue(String key) {
    final event = widget.event;
    switch (key) {
      case 'location':
        return event?.location ?? '';
      case 'city':
        return event?.city ?? '';
      case 'address':
        return event?.address ?? '';
      case 'address2':
        return event?.address2 ?? '';
      case 'delivery_date':
        return event?.deliveryDate ?? '';
      case 'guest_count':
        return event?.guestCount?.toString() ?? '';
    }
    return '';
  }

  void _updateTeamPreview() {
    final raw = equipaTrabalhoCtrl.text;
    final result = _resolveTeamUsers(raw);
    _matchedTeamUsers = result.matched;
    _unknownTeamTokens = result.unknown;
    _teamCount = _matchedTeamUsers.length + _unknownTeamTokens.length;
    teamCountCtrl.text = _teamCount == 0 ? '' : _teamCount.toString();
    if (mounted) {
      setState(() {});
    }
  }

  _TeamResolveResult _resolveTeamUsers(String raw) {
    final tokens = _splitTeamTokens(
      raw,
    ).map(_normalizeToken).where((t) => t.isNotEmpty).toList();
    final matched = <int, StaffUser>{};
    final unknown = <String>[];
    final userMap = <String, List<StaffUser>>{};
    for (final user in _teamUsers) {
      final username = (user.username ?? '').trim().toLowerCase();
      if (username.isNotEmpty) {
        userMap.putIfAbsent(username, () => []).add(user);
      }
      final initials = _initialsFromName(user.name);
      if (initials.isNotEmpty) {
        userMap.putIfAbsent(initials, () => []).add(user);
      }
    }
    final rawNormalized = _normalizeRaw(raw);
    final matchedByRaw = <String>{};
    for (final entry in userMap.entries) {
      final username = entry.key;
      final pattern = RegExp(
        '(^|[^a-z0-9])${RegExp.escape(username)}([^a-z0-9]|'
        r'$)',
      );
      if (pattern.hasMatch(rawNormalized)) {
        for (final user in entry.value) {
          matched[user.id] = user;
        }
        matchedByRaw.add(username);
      }
    }
    for (final user in _teamUsers) {
      final nameToken = _normalizeRaw(user.name ?? '');
      if (nameToken.trim().isNotEmpty && rawNormalized.contains(nameToken)) {
        matched[user.id] = user;
      }
    }

    for (final token in tokens) {
      if (userMap.containsKey(token)) {
        for (final user in userMap[token]!) {
          matched[user.id] = user;
        }
        continue;
      }
      if (token.length > 2) {
        final prefix = token.substring(0, 2);
        if (userMap.containsKey(prefix)) {
          for (final user in userMap[prefix]!) {
            matched[user.id] = user;
          }
          continue;
        }
      }
      if (!matchedByRaw.contains(token)) {
        unknown.add(token);
      }
    }
    return _TeamResolveResult(
      matched: matched.values.toList(),
      unknown: unknown.toSet().toList(),
    );
  }

  Future<void> _loadNextReportNumber() async {
    if (widget.event != null) return;
    final token = ref.read(staffTokenProvider);
    if (token == null) return;
    if (reportNumberCtrl.text.trim().isNotEmpty) return;
    try {
      final next = await ref.read(apiProvider).staffNextReportNumber(token);
      if (!mounted) return;
      if (next != null && reportNumberCtrl.text.trim().isEmpty) {
        reportNumberCtrl.text = next;
      }
    } catch (_) {
      if (!mounted) return;
    }
  }

  @override
  void dispose() {
    equipaTrabalhoCtrl.removeListener(_updateTeamPreview);
    reportNumberCtrl.dispose();
    basePriceCtrl.dispose();
    dateCtrl.dispose();
    timeCtrl.dispose();
    locationCtrl.dispose();
    cityCtrl.dispose();
    addressCtrl.dispose();
    address2Ctrl.dispose();
    deliveryDateEventCtrl.dispose();
    guestCountEventCtrl.dispose();
    pinCtrl.dispose();
    priceCtrl.dispose();
    notesCtrl.dispose();
    noivoNomeCtrl.dispose();
    noivaNomeCtrl.dispose();
    noivoContactoCtrl.dispose();
    noivaContactoCtrl.dispose();
    noivoProfissaoCtrl.dispose();
    noivaProfissaoCtrl.dispose();
    noivoMoradaCtrl.dispose();
    noivaMoradaCtrl.dispose();
    noivoInstagramCtrl.dispose();
    noivaInstagramCtrl.dispose();
    noivoFilhoDe1Ctrl.dispose();
    noivoFilhoDe2Ctrl.dispose();
    noivaFilhoDe1Ctrl.dispose();
    noivaFilhoDe2Ctrl.dispose();
    noivoCoordenadasCtrl.dispose();
    noivaCoordenadasCtrl.dispose();
    missaHoraCtrl.dispose();
    igrejaLocalidadeCtrl.dispose();
    almocoLocalidadeCtrl.dispose();
    numeroConvidadosCtrl.dispose();
    instagramPaisCtrl.dispose();
    casaNoivoChegadaCtrl.dispose();
    casaNoivoSaidaCtrl.dispose();
    casaNoivaChegadaCtrl.dispose();
    casaNoivaSaidaCtrl.dispose();
    dataEntregaCtrl.dispose();
    equipaTrabalhoCtrl.dispose();
    teamCountCtrl.dispose();
    bebeNomeCtrl.dispose();
    paiNomeCtrl.dispose();
    maeNomeCtrl.dispose();
    padrinhoNomeCtrl.dispose();
    madrinhaNomeCtrl.dispose();
    contactoPaisCtrl.dispose();
    batizadoMoradaCtrl.dispose();
    servicoTelaCtrl.dispose();
    servicoUsbCtrl.dispose();
    servicoCondicoesCtrl.dispose();
    servicoMusicasCtrl.dispose();
    servicoExtrasCtrl.dispose();
    for (final controller in _dynamicControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime initialDate = DateTime.now();
    final existing = DateTime.tryParse(dateCtrl.text.trim());
    if (existing != null) {
      initialDate = existing;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    dateCtrl.text = '$y-$m-$d';
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    TimeOfDay initial = now;
    if (timeCtrl.text.trim().isNotEmpty) {
      final parts = timeCtrl.text.trim().split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          initial = TimeOfDay(hour: h, minute: m);
        }
      }
    }
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    timeCtrl.text = '$hh:$mm';
  }

  Future<void> _pickDateInto(TextEditingController ctrl) async {
    DateTime initialDate = DateTime.now();
    final existing = DateTime.tryParse(ctrl.text.trim());
    if (existing != null) {
      initialDate = existing;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    ctrl.text = '$y-$m-$d';
  }

  Future<void> _pickTimeInto(TextEditingController ctrl) async {
    final now = TimeOfDay.now();
    TimeOfDay initial = now;
    if (ctrl.text.trim().isNotEmpty) {
      final parts = ctrl.text.trim().split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          initial = TimeOfDay(hour: h, minute: m);
        }
      }
    }
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    ctrl.text = '$hh:$mm';
  }

  bool _isTodayOrPast(String dateValue) {
    final parsed = DateTime.tryParse(dateValue);
    if (parsed == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    return !day.isAfter(today);
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    if (token == null)
      return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    final user = ref.watch(staffUserProvider);

    final formBody = LayoutBuilder(
      builder: (context, constraints) {
        final maxContentWidth = constraints.maxWidth > 1200
            ? 1200.0
            : constraints.maxWidth;
        final isWide = maxContentWidth >= 900;
        const spacing = 16.0;

        Widget wrapFields(List<Widget> fields, {int columns = 2}) {
          final cols = isWide ? columns : 1;
          final width = (maxContentWidth - spacing * (cols - 1)) / cols;
          return Wrap(
            spacing: spacing,
            runSpacing: 12,
            children: fields
                .map((f) => SizedBox(width: width, child: f))
                .toList(),
          );
        }

        Widget sectionCard(String title, Widget child) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kBrandBlack,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBrandRose),
              boxShadow: [
                BoxShadow(
                  color: kBrandRose.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                child,
              ],
            ),
          );
        }

        Widget subCard(String title, Widget child) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kBrandBlack.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBrandRose.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                child,
              ],
            ),
          );
        }

        Widget stackFields(List<Widget> fields) {
          return Column(
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                fields[i],
                if (i < fields.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }

        Widget serviceCheck(
          String label,
          bool value,
          ValueChanged<bool> onChanged,
        ) {
          return CheckboxListTile(
            value: value,
            onChanged: (v) => setState(() => onChanged(v ?? false)),
            title: Text(label),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          );
        }

        final activeTemplate = _activeTemplate;
        final groupedTemplateFields = <String, List<StaffServiceTemplateField>>{};
        if (!_isLegacyEventType && activeTemplate != null) {
          final fields = activeTemplate.fields
              .where((field) => field.showInForm)
              .toList()
            ..sort((a, b) {
              final sectionCompare = a.sectionOrder.compareTo(b.sectionOrder);
              if (sectionCompare != 0) return sectionCompare;
              return a.order.compareTo(b.order);
            });
          for (final field in fields) {
            final key = '${field.sectionOrder}|${field.section}';
            groupedTemplateFields.putIfAbsent(key, () => []).add(field);
          }
        }

        double fieldWidthFor(String width) {
          if (!isWide) return maxContentWidth;
          switch (width) {
            case 'full':
              return maxContentWidth;
            case 'third':
              return (maxContentWidth - spacing * 2) / 3;
            default:
              return (maxContentWidth - spacing) / 2;
          }
        }

        final teamPreview =
            _matchedTeamUsers.isEmpty && _unknownTeamTokens.isEmpty
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _matchedTeamUsers
                        .map(
                          (u) => Chip(
                            label: Text((u.username ?? '').toUpperCase()),
                          ),
                        )
                        .toList(),
                  ),
                  if (_unknownTeamTokens.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Sem correspondência: ${_unknownTeamTokens.join(', ')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                ],
              );

        Widget buildTemplateField(StaffServiceTemplateField field) {
          final controller = _controllerForTemplateField(field);
          final width = fieldWidthFor(field.width);
          final label = field.label;
          final isTeamField = field.key == 'equipa_de_trabalho';
          final isTeamCountField = field.key == 'servico_num_profissionais';

          Widget child;
          switch (field.type) {
            case 'textarea':
              child = TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: field.placeholder,
                  border: const OutlineInputBorder(),
                ),
              );
              break;
            case 'select':
              child = DropdownButtonFormField<String>(
                value: controller.text.trim().isEmpty ? null : controller.text.trim(),
                decoration: InputDecoration(
                  labelText: label,
                  border: const OutlineInputBorder(),
                ),
                items: field.options
                    .map((option) => DropdownMenuItem(
                          value: option,
                          child: Text(option),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => controller.text = value ?? '');
                },
              );
              break;
            case 'checkbox':
              child = CheckboxListTile(
                value: controller.text == '1' || controller.text.toLowerCase() == 'true',
                onChanged: (value) {
                  setState(() => controller.text = value == true ? '1' : '');
                },
                title: Text(label),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              );
              break;
            case 'date':
              child = TextField(
                controller: controller,
                readOnly: true,
                onTap: () => _pickDateInto(controller),
                decoration: InputDecoration(
                  labelText: label,
                  hintText: field.placeholder,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
              );
              break;
            case 'time':
              child = TextField(
                controller: controller,
                readOnly: true,
                onTap: () => _pickTimeInto(controller),
                decoration: InputDecoration(
                  labelText: label,
                  hintText: field.placeholder,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.access_time),
                ),
              );
              break;
            default:
              child = TextField(
                controller: controller,
                readOnly: isTeamCountField,
                keyboardType: field.type == 'number'
                    ? const TextInputType.numberWithOptions(decimal: false)
                    : (field.type == 'email'
                        ? TextInputType.emailAddress
                        : TextInputType.text),
                decoration: InputDecoration(
                  labelText: label,
                  hintText: field.placeholder,
                  border: const OutlineInputBorder(),
                ),
              );
          }

          if (isTeamField) {
            return SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  child,
                  if (_matchedTeamUsers.isNotEmpty ||
                      _unknownTeamTokens.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    teamPreview,
                  ],
                ],
              ),
            );
          }

          return SizedBox(width: width, child: child);
        }

        List<Widget> buildTemplateSections() {
          return groupedTemplateFields.entries.map((entry) {
            final fields = entry.value;
            final title = fields.first.section;
            return sectionCard(
              title,
              Wrap(
                spacing: spacing,
                runSpacing: 12,
                children: fields.map(buildTemplateField).toList(),
              ),
            );
          }).toList();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionCard(
                    'Dados base',
                    wrapFields([
                      DropdownButtonFormField<String>(
                        value: eventType.isEmpty ? null : eventType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo Evento',
                          border: OutlineInputBorder(),
                        ),
                        items: (_serviceTemplates.isNotEmpty
                                ? _serviceTemplates
                                : [
                                    StaffServiceTemplate(
                                      id: 0,
                                      slug: 'casamento',
                                      name: 'Casamento',
                                      fields: const [],
                                    ),
                                    StaffServiceTemplate(
                                      id: 0,
                                      slug: 'batizado',
                                      name: 'Batizado',
                                      fields: const [],
                                    ),
                                  ])
                            .map(
                              (template) => DropdownMenuItem(
                                value: template.slug,
                                child: Text(template.name.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          eventType = v ?? '';
                          _primeDynamicControllers();
                          _updateTeamPreview();
                        }),
                      ),
                      TextField(
                        controller: dateCtrl,
                        readOnly: true,
                        onTap: _pickDate,
                        decoration: const InputDecoration(
                          labelText: 'Data',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                      ),
                      TextField(
                        controller: reportNumberCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Nº reportagem',
                          hintText: 'Gerado automaticamente',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      TextField(
                        controller: timeCtrl,
                        readOnly: true,
                        onTap: _pickTime,
                        decoration: const InputDecoration(
                          labelText: 'Hora',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.access_time),
                        ),
                      ),
                      TextField(
                        controller: basePriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Preço base',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Preço por foto',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      TextField(
                        controller: pinCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Código do evento (PIN)',
                          border: OutlineInputBorder(),
                          hintText: 'Gerado automaticamente ao guardar',
                        ),
                      ),
                    ], columns: 3),
                  ),
                  if (_isLegacyEventType) ...[
                    sectionCard(
                      'Missa e locais',
                      wrapFields([
                        TextField(
                          controller: missaHoraCtrl,
                          readOnly: true,
                          onTap: () => _pickTimeInto(missaHoraCtrl),
                          decoration: const InputDecoration(
                            labelText: 'Hora da missa',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          value: igrejaTipo.isEmpty ? null : igrejaTipo,
                          decoration: const InputDecoration(
                            labelText: 'Cerimónia',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Igreja',
                              child: Text('Igreja'),
                            ),
                            DropdownMenuItem(
                              value: 'Civil',
                              child: Text('Civil'),
                            ),
                          ],
                          onChanged: (v) => setState(() => igrejaTipo = v ?? ''),
                        ),
                        TextField(
                          controller: igrejaLocalidadeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome da igreja/local',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          value: refeicaoTipo.isEmpty ? null : refeicaoTipo,
                          decoration: const InputDecoration(
                            labelText: 'Refeição',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Almoço',
                              child: Text('Almoço'),
                            ),
                            DropdownMenuItem(
                              value: 'Jantar',
                              child: Text('Jantar'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => refeicaoTipo = v ?? ''),
                        ),
                        TextField(
                          controller: almocoLocalidadeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome da quinta/restaurante',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ], columns: 3),
                    ),
                    sectionCard(
                      'Entrega e equipa',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          wrapFields([
                            TextField(
                              controller: numeroConvidadosCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Número de convidados',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            TextField(
                              controller: dataEntregaCtrl,
                              readOnly: true,
                              onTap: () => _pickDateInto(dataEntregaCtrl),
                              decoration: const InputDecoration(
                                labelText: 'Data de entrega',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                            ),
                            TextField(
                              controller: equipaTrabalhoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Equipa de trabalho',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            TextField(
                              controller: teamCountCtrl,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Nº de profissionais',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ], columns: 2),
                          if (_matchedTeamUsers.isNotEmpty ||
                              _unknownTeamTokens.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            teamPreview,
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (_isLegacyEventType && eventType == 'casamento') ...[
                    sectionCard(
                      'Dados do casamento',
                      isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: subCard(
                                    'Noivo',
                                    stackFields([
                                      TextField(
                                        controller: noivoNomeCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Nome do noivo',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: noivoInstagramCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Instagram',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: noivoContactoCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Telemóvel',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: noivoProfissaoCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Profissão',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: noivoFilhoDe1Ctrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Filho de (pai)',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: noivoFilhoDe2Ctrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Filho de (mãe)',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: noivoMoradaCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Morada',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: noivoCoordenadasCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Coordenadas',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: casaNoivoChegadaCtrl,
                                        readOnly: true,
                                        onTap: () =>
                                            _pickTimeInto(casaNoivoChegadaCtrl),
                                        decoration: const InputDecoration(
                                          labelText: 'Casa: chegada',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: casaNoivoSaidaCtrl,
                                        readOnly: true,
                                        onTap: () =>
                                            _pickTimeInto(casaNoivoSaidaCtrl),
                                        decoration: const InputDecoration(
                                          labelText: 'Casa: saída',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ]),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: subCard(
                                    'Noiva',
                                    stackFields([
                                      TextField(
                                        controller: noivaNomeCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Nome da noiva',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: noivaInstagramCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Instagram',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: noivaContactoCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Telemóvel',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: noivaProfissaoCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Profissão',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: noivaFilhoDe1Ctrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Filha de (pai)',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: noivaFilhoDe2Ctrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Filha de (mãe)',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: noivaMoradaCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Morada',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: noivaCoordenadasCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Coordenadas',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: casaNoivaChegadaCtrl,
                                        readOnly: true,
                                        onTap: () =>
                                            _pickTimeInto(casaNoivaChegadaCtrl),
                                        decoration: const InputDecoration(
                                          labelText: 'Casa: chegada',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: casaNoivaSaidaCtrl,
                                        readOnly: true,
                                        onTap: () =>
                                            _pickTimeInto(casaNoivaSaidaCtrl),
                                        decoration: const InputDecoration(
                                          labelText: 'Casa: saída',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ]),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                subCard(
                                  'Noivo',
                                  stackFields([
                                    TextField(
                                      controller: noivoNomeCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Nome do noivo',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: noivoInstagramCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Instagram',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: noivoContactoCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Telemóvel',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: noivoProfissaoCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Profissão',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: noivoFilhoDe1Ctrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Filho de (pai)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: noivoFilhoDe2Ctrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Filho de (mãe)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: noivoMoradaCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Morada',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: noivoCoordenadasCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Coordenadas',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: casaNoivoChegadaCtrl,
                                      readOnly: true,
                                      onTap: () =>
                                          _pickTimeInto(casaNoivoChegadaCtrl),
                                      decoration: const InputDecoration(
                                        labelText: 'Casa: chegada',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: casaNoivoSaidaCtrl,
                                      readOnly: true,
                                      onTap: () =>
                                          _pickTimeInto(casaNoivoSaidaCtrl),
                                      decoration: const InputDecoration(
                                        labelText: 'Casa: saída',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ]),
                                ),
                                const SizedBox(height: 12),
                                subCard(
                                  'Noiva',
                                  stackFields([
                                    TextField(
                                      controller: noivaNomeCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Nome da noiva',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: noivaInstagramCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Instagram',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: noivaContactoCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Telemóvel',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: noivaProfissaoCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Profissão',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: noivaFilhoDe1Ctrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Filha de (pai)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: noivaFilhoDe2Ctrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Filha de (mãe)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: noivaMoradaCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Morada',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: noivaCoordenadasCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Coordenadas',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: casaNoivaChegadaCtrl,
                                      readOnly: true,
                                      onTap: () =>
                                          _pickTimeInto(casaNoivaChegadaCtrl),
                                      decoration: const InputDecoration(
                                        labelText: 'Casa: chegada',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    TextField(
                                      controller: casaNoivaSaidaCtrl,
                                      readOnly: true,
                                      onTap: () =>
                                          _pickTimeInto(casaNoivaSaidaCtrl),
                                      decoration: const InputDecoration(
                                        labelText: 'Casa: saída',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ]),
                                ),
                              ],
                            ),
                    ),
                  ],
                  if (_isLegacyEventType && eventType == 'batizado') ...[
                    sectionCard(
                      'Dados do batizado',
                      wrapFields([
                        TextField(
                          controller: bebeNomeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome do bebé',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        TextField(
                          controller: paiNomeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome do pai',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        TextField(
                          controller: maeNomeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome da mãe',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        TextField(
                          controller: padrinhoNomeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome do padrinho',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        TextField(
                          controller: madrinhaNomeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome da madrinha',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        TextField(
                          controller: contactoPaisCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Contacto dos pais',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        TextField(
                          controller: batizadoMoradaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Morada',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        TextField(
                          controller: instagramPaisCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Instagram dos pais',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ], columns: 2),
                    ),
                  ],
                  if (_isLegacyEventType)
                    sectionCard(
                      'Serviços',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          wrapFields([
                            serviceCheck(
                              'Save the Date',
                              servicoSaveTheDate,
                              (v) => servicoSaveTheDate = v,
                            ),
                            serviceCheck(
                              'Fotos Love Story',
                              servicoFotosLoveStory,
                              (v) => servicoFotosLoveStory = v,
                            ),
                            serviceCheck(
                              'Vídeo Love Story',
                              servicoVideoLoveStory,
                              (v) => servicoVideoLoveStory = v,
                            ),
                            serviceCheck(
                              'Projectar Love Story',
                              servicoProjectarLoveStory,
                              (v) => servicoProjectarLoveStory = v,
                            ),
                            serviceCheck(
                              'Combo beleza Love Story',
                              servicoComboBelezaLoveStory,
                              (v) => servicoComboBelezaLoveStory = v,
                            ),
                            serviceCheck(
                              'Álbum digital 30x5',
                              servicoAlbumDigital305,
                              (v) => servicoAlbumDigital305 = v,
                            ),
                            serviceCheck(
                              'Combo beleza TTD',
                              servicoComboBelezaTtd,
                              (v) => servicoComboBelezaTtd = v,
                            ),
                            serviceCheck(
                              'Álbum digital',
                              servicoAlbumDigital,
                              (v) => servicoAlbumDigital = v,
                            ),
                            serviceCheck(
                              'Álbum convidados',
                              servicoAlbumConvidados,
                              (v) => servicoAlbumConvidados = v,
                            ),
                            serviceCheck(
                              'Álbuns 40x20',
                              servicoAlbuns4020,
                              (v) => servicoAlbuns4020 = v,
                            ),
                            serviceCheck(
                              'Same Day Edit',
                              servicoSameDayEdit,
                              (v) => servicoSameDayEdit = v,
                            ),
                            serviceCheck(
                              'Projectar Same Day Edit',
                              servicoProjectarSameDayEdit,
                              (v) => servicoProjectarSameDayEdit = v,
                            ),
                            serviceCheck(
                              'Galeria digital convidados',
                              servicoGaleriaDigitalConvidados,
                              (v) => servicoGaleriaDigitalConvidados = v,
                            ),
                            serviceCheck(
                              'Foto lembrança QR',
                              servicoFotoLembrancaQr,
                              (v) => servicoFotoLembrancaQr = v,
                            ),
                            serviceCheck(
                              'Impressão 100 11x22,7',
                              servicoImpressao100,
                              (v) => servicoImpressao100 = v,
                            ),
                            serviceCheck(
                              'Vídeo depois do sim',
                              servicoVideoDepoisDoSim,
                              (v) => servicoVideoDepoisDoSim = v,
                            ),
                            serviceCheck(
                              'Drone',
                              servicoDrone,
                              (v) => servicoDrone = v,
                            ),
                          ], columns: 3),
                          const SizedBox(height: 8),
                          wrapFields([
                            TextField(
                              controller: servicoTelaCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Tela',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            TextField(
                              controller: servicoUsbCtrl,
                              decoration: const InputDecoration(
                                labelText: 'USB',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          wrapFields([
                            TextField(
                              controller: servicoCondicoesCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Condições mínimas',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            TextField(
                              controller: servicoMusicasCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Músicas',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            TextField(
                              controller: servicoExtrasCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Extras',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ], columns: 1),
                        ],
                      ),
                    ),
                  if (!_isLegacyEventType && activeTemplate != null)
                    ...buildTemplateSections(),
                  if (widget.event != null &&
                      _isTodayOrPast(dateCtrl.text)) ...[
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: isLocked,
                      onChanged: (v) => setState(() => isLocked = v),
                      title: const Text('Bloqueado'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final price =
                                num.tryParse(priceCtrl.text.trim()) ?? 0;
                            final basePrice =
                                num.tryParse(basePriceCtrl.text.trim()) ?? 0;
                            final meta = Map<String, dynamic>.from(
                              widget.event?.eventMeta ?? {},
                            );
                            void setMetaValue(String key, String value) {
                              final trimmed = value.trim();
                              if (trimmed.isEmpty) {
                                meta.remove(key);
                              } else {
                                meta[key] = trimmed;
                              }
                            }

                            void setMetaBool(String key, bool value) {
                              if (value) {
                                meta[key] = 1;
                              } else {
                                meta.remove(key);
                              }
                            }

                            const weddingKeys = [
                              'noivo_nome',
                              'noiva_nome',
                              'noivo_contacto',
                              'noiva_contacto',
                              'noivo_profissao',
                              'noiva_profissao',
                              'noivo_instagram',
                              'noiva_instagram',
                              'instagram_noivos',
                              'noivo_filho_de_1',
                              'noivo_filho_de_2',
                              'noiva_filho_de_1',
                              'noiva_filho_de_2',
                              'noivo_morada',
                              'noiva_morada',
                              'noivo_coordenadas',
                              'noiva_coordenadas',
                              'casa_noivo_chegada',
                              'casa_noivo_saida',
                              'casa_noiva_chegada',
                              'casa_noiva_saida',
                            ];
                            const baptKeys = [
                              'bebe_nome',
                              'pai_nome',
                              'mae_nome',
                              'padrinho_nome',
                              'madrinha_nome',
                              'contacto_pais',
                              'morada',
                              'instagram_pais',
                            ];

                            const legacyCommonKeys = [
                              'missa_hora',
                              'igreja_local',
                              'igreja_localidade',
                              'quinta_local',
                              'almoco_localidade',
                              'numero_convidados',
                              'data_entrega',
                              'equipa_de_trabalho',
                              'servico_num_profissionais',
                              'servico_save_the_date',
                              'servico_fotos_love_story',
                              'servico_video_love_story',
                              'servico_projectar_love_story',
                              'servico_combo_beleza_love_story',
                              'servico_album_digital_30_5',
                              'servico_combo_beleza_ttd',
                              'servico_album_digital',
                              'servico_album_convidados',
                              'servico_albuns_40_20',
                              'servico_same_day_edit',
                              'servico_projectar_same_day_edit',
                              'servico_galeria_digital_convidados',
                              'servico_foto_lembranca_qr',
                              'servico_impressao_100_11x22_7',
                              'servico_video_depois_do_sim',
                              'servico_drone',
                              'servico_tela',
                              'servico_usb',
                              'servico_condicoes_minimas',
                              'servico_musicas',
                              'servico_extras',
                            ];

                            if (_isLegacyEventType) {
                              setMetaValue('missa_hora', missaHoraCtrl.text);
                              setMetaValue('igreja_local', igrejaTipo);
                              setMetaValue(
                                'igreja_localidade',
                                igrejaLocalidadeCtrl.text,
                              );
                              setMetaValue('quinta_local', refeicaoTipo);
                              setMetaValue(
                                'almoco_localidade',
                                almocoLocalidadeCtrl.text,
                              );
                              setMetaValue(
                                'numero_convidados',
                                numeroConvidadosCtrl.text,
                              );
                              setMetaValue(
                                'data_entrega',
                                dataEntregaCtrl.text,
                              );
                              setMetaValue(
                                'equipa_de_trabalho',
                                equipaTrabalhoCtrl.text,
                              );
                              setMetaValue(
                                'servico_num_profissionais',
                                _teamCount == 0 ? '' : _teamCount.toString(),
                              );
                              setMetaBool(
                                'servico_save_the_date',
                                servicoSaveTheDate,
                              );
                              setMetaBool(
                                'servico_fotos_love_story',
                                servicoFotosLoveStory,
                              );
                              setMetaBool(
                                'servico_video_love_story',
                                servicoVideoLoveStory,
                              );
                              setMetaBool(
                                'servico_projectar_love_story',
                                servicoProjectarLoveStory,
                              );
                              setMetaBool(
                                'servico_combo_beleza_love_story',
                                servicoComboBelezaLoveStory,
                              );
                              setMetaBool(
                                'servico_album_digital_30_5',
                                servicoAlbumDigital305,
                              );
                              setMetaBool(
                                'servico_combo_beleza_ttd',
                                servicoComboBelezaTtd,
                              );
                              setMetaBool(
                                'servico_album_digital',
                                servicoAlbumDigital,
                              );
                              setMetaBool(
                                'servico_album_convidados',
                                servicoAlbumConvidados,
                              );
                              setMetaBool(
                                'servico_albuns_40_20',
                                servicoAlbuns4020,
                              );
                              setMetaBool(
                                'servico_same_day_edit',
                                servicoSameDayEdit,
                              );
                              setMetaBool(
                                'servico_projectar_same_day_edit',
                                servicoProjectarSameDayEdit,
                              );
                              setMetaBool(
                                'servico_galeria_digital_convidados',
                                servicoGaleriaDigitalConvidados,
                              );
                              setMetaBool(
                                'servico_foto_lembranca_qr',
                                servicoFotoLembrancaQr,
                              );
                              setMetaBool(
                                'servico_impressao_100_11x22_7',
                                servicoImpressao100,
                              );
                              setMetaBool(
                                'servico_video_depois_do_sim',
                                servicoVideoDepoisDoSim,
                              );
                              setMetaBool('servico_drone', servicoDrone);
                              setMetaValue(
                                'servico_tela',
                                servicoTelaCtrl.text,
                              );
                              setMetaValue('servico_usb', servicoUsbCtrl.text);
                              setMetaValue(
                                'servico_condicoes_minimas',
                                servicoCondicoesCtrl.text,
                              );
                              setMetaValue(
                                'servico_musicas',
                                servicoMusicasCtrl.text,
                              );
                              setMetaValue(
                                'servico_extras',
                                servicoExtrasCtrl.text,
                              );
                            }
                            if (eventType == 'casamento') {
                              for (final key in baptKeys) {
                                meta.remove(key);
                              }
                              setMetaValue('noivo_nome', noivoNomeCtrl.text);
                              setMetaValue('noiva_nome', noivaNomeCtrl.text);
                              setMetaValue(
                                'noivo_instagram',
                                noivoInstagramCtrl.text,
                              );
                              setMetaValue(
                                'noiva_instagram',
                                noivaInstagramCtrl.text,
                              );
                              setMetaValue(
                                'noivo_contacto',
                                noivoContactoCtrl.text,
                              );
                              setMetaValue(
                                'noiva_contacto',
                                noivaContactoCtrl.text,
                              );
                              setMetaValue(
                                'noivo_profissao',
                                noivoProfissaoCtrl.text,
                              );
                              setMetaValue(
                                'noiva_profissao',
                                noivaProfissaoCtrl.text,
                              );
                              setMetaValue(
                                'noivo_filho_de_1',
                                noivoFilhoDe1Ctrl.text,
                              );
                              setMetaValue(
                                'noivo_filho_de_2',
                                noivoFilhoDe2Ctrl.text,
                              );
                              setMetaValue(
                                'noiva_filho_de_1',
                                noivaFilhoDe1Ctrl.text,
                              );
                              setMetaValue(
                                'noiva_filho_de_2',
                                noivaFilhoDe2Ctrl.text,
                              );
                              setMetaValue(
                                'noivo_morada',
                                noivoMoradaCtrl.text,
                              );
                              setMetaValue(
                                'noiva_morada',
                                noivaMoradaCtrl.text,
                              );
                              setMetaValue(
                                'noivo_coordenadas',
                                noivoCoordenadasCtrl.text,
                              );
                              setMetaValue(
                                'noiva_coordenadas',
                                noivaCoordenadasCtrl.text,
                              );
                              setMetaValue(
                                'casa_noivo_chegada',
                                casaNoivoChegadaCtrl.text,
                              );
                              setMetaValue(
                                'casa_noivo_saida',
                                casaNoivoSaidaCtrl.text,
                              );
                              setMetaValue(
                                'casa_noiva_chegada',
                                casaNoivaChegadaCtrl.text,
                              );
                              setMetaValue(
                                'casa_noiva_saida',
                                casaNoivaSaidaCtrl.text,
                              );
                            }
                            if (eventType == 'batizado') {
                              for (final key in weddingKeys) {
                                meta.remove(key);
                              }
                              setMetaValue('bebe_nome', bebeNomeCtrl.text);
                              setMetaValue('pai_nome', paiNomeCtrl.text);
                              setMetaValue('mae_nome', maeNomeCtrl.text);
                              setMetaValue(
                                'padrinho_nome',
                                padrinhoNomeCtrl.text,
                              );
                              setMetaValue(
                                'madrinha_nome',
                                madrinhaNomeCtrl.text,
                              );
                              setMetaValue(
                                'contacto_pais',
                                contactoPaisCtrl.text,
                              );
                              setMetaValue('morada', batizadoMoradaCtrl.text);
                              setMetaValue(
                                'instagram_pais',
                                instagramPaisCtrl.text,
                              );
                            }
                            if (!_isLegacyEventType) {
                              for (final key in [
                                ...legacyCommonKeys,
                                ...weddingKeys,
                                ...baptKeys,
                                'location',
                                'city',
                                'address',
                                'address2',
                                'delivery_date',
                                'guest_count',
                              ]) {
                                meta.remove(key);
                              }
                              if (activeTemplate != null) {
                                for (final field in activeTemplate.fields.where(
                                  (item) => item.showInForm,
                                )) {
                                  final controller =
                                      _controllerForTemplateField(field);
                                  if (field.source == 'event') {
                                    meta.remove(field.key);
                                    continue;
                                  }
                                  if (field.type == 'checkbox') {
                                    setMetaBool(
                                      field.key,
                                      controller.text == '1' ||
                                          controller.text.toLowerCase() ==
                                              'true',
                                    );
                                  } else {
                                    setMetaValue(field.key, controller.text);
                                  }
                                }
                              }
                            }
                            final guestCount = int.tryParse(
                              guestCountEventCtrl.text.trim(),
                            );
                            final payload = StaffEventPayload(
                              name: null,
                              legacyReportNumber: reportNumberCtrl.text.trim(),
                              eventDate: dateCtrl.text.trim(),
                              eventTime: timeCtrl.text.trim(),
                              pricePerPhoto: price,
                              basePrice: basePrice,
                              eventType: eventType,
                              location: locationCtrl.text.trim().isEmpty
                                  ? null
                                  : locationCtrl.text.trim(),
                              city: cityCtrl.text.trim().isEmpty
                                  ? null
                                  : cityCtrl.text.trim(),
                              address: addressCtrl.text.trim().isEmpty
                                  ? null
                                  : addressCtrl.text.trim(),
                              address2: address2Ctrl.text.trim().isEmpty
                                  ? null
                                  : address2Ctrl.text.trim(),
                              deliveryDate:
                                  deliveryDateEventCtrl.text.trim().isEmpty
                                  ? null
                                  : deliveryDateEventCtrl.text.trim(),
                              guestCount: guestCount,
                              eventMeta: meta,
                              notes: notesCtrl.text.trim(),
                              isLocked: isLocked,
                            );
                            if (payload.eventDate.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Data é obrigatória.'),
                                ),
                              );
                              return;
                            }
                            try {
                              setState(() => saving = true);
                              if (widget.event == null) {
                                await ref
                                    .read(apiProvider)
                                    .createEvent(token, payload);
                              } else {
                                await ref
                                    .read(apiProvider)
                                    .updateEvent(
                                      token,
                                      widget.event!.id,
                                      payload,
                                    );
                              }
                              if (!context.mounted) return;
                              Navigator.pop(context);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro: $e')),
                              );
                            } finally {
                              if (mounted) setState(() => saving = false);
                            }
                          },
                    child: Text(saving ? 'A guardar...' : 'Guardar'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (user != null && useDesktopLayout(context)) {
      return StaffDesktopShell(
        user: user,
        token: token,
        initialId: 'events',
        overrideTitle: widget.event == null ? 'Novo Evento' : 'Editar Evento',
        overrideSubtitle: 'Eventos',
        overrideShowSearch: false,
        overrideContent: (ctx, u, t) => formBody,
      );
    }
    final eventActions = <Widget>[
      if (widget.event != null &&
          user != null &&
          user.hasPermission('events.view'))
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          tooltip: 'Gerar PDF',
          onPressed: () async {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const AlertDialog(
                content: SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            );
            try {
              final bytes = await ref
                  .read(apiProvider)
                  .staffEventPdf(token, widget.event!.id);
              final dir = await getTemporaryDirectory();
              final file = File('${dir.path}/evento-${widget.event!.id}.pdf');
              await file.writeAsBytes(bytes, flush: true);
              if (!context.mounted) return;
              await OpenFilex.open(file.path);
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Erro PDF: $e')));
            } finally {
              if (context.mounted) Navigator.pop(context);
            }
          },
        ),
      if (widget.event != null &&
          user != null &&
          user.hasPermission('events.delete'))
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Apagar evento',
          onPressed: () async {
            final ok = await _confirm(
              context,
              'Apagar evento?',
              'Isto remove fotos e uploads associados.',
            );
            if (!ok || !context.mounted) return;
            try {
              await ref.read(apiProvider).deleteEvent(token, widget.event!.id);
              if (!context.mounted) return;
              Navigator.pop(context);
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Erro: $e')));
            }
          },
        ),
    ];

    return Scaffold(
      appBar: buildNavAppBar(
        context,
        widget.event == null ? 'Novo Evento' : 'Editar Evento',
        actions: eventActions,
      ),
      body: formBody,
    );
  }
}

class _TeamResolveResult {
  const _TeamResolveResult({required this.matched, required this.unknown});
  final List<StaffUser> matched;
  final List<String> unknown;
}

class StaffEventStaffPage extends ConsumerStatefulWidget {
  const StaffEventStaffPage({super.key, required this.event});
  final StaffEvent event;

  @override
  ConsumerState<StaffEventStaffPage> createState() =>
      _StaffEventStaffPageState();
}

class _StaffEventStaffPageState extends ConsumerState<StaffEventStaffPage> {
  int? selectedUserId;
  String role = 'photographer';
  bool sendInvite = true;
  String channel = 'email';
  final messageCtrl = TextEditingController();

  @override
  void dispose() {
    messageCtrl.dispose();
    super.dispose();
  }

  Future<_StaffStaffData> _loadData(String token) async {
    final api = ref.read(apiProvider);
    final staff = await api.staffEventStaff(token, widget.event.id);
    final users = await api.staffAssignableUsers(token, widget.event.id);
    return _StaffStaffData(staff: staff, users: users);
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null)
      return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    if (useDesktopLayout(context) && user != null) {
      return StaffDesktopShell(
        user: user,
        token: token,
        initialId: 'events',
        overrideTitle: 'Equipa do Evento',
        overrideSubtitle: widget.event.name,
        overrideShowSearch: false,
        overrideContent: (ctx, u, t) => _buildStaffBody(ctx, t),
      );
    }

    return Scaffold(
      appBar: buildNavAppBar(context, 'Staff • ${widget.event.name}'),
      body: _buildStaffBody(context, token),
    );
  }

  Widget _buildStaffBody(BuildContext context, String token) {
    return FutureBuilder<_StaffStaffData>(
      future: _loadData(token),
      builder: (context, snap) {
        if (!snap.hasData) {
          if (snap.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [Text('Erro: ${snap.error}')],
            );
          }
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!;
        final users = data.users;
        final staff = data.staff;
        if (selectedUserId == null && users.isNotEmpty) {
          selectedUserId = users.first.id;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Associar staff',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: selectedUserId,
              items: users
                  .map(
                    (u) => DropdownMenuItem(
                      value: u.id,
                      child: Text('${u.name} (${u.role})'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => selectedUserId = v),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Utilizador',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: role,
              items: const [
                DropdownMenuItem(
                  value: 'photographer',
                  child: Text('Fotógrafo'),
                ),
                DropdownMenuItem(value: 'assistant', child: Text('Assistente')),
                DropdownMenuItem(value: 'sales', child: Text('Vendas')),
              ],
              onChanged: (v) => setState(() => role = v ?? 'photographer'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Função',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: sendInvite,
              onChanged: (v) => setState(() => sendInvite = v),
              title: const Text('Enviar convite'),
            ),
            if (sendInvite) ...[
              DropdownButtonFormField<String>(
                value: channel,
                items: const [
                  DropdownMenuItem(value: 'email', child: Text('Email')),
                  DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                ],
                onChanged: (v) => setState(() => channel = v ?? 'email'),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Canal',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: messageCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Mensagem (opcional)',
                ),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: selectedUserId == null
                  ? null
                  : () async {
                      await ref
                          .read(apiProvider)
                          .staffAssignEventStaff(
                            token,
                            widget.event.id,
                            [selectedUserId!],
                            role: role,
                            sendInvite: sendInvite,
                            channel: channel,
                            message: messageCtrl.text.trim(),
                          );
                      if (!mounted) return;
                      setState(() {});
                    },
              child: const Text('Associar'),
            ),
            const Divider(height: 32),
            const Text(
              'Staff associado',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (staff.isEmpty) const Text('Sem staff associado.'),
            ...staff.map((s) {
              return Card(
                child: ListTile(
                  title: Text('${s.user.name} (${s.user.role})'),
                  subtitle: Text('${s.role} • ${s.status}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await ref
                          .read(apiProvider)
                          .staffRemoveEventStaff(
                            token,
                            widget.event.id,
                            s.user.id,
                          );
                      if (!mounted) return;
                      setState(() {});
                    },
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}

class _StaffStaffData {
  const _StaffStaffData({required this.staff, required this.users});
  final List<StaffEventStaff> staff;
  final List<StaffUser> users;
}

class _UploadOutcome {
  const _UploadOutcome({
    required this.fileName,
    required this.duration,
    required this.success,
    this.error,
  });
  final String fileName;
  final Duration duration;
  final bool success;
  final String? error;
}

class StaffUploadsPage extends ConsumerStatefulWidget {
  const StaffUploadsPage({super.key});

  @override
  ConsumerState<StaffUploadsPage> createState() => _StaffUploadsPageState();
}

class _StaffUploadsPageState extends ConsumerState<StaffUploadsPage> {
  int? eventId;
  String status = '';
  bool uploading = false;
  List<_UploadOutcome> uploadResults = [];
  List<StaffPhoto> latestPhotos = [];

  Future<List<StaffEvent>> _loadEvents(
    String token, {
    required bool assignedOnly,
  }) => ref.read(apiProvider).staffEvents(token, assignedOnly: assignedOnly);

  @override
  void initState() {
    super.initState();
    saveStaffLastRoute('uploads', userId: ref.read(staffUserProvider)?.id);
  }

  String _humanDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    if (totalSeconds < 60) return '${totalSeconds}s';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes < 60) return '${minutes}m ${seconds}s';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  Future<void> _refreshLatestPhotos(String token, int eventId) async {
    try {
      final photos = await ref
          .read(apiProvider)
          .staffEventPhotos(token, eventId, '');
      photos.sort((a, b) => b.id.compareTo(a.id));
      if (mounted) {
        setState(() => latestPhotos = photos.take(24).toList());
      }
    } catch (_) {}
  }

  Widget _buildUploadsBody(BuildContext context, String token, StaffUser user) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: FutureBuilder<List<StaffEvent>>(
        future: _loadEvents(token, assignedOnly: !_canSeeAllEvents(user)),
        builder: (_, snap) {
          if (!snap.hasData) {
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Erro: ${snap.error}'),
                  ),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }
          final events = _filterEventsForUser(snap.data!, user);
          if (events.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Sem eventos'),
                ),
              ],
            );
          }
          if (eventId == null || !events.any((e) => e.id == eventId)) {
            eventId = events.first.id;
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: [
              DropdownButtonFormField<int>(
                value: eventId,
                items: events
                    .map(
                      (e) => DropdownMenuItem(value: e.id, child: Text(e.name)),
                    )
                    .toList(),
                onChanged: uploading
                    ? null
                    : (v) async {
                        if (v == null) return;
                        setState(() => eventId = v);
                        await _refreshLatestPhotos(token, v);
                      },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Evento',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: uploading
                    ? null
                    : () async {
                        final picker = ImagePicker();
                        final files = await picker.pickMultiImage(
                          imageQuality: 90,
                        );
                        if (files.isEmpty) return;
                        setState(() {
                          uploading = true;
                          status = 'A enviar ${files.length} ficheiros...';
                          uploadResults = [];
                        });
                        try {
                          final results = <_UploadOutcome>[];
                          for (final file in files) {
                            final outcome = await _uploadFile(
                              token,
                              eventId!,
                              File(file.path),
                            );
                            results.add(outcome);
                            if (mounted)
                              setState(
                                () => uploadResults = List.from(results),
                              );
                          }
                          if (!context.mounted) return;
                          final failed = results
                              .where((r) => !r.success)
                              .toList();
                          if (mounted) {
                            setState(() {
                              status = failed.isEmpty
                                  ? 'Uploads concluídos.'
                                  : 'Uploads concluídos com falhas (${failed.length}).';
                            });
                          }
                          if (failed.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Uploads concluídos.'),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Uploads concluídos com falhas (${failed.length}).',
                                ),
                              ),
                            );
                          }
                          await _refreshLatestPhotos(token, eventId!);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erro upload: $e')),
                          );
                        } finally {
                          if (mounted) setState(() => uploading = false);
                        }
                      },
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Selecionar fotos'),
              ),
              const SizedBox(height: 12),
              Text(status),
              if (uploadResults.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Resultado dos uploads',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...uploadResults.map((r) {
                  final icon = r.success
                      ? Icons.check_circle_outline
                      : Icons.error_outline;
                  final color = r.success ? kBrandRose : Colors.redAccent;
                  final message = r.success
                      ? '${r.fileName} • ${_humanDuration(r.duration)}'
                      : '${r.fileName} • ${_humanDuration(r.duration)} • Falhou';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 8),
                        Expanded(child: Text(message)),
                      ],
                    ),
                  );
                }),
              ],
              if (latestPhotos.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Últimas fotos',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: latestPhotos.map((p) {
                    final preview = p.previewUrl;
                    return Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: kBrandRoseSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kBrandRose),
                        image: preview != null && preview.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(preview),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        color: Colors.black54,
                        child: Text(
                          '#${p.number}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null)
      return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    if (useDesktopLayout(context)) {
      return StaffDesktopShell(
        user: user,
        token: token,
        initialId: 'photos',
        overrideTitle: 'Uploads',
        overrideSubtitle: 'Envio de ficheiros',
        overrideShowSearch: false,
        overrideContent: (ctx, u, t) => _buildUploadsBody(ctx, t, u),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uploads'),
        leading: navLeading(context),
        actions: navActions(
          context,
          extra: [
            IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      body: _buildUploadsBody(context, token, user),
    );
  }

  Future<_UploadOutcome> _uploadFile(
    String token,
    int eventId,
    File file,
  ) async {
    final fileName = file.path.split('/').last;
    final length = await file.length();
    const chunkSize = 1024 * 1024 * 2;
    final totalChunks = (length / chunkSize).ceil();
    final uploadId = _generateUploadId();
    final raf = await file.open();
    final startedAt = DateTime.now();
    try {
      for (var i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final size = min(chunkSize, length - start);
        await raf.setPosition(start);
        final bytes = await raf.read(size);
        await ref
            .read(apiProvider)
            .staffUploadChunk(
              token: token,
              eventId: eventId,
              uploadId: uploadId,
              chunkIndex: i,
              totalChunks: totalChunks,
              fileName: fileName,
              chunkBytes: bytes,
            );
        if (mounted) {
          setState(() => status = 'Upload ${i + 1}/$totalChunks: $fileName');
        }
      }
      return _UploadOutcome(
        fileName: fileName,
        duration: DateTime.now().difference(startedAt),
        success: true,
      );
    } catch (e) {
      return _UploadOutcome(
        fileName: fileName,
        duration: DateTime.now().difference(startedAt),
        success: false,
        error: e.toString(),
      );
    } finally {
      await raf.close();
    }
  }

  String _generateUploadId() {
    final rand = Random();
    return '${DateTime.now().millisecondsSinceEpoch}-${rand.nextInt(1 << 32)}';
  }
}

class _StaffEventGalleryPage extends ConsumerStatefulWidget {
  const _StaffEventGalleryPage({required this.event});
  final StaffEvent event;

  @override
  ConsumerState<_StaffEventGalleryPage> createState() =>
      _StaffEventGalleryPageState();
}

class _StaffEventGalleryPageState
    extends ConsumerState<_StaffEventGalleryPage> {
  bool uploading = false;
  String uploadStatus = '';
  List<_UploadOutcome> uploadResults = [];

  String _generateUploadId() {
    final rand = Random();
    return '${DateTime.now().millisecondsSinceEpoch}-${rand.nextInt(1 << 32)}';
  }

  Future<_UploadOutcome> _uploadFile(String token, File file) async {
    final fileName = file.path.split('/').last;
    final length = await file.length();
    const chunkSize = 1024 * 1024 * 2;
    final totalChunks = (length / chunkSize).ceil();
    final uploadId = _generateUploadId();
    final raf = await file.open();
    final startedAt = DateTime.now();
    try {
      for (var i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final size = min(chunkSize, length - start);
        await raf.setPosition(start);
        final bytes = await raf.read(size);
        await ref
            .read(apiProvider)
            .staffUploadChunk(
              token: token,
              eventId: widget.event.id,
              uploadId: uploadId,
              chunkIndex: i,
              totalChunks: totalChunks,
              fileName: fileName,
              chunkBytes: bytes,
            );
        if (mounted)
          setState(
            () => uploadStatus = 'Upload ${i + 1}/$totalChunks: $fileName',
          );
      }
      return _UploadOutcome(
        fileName: fileName,
        duration: DateTime.now().difference(startedAt),
        success: true,
      );
    } catch (e) {
      return _UploadOutcome(
        fileName: fileName,
        duration: DateTime.now().difference(startedAt),
        success: false,
        error: e.toString(),
      );
    } finally {
      await raf.close();
    }
  }

  Future<void> _pickAndUpload(String token) async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 90);
    if (files.isEmpty) return;
    setState(() {
      uploading = true;
      uploadStatus = 'A enviar ${files.length} ficheiros...';
      uploadResults = [];
    });
    try {
      final results = <_UploadOutcome>[];
      for (final f in files) {
        final outcome = await _uploadFile(token, File(f.path));
        results.add(outcome);
        if (mounted) setState(() => uploadResults = List.from(results));
      }
      if (mounted) {
        final failed = results.where((r) => !r.success).length;
        setState(
          () => uploadStatus = failed == 0
              ? 'Uploads concluídos.'
              : 'Concluído com $failed falhas.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => uploadStatus = 'Erro: $e');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _deletePhoto(String token, StaffPhoto photo) async {
    final ok = await _confirm(
      context,
      'Apagar foto?',
      'Número ${photo.number}',
    );
    if (!ok) return;
    await ref
        .read(apiProvider)
        .staffDeletePhoto(token, widget.event.id, photo.id);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openPhotoDialog(
    String token,
    StaffUser user,
    StaffPhoto photo,
  ) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 960, maxHeight: 760),
          decoration: BoxDecoration(
            color: kDeskCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kBrandRose.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                child: Row(
                  children: [
                    Text(
                      'Foto #${photo.number}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (user.hasPermission('photos.delete'))
                      IconButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await _deletePhoto(token, photo);
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        tooltip: 'Apagar foto',
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child:
                      photo.previewUrl != null && photo.previewUrl!.isNotEmpty
                      ? InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Center(
                            child: Image.network(
                              photo.previewUrl!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.white24,
                            size: 42,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null) return const Scaffold(body: SizedBox());
    return Scaffold(
      appBar: buildNavAppBar(context, widget.event.name),
      floatingActionButton: user.hasPermission('photos.upload')
          ? FloatingActionButton.extended(
              onPressed: uploading ? null : () => _pickAndUpload(token),
              icon: uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.add_a_photo),
              label: Text(uploading ? 'A enviar...' : 'Adicionar fotos'),
              backgroundColor: kBrandRose,
              foregroundColor: kBrandBlack,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: FutureBuilder<List<StaffPhoto>>(
          future: ref
              .read(apiProvider)
              .staffEventPhotos(token, widget.event.id, ''),
          builder: (_, snap) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              children: [
                if (uploadStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      uploadStatus,
                      style: TextStyle(
                        color: kBrandRose,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (uploadResults.isNotEmpty) ...[
                  ...uploadResults.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            r.success
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            size: 16,
                            color: r.success
                                ? Colors.greenAccent
                                : Colors.redAccent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${r.fileName}${r.success ? '' : ' • Falhou'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!snap.hasData) ...[
                  if (snap.hasError)
                    Center(child: Text('Erro: ${snap.error}'))
                  else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ] else if (snap.data!.isEmpty) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 64,
                            color: Colors.white24,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Sem fotos neste evento',
                            style: TextStyle(color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                    itemCount: snap.data!.length,
                    itemBuilder: (_, i) {
                      final p = snap.data![i];
                      return GestureDetector(
                        onTap: () => _openPhotoDialog(token, user, p),
                        onLongPress: user.hasPermission('photos.delete')
                            ? () => _deletePhoto(token, p)
                            : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: kBrandBlack,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: kBrandRose.withOpacity(0.2),
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (p.previewUrl != null &&
                                  p.previewUrl!.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    p.previewUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.white24,
                                    size: 28,
                                  ),
                                ),
                              Positioned(
                                bottom: 2,
                                left: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    '#${p.number}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class StaffPhotosPage extends ConsumerStatefulWidget {
  const StaffPhotosPage({super.key});

  @override
  ConsumerState<StaffPhotosPage> createState() => _StaffPhotosPageState();
}

class _StaffPhotosPageState extends ConsumerState<StaffPhotosPage> {
  Future<List<StaffEvent>> _loadEvents(
    String token, {
    required bool assignedOnly,
  }) => ref.read(apiProvider).staffEvents(token, assignedOnly: assignedOnly);

  @override
  void initState() {
    super.initState();
    saveStaffLastRoute('photos', userId: ref.read(staffUserProvider)?.id);
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null)
      return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    if (useDesktopLayout(context)) {
      return StaffDesktopShell(user: user, token: token, initialId: 'photos');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Galerias / Fotos'),
        leading: navLeading(context),
        actions: navActions(
          context,
          extra: [
            IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: FutureBuilder<List<StaffEvent>>(
          future: _loadEvents(token, assignedOnly: !_canSeeAllEvents(user)),
          builder: (_, snap) {
            if (!snap.hasData) {
              if (snap.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Erro: ${snap.error}'),
                    ),
                  ],
                );
              }
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            final events = _filterEventsForUser(snap.data!, user);
            if (events.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sem eventos'),
                  ),
                ],
              );
            }
            return GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final e = events[index];
                final typeLabel = _eventTypeLabel(e);
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _StaffEventGalleryPage(event: e),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: kBrandBlack,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kBrandRose.withOpacity(0.35)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: kBrandRose.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.photo_library_outlined,
                                size: 36,
                                color: kBrandRose.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          e.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (e.eventDate.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            e.eventDate,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.45),
                            ),
                          ),
                        ],
                        if (typeLabel.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: kBrandRose.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class StaffOrdersPage extends ConsumerStatefulWidget {
  const StaffOrdersPage({super.key});

  @override
  ConsumerState<StaffOrdersPage> createState() => _StaffOrdersPageState();
}

class _StaffOrdersPageState extends ConsumerState<StaffOrdersPage> {
  DateTime? selectedDate;
  int? selectedEventId;
  String status = '';
  final queryCtrl = TextEditingController();
  final selected = <int>{};
  Future<List<StaffEvent>>? _eventsFuture;
  Future<List<OrderListItem>>? _ordersFuture;
  String? _lastToken;
  String? _lastOrdersKey;

  @override
  void initState() {
    super.initState();
    saveStaffLastRoute('orders', userId: ref.read(staffUserProvider)?.id);
  }

  @override
  void dispose() {
    queryCtrl.dispose();
    super.dispose();
  }

  Future<List<StaffEvent>> _loadEvents(
    String token, {
    required bool assignedOnly,
  }) {
    if (_eventsFuture == null || _lastToken != token) {
      _lastToken = token;
      _eventsFuture = ref
          .read(apiProvider)
          .staffEvents(token, assignedOnly: assignedOnly);
    }
    return _eventsFuture!;
  }

  void _refreshEvents() {
    final token = ref.read(staffTokenProvider);
    final user = ref.read(staffUserProvider);
    if (token == null || user == null) return;
    setState(() {
      _lastToken = null;
      selectedEventId = null;
      _eventsFuture = null;
      _ordersFuture = null;
      _lastOrdersKey = null;
    });
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDateLabel(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  Future<List<OrderListItem>> _loadOrdersFiltered(
    String token, {
    int? eventId,
    List<int>? eventIds,
    required String eventDate,
    required String status,
    required String query,
  }) async {
    return ref
        .read(apiProvider)
        .staffOrdersList(
          token,
          eventId: eventId,
          eventIds: eventIds,
          eventDate: eventId == null && (eventIds == null || eventIds.isEmpty)
              ? eventDate
              : '',
          status: status,
          q: query,
        );
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null)
      return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    if (useDesktopLayout(context)) {
      return StaffDesktopShell(user: user, token: token, initialId: 'orders');
    }
    final isPhotographer = _isPhotographerRole(user.role);
    final canUpdate = user.hasPermission('orders.update');
    final canBulk = user.hasPermission('orders.bulk');
    final canDownload =
        user.hasPermission('orders.download') && !isPhotographer;
    final canExport = user.hasPermission('orders.export') && !isPhotographer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos'),
        leading: navLeading(context),
        actions: navActions(
          context,
          extra: [
            IconButton(
              onPressed: _refreshEvents,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshEvents(),
        child: FutureBuilder<List<StaffEvent>>(
          future: _loadEvents(token, assignedOnly: !_canSeeAllEvents(user)),
          builder: (_, snap) {
            if (!snap.hasData) {
              if (snap.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Erro: ${snap.error}'),
                    ),
                  ],
                );
              }
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            final events = _filterEventsForUser(snap.data!, user);
            selectedDate ??= _startOfDay(DateTime.now());
            final resolvedDate = _startOfDay(selectedDate!);
            final resolvedDateKey = _dateKey(resolvedDate);
            final eventsForDate = events
                .where((e) => e.eventDate == resolvedDateKey)
                .toList();
            final hasSelectedEvent = eventsForDate.any(
              (e) => e.id == selectedEventId,
            );
            final effectiveSelectedEventId = hasSelectedEvent
                ? selectedEventId
                : null;
            final selectedEventIds = effectiveSelectedEventId == null
                ? eventsForDate.map((e) => e.id).toList()
                : <int>[effectiveSelectedEventId];
            final eventInfoById = {for (final e in events) e.id: e};
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      FilledButton.tonal(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: resolvedDate,
                            firstDate: DateTime(2020, 1, 1),
                            lastDate: DateTime(2100, 12, 31),
                          );
                          if (picked == null) return;
                          setState(() {
                            selectedDate = picked;
                            selectedEventId = null;
                            selected.clear();
                            _ordersFuture = null;
                            _lastOrdersKey = null;
                          });
                        },
                        child: Text('Data: ${_formatDateLabel(resolvedDate)}'),
                      ),
                      if (eventsForDate.length > 1) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: effectiveSelectedEventId?.toString() ?? '',
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Todos os eventos'),
                            ),
                            ...eventsForDate.map(
                              (event) => DropdownMenuItem(
                                value: event.id.toString(),
                                child: Text(event.name),
                              ),
                            ),
                          ],
                          onChanged: (value) => setState(() {
                            selectedEventId = value == null || value.isEmpty
                                ? null
                                : int.tryParse(value);
                            selected.clear();
                            _ordersFuture = null;
                            _lastOrdersKey = null;
                          }),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Evento',
                          ),
                        ),
                      ] else if (eventsForDate.length == 1) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: kBrandRose.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kBrandRose.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            'Evento: ${eventsForDate.first.name}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: status,
                        items: const [
                          DropdownMenuItem(
                            value: '',
                            child: Text('Todos status'),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('pending'),
                          ),
                          DropdownMenuItem(value: 'paid', child: Text('paid')),
                          DropdownMenuItem(
                            value: 'delivered',
                            child: Text('delivered'),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          status = v ?? '';
                          _ordersFuture = null;
                          _lastOrdersKey = null;
                        }),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Status',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: queryCtrl,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Nome/codigo',
                        ),
                        onSubmitted: (_) => setState(() => selected.clear()),
                      ),
                      if (canExport && selectedEventIds.length == 1) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: FilledButton.tonal(
                            onPressed: () async {
                              final path = await ref
                                  .read(apiProvider)
                                  .staffExportOrdersCsv(
                                    token,
                                    selectedEventIds.first,
                                  );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('CSV guardado em: $path'),
                                ),
                              );
                            },
                            child: const Text('Exportar CSV do evento'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: FilledButton.tonal(
                            onPressed: () async {
                              final path = await ref
                                  .read(apiProvider)
                                  .staffExportOrdersTxt(
                                    token,
                                    selectedEventIds.first,
                                  );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('TXT guardado em: $path'),
                                ),
                              );
                            },
                            child: const Text('Exportar TXT do evento'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: FilledButton.tonal(
                            onPressed: () async {
                              final appConfig = ref.read(
                                appRuntimeConfigProvider,
                              );
                              final path = await ref
                                  .read(apiProvider)
                                  .staffExportSalesPdf(
                                    token,
                                    selectedEventIds.first,
                                    commissionRate: appConfig.commissionRate,
                                  );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'PDF vendas guardado em: $path',
                                  ),
                                ),
                              );
                            },
                            child: const Text('PDF Vendas'),
                          ),
                        ),
                      ],
                      if (selected.isNotEmpty && canBulk)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: isPhotographer
                              ? FilledButton(
                                  onPressed: () async {
                                    final updated = await ref
                                        .read(apiProvider)
                                        .staffBulkOrderStatus(
                                          token,
                                          selected.toList(),
                                          'paid',
                                        );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Atualizados $updated pedidos.',
                                        ),
                                      ),
                                    );
                                    selected.clear();
                                    setState(() {});
                                  },
                                  child: const Text(
                                    'Marcar pagos (selecionados)',
                                  ),
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: 'paid',
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'pending',
                                            child: Text('pending'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'paid',
                                            child: Text('paid'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'delivered',
                                            child: Text('delivered'),
                                          ),
                                        ],
                                        onChanged: (v) async {
                                          if (v == null) return;
                                          final updated = await ref
                                              .read(apiProvider)
                                              .staffBulkOrderStatus(
                                                token,
                                                selected.toList(),
                                                v,
                                              );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Atualizados $updated pedidos.',
                                              ),
                                            ),
                                          );
                                          selected.clear();
                                          setState(() {});
                                        },
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          labelText: 'Bulk status',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<OrderListItem>>(
                    future: () {
                      final key =
                          '$resolvedDateKey|$status|${queryCtrl.text.trim()}|${effectiveSelectedEventId ?? 'all'}|${selectedEventIds.join(',')}';
                      if (_ordersFuture == null || _lastOrdersKey != key) {
                        _lastOrdersKey = key;
                        _ordersFuture =
                            _loadOrdersFiltered(
                              token,
                              eventId: effectiveSelectedEventId,
                              eventIds:
                                  effectiveSelectedEventId == null &&
                                      selectedEventIds.length > 1
                                  ? selectedEventIds
                                  : null,
                              eventDate: resolvedDateKey,
                              status: status,
                              query: queryCtrl.text.trim(),
                            ).timeout(
                              const Duration(seconds: 30),
                              onTimeout: () => throw TimeoutException(
                                'Tempo limite ao carregar pedidos',
                              ),
                            );
                      }
                      return _ordersFuture!;
                    }(),
                    builder: (_, orderSnap) {
                      if (!orderSnap.hasData) {
                        if (orderSnap.hasError) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Erro: ${orderSnap.error}',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: () => setState(() {
                                    _ordersFuture = null;
                                    _lastOrdersKey = null;
                                  }),
                                  child: const Text('Tentar novamente'),
                                ),
                              ],
                            ),
                          );
                        }
                        return const Center(child: CircularProgressIndicator());
                      }
                      final orders = orderSnap.data!;
                      if (orders.isEmpty)
                        return const Center(child: Text('Sem pedidos'));
                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: orders.length,
                        itemBuilder: (_, i) {
                          final o = orders[i];
                          final isSelected = selected.contains(o.id);
                          final info = o.eventId != null
                              ? eventInfoById[o.eventId]
                              : null;
                          final eventName = info?.name ?? o.eventName ?? '';
                          final eventDate = info?.eventDate ?? '';
                          final eventType = info?.eventType ?? '';
                          final statusColor = o.status == 'paid'
                              ? Colors.lightGreenAccent
                              : o.status == 'delivered'
                              ? Colors.lightBlueAccent
                              : Colors.orangeAccent;
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: kDeskCard,
                              borderRadius: BorderRadius.circular(kDeskRadius),
                              border: Border.all(
                                color: isSelected
                                    ? kBrandRose.withOpacity(0.7)
                                    : kBrandRose.withOpacity(0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: kBrandRose.withOpacity(0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  kDeskRadius,
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          StaffOrderDetailPage(orderId: o.id),
                                    ),
                                  );
                                  if (!mounted) return;
                                  setState(() {
                                    _ordersFuture = null;
                                    _lastOrdersKey = null;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              o.orderCode,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          _DeskStatusBadge(
                                            o.status.toUpperCase(),
                                            color: statusColor,
                                          ),
                                          if (canBulk) ...[
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => setState(
                                                () => isSelected
                                                    ? selected.remove(o.id)
                                                    : selected.add(o.id),
                                              ),
                                              child: Icon(
                                                isSelected
                                                    ? Icons.check_circle
                                                    : Icons
                                                          .radio_button_unchecked,
                                                color: kBrandRose,
                                                size: 22,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              o.customerName,
                                              style: const TextStyle(
                                                color: kBrandRose,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          if (o.productType != null)
                                            _ProductTypeBadge(o.productType!),
                                        ],
                                      ),
                                      if (eventName.isNotEmpty ||
                                          eventDate.isNotEmpty ||
                                          eventType.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 4,
                                          children: [
                                            if (eventName.isNotEmpty)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.event,
                                                    size: 12,
                                                    color: kDeskMuted,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    eventName,
                                                    style: const TextStyle(
                                                      color: kDeskMuted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            if (eventDate.isNotEmpty)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.calendar_today,
                                                    size: 12,
                                                    color: kDeskMuted,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    eventDate,
                                                    style: const TextStyle(
                                                      color: kDeskMuted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            if (eventType.isNotEmpty)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.label_outline,
                                                    size: 12,
                                                    color: kDeskMuted,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    eventType,
                                                    style: const TextStyle(
                                                      color: kDeskMuted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ],
                                      if (canUpdate || canDownload) ...[
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            if (canUpdate &&
                                                o.status != 'paid' &&
                                                o.status != 'delivered')
                                              _MobileActionChip(
                                                label: 'Pagar',
                                                color: Colors.lightGreenAccent,
                                                onTap: () async {
                                                  final settlement =
                                                      await promptCashSettlement(
                                                        context,
                                                        totalAmount:
                                                            o.totalAmount ?? 0,
                                                      );
                                                  if (settlement == null) {
                                                    return;
                                                  }
                                                  final emailed = await ref
                                                      .read(apiProvider)
                                                      .markOrderPaid(
                                                        token,
                                                        o.id,
                                                        eventId: o.eventId,
                                                        cashReceivedAmount:
                                                            settlement
                                                                .receivedAmount,
                                                        cashChangeAmount:
                                                            settlement
                                                                .changeAmount,
                                                        cashChangeGiven:
                                                            settlement
                                                                .changeGiven,
                                                        cashDueAmount:
                                                            settlement
                                                                .dueAmount,
                                                        notes: settlement.notes,
                                                      );
                                                  if (!context.mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        settlement.dueAmount > 0
                                                            ? 'Registado. Falta ${formatEuroAmount(settlement.dueAmount)}€.'
                                                            : settlement
                                                                      .changeAmount >
                                                                  0
                                                            ? settlement
                                                                      .changeGiven
                                                                  ? 'Registado. Troco entregue ${formatEuroAmount(settlement.changeAmount)}€.'
                                                                  : 'Registado. TROCO pendente ${formatEuroAmount(settlement.changeAmount)}€.'
                                                            : emailed
                                                            ? 'Marcado pago e link enviado.'
                                                            : 'Marcado pago. Sem email.',
                                                      ),
                                                    ),
                                                  );
                                                  setState(() {
                                                    selected.remove(o.id);
                                                    _ordersFuture = null;
                                                    _lastOrdersKey = null;
                                                  });
                                                },
                                              ),
                                            if (canUpdate &&
                                                o.paymentMethod == 'cash')
                                              _MobileActionChip(
                                                label: 'Editar €',
                                                color: Colors.amberAccent,
                                                onTap: () async {
                                                  final edit =
                                                      await promptCashOrderEdit(
                                                        context,
                                                        totalAmount:
                                                            o.totalAmount ?? 0,
                                                        currentStatus: o.status,
                                                        currentReceived: o
                                                            .cashReceivedAmount,
                                                        currentChangeGiven:
                                                            o.cashChangeGiven,
                                                      );
                                                  if (edit == null ||
                                                      !context.mounted)
                                                    return;
                                                  await ref
                                                      .read(apiProvider)
                                                      .updateOrder(
                                                        token,
                                                        o.id,
                                                        StaffOrderUpdatePayload(
                                                          customerName:
                                                              o.customerName,
                                                          status: edit.status,
                                                          paymentMethod:
                                                              o.paymentMethod,
                                                          notes: edit.notes,
                                                        cashReceivedAmount:
                                                            edit.receivedAmount,
                                                        cashChangeAmount:
                                                            edit.changeAmount,
                                                        cashChangeGiven:
                                                            edit.changeGiven,
                                                        cashDueAmount:
                                                            edit.dueAmount,
                                                      ),
                                                      );
                                                  if (!context.mounted) return;
                                                  setState(() {
                                                    selected.remove(o.id);
                                                    _ordersFuture = null;
                                                    _lastOrdersKey = null;
                                                  });
                                                },
                                              ),
                                            if (canDownload)
                                              _MobileActionChip(
                                                label: 'Enviar link',
                                                color: kBrandRose,
                                                onTap: () async {
                                                  final sent = await ref
                                                      .read(apiProvider)
                                                      .staffSendDownloadLink(
                                                        token,
                                                        o.id,
                                                      );
                                                  if (!context.mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        sent
                                                            ? 'Link enviado.'
                                                            : 'Falha no envio.',
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            if (canDownload)
                                              _MobileActionChip(
                                                label: 'ZIP',
                                                color: kDeskMuted,
                                                onTap: () async {
                                                  final path = await ref
                                                      .read(apiProvider)
                                                      .staffDownloadAll(
                                                        token,
                                                        o.id,
                                                      );
                                                  if (!context.mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'ZIP guardado: $path',
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class StaffOrderDetailPage extends ConsumerStatefulWidget {
  const StaffOrderDetailPage({super.key, required this.orderId});
  final int orderId;

  @override
  ConsumerState<StaffOrderDetailPage> createState() =>
      _StaffOrderDetailPageState();
}

class _StaffOrderDetailPageState extends ConsumerState<StaffOrderDetailPage> {
  Future<StaffOrderDetail>? _future;
  bool editing = false;
  bool saving = false;
  bool _initialized = false;
  bool cashChangeGiven = true;
  late final TextEditingController nameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController paymentCtrl;
  late final TextEditingController notesCtrl;
  late final TextEditingController cashReceivedCtrl;
  String status = 'pending';
  num _orderTotal = 0;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController();
    emailCtrl = TextEditingController();
    phoneCtrl = TextEditingController();
    paymentCtrl = TextEditingController();
    notesCtrl = TextEditingController();
    cashReceivedCtrl = TextEditingController();
    final token = ref.read(staffTokenProvider);
    if (token != null) {
      _future = ref.read(apiProvider).staffOrderDetail(token, widget.orderId);
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    paymentCtrl.dispose();
    notesCtrl.dispose();
    cashReceivedCtrl.dispose();
    super.dispose();
  }

  void _loadDetail(String token) {
    _initialized = false;
    _future = ref.read(apiProvider).staffOrderDetail(token, widget.orderId);
  }

  Future<void> _save(String token) async {
    final isCash = paymentCtrl.text.trim() == 'cash';
    final rawReceived = cashReceivedCtrl.text.trim().replaceAll(',', '.');
    final received = isCash && rawReceived.isNotEmpty
        ? num.tryParse(rawReceived)
        : null;
    final change = (received != null && received > _orderTotal)
        ? received - _orderTotal
        : (received != null ? 0 : null);
    final due = (received != null && received < _orderTotal)
        ? _orderTotal - received
        : (received != null ? 0 : null);
    final payload = StaffOrderUpdatePayload(
      customerName: nameCtrl.text.trim(),
      customerEmail: emailCtrl.text.trim().isEmpty
          ? null
          : emailCtrl.text.trim(),
      customerPhone: phoneCtrl.text.trim().isEmpty
          ? null
          : phoneCtrl.text.trim(),
      paymentMethod: paymentCtrl.text.trim().isEmpty
          ? null
          : paymentCtrl.text.trim(),
      status: status,
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      cashReceivedAmount: received,
      cashChangeAmount: change,
      cashChangeGiven: (change ?? 0) > 0 ? cashChangeGiven : true,
      cashDueAmount: due,
    );
    if (payload.customerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome do cliente é obrigatório.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await ref.read(apiProvider).updateOrder(token, widget.orderId, payload);
      if (!mounted) return;
      setState(() {
        editing = false;
        saving = false;
        _loadDetail(token);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Widget _buildOrderDetailBody(
    BuildContext context,
    String token,
    StaffUser user,
  ) {
    final canWrite = user.hasPermission('orders.update');
    final isPhotographer = _isPhotographerRole(user.role);
    final canEdit = canWrite && !isPhotographer;
    final canDownload =
        user.hasPermission('orders.download') && !isPhotographer;

    return FutureBuilder<StaffOrderDetail>(
      future:
          _future ??
          ref.read(apiProvider).staffOrderDetail(token, widget.orderId),
      builder: (_, snap) {
        if (!snap.hasData) {
          if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
          return const Center(child: CircularProgressIndicator());
        }
        final order = snap.data!;
        if (!_initialized) {
          _initialized = true;
          nameCtrl.text = order.customerName;
          emailCtrl.text = order.customerEmail ?? '';
          phoneCtrl.text = order.customerPhone ?? '';
          paymentCtrl.text = order.paymentMethod;
          notesCtrl.text = order.notes ?? '';
          cashReceivedCtrl.text = order.cashReceivedAmount != null
              ? formatEuroAmount(order.cashReceivedAmount!)
              : '';
          cashChangeGiven = order.cashChangeGiven;
          status = order.status;
          _orderTotal = order.totalAmount;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Código: ${order.orderCode}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (order.eventName != null) Text('Evento: ${order.eventName}'),
            const SizedBox(height: 8),
            if (!editing) ...[
              Text('Status: ${order.status}'),
              Text(
                'Pagamento: ${order.paymentMethod.isEmpty ? '-' : order.paymentMethod}',
              ),
              Text('Total: ${order.totalAmount}'),
              if (order.cashReceivedAmount != null)
                Text(
                  'Entregue: ${formatEuroAmount(order.cashReceivedAmount!)}€',
                ),
              if ((order.cashChangeAmount ?? 0) > 0)
                Text(
                  order.cashChangeGiven
                      ? 'Troco entregue: ${formatEuroAmount(order.cashChangeAmount!)}€'
                      : 'TROCO por entregar: ${formatEuroAmount(order.cashChangeAmount!)}€',
                  style: TextStyle(
                    color: order.cashChangeGiven
                        ? Colors.lightGreenAccent
                        : Colors.orangeAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if ((order.cashDueAmount ?? 0) > 0)
                Text('DEVE: ${formatEuroAmount(order.cashDueAmount!)}€'),
              if (order.productType != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Produto: ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    _ProductTypeBadge(order.productType!),
                  ],
                ),
                if (order.productType == 'paper' ||
                    order.productType == 'both') ...[
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Icon(Icons.print, size: 16, color: Colors.orangeAccent),
                      SizedBox(width: 6),
                      Text(
                        'Impressão necessária',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              if (order.deliveryType != null)
                Text(
                  'Entrega: ${formatDeliveryTypeLabel(order.deliveryType)}',
                ),
              if ((order.deliveryAddress ?? '').isNotEmpty)
                Text('Morada: ${order.deliveryAddress}'),
              if ((order.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Notas: ${order.notes}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 12),
              Text('Cliente: ${order.customerName}'),
              if ((order.customerEmail ?? '').isNotEmpty)
                Text('Email: ${order.customerEmail}'),
              if ((order.customerPhone ?? '').isNotEmpty)
                Text('Telefone: ${order.customerPhone}'),
              if (canWrite && order.status == 'pending')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () async {
                          final settlement = await promptCashSettlement(
                            context,
                            totalAmount: order.totalAmount,
                            initialNotes: order.notes,
                          );
                          if (settlement == null) return;
                          await ref
                              .read(apiProvider)
                              .markOrderPaid(
                                token,
                                order.id,
                                cashReceivedAmount: settlement.receivedAmount,
                                cashChangeAmount: settlement.changeAmount,
                                cashChangeGiven: settlement.changeGiven,
                                cashDueAmount: settlement.dueAmount,
                                notes: settlement.notes,
                              );
                          if (!context.mounted) return;
                          setState(() => _loadDetail(token));
                        },
                        child: const Text('Pagar'),
                      ),
                      if (!isPhotographer && canEdit)
                        OutlinedButton(
                          onPressed: () => setState(() => editing = true),
                          child: const Text('Editar'),
                        ),
                    ],
                  ),
                ),
              if (canWrite &&
                  order.paymentMethod == 'cash' &&
                  order.status != 'pending')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final edit = await promptCashOrderEdit(
                        context,
                        totalAmount: order.totalAmount,
                        currentStatus: order.status,
                        currentReceived: order.cashReceivedAmount,
                        currentChangeGiven: order.cashChangeGiven,
                        currentNotes: order.notes,
                      );
                      if (edit == null || !context.mounted) return;
                      await ref
                          .read(apiProvider)
                          .updateOrder(
                            token,
                            order.id,
                            StaffOrderUpdatePayload(
                              customerName: order.customerName,
                              status: edit.status,
                              paymentMethod: order.paymentMethod,
                              notes: edit.notes,
                              cashReceivedAmount: edit.receivedAmount,
                              cashChangeAmount: edit.changeAmount,
                              cashChangeGiven: edit.changeGiven,
                              cashDueAmount: edit.dueAmount,
                            ),
                          );
                      if (!context.mounted) return;
                      setState(() => _loadDetail(token));
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Editar pagamento'),
                  ),
                ),
            ] else ...[
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: paymentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pagamento',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: status,
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('pending')),
                  DropdownMenuItem(value: 'paid', child: Text('paid')),
                  DropdownMenuItem(
                    value: 'delivered',
                    child: Text('delivered'),
                  ),
                ],
                onChanged: (v) => setState(() => status = v ?? status),
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  border: OutlineInputBorder(),
                ),
              ),
              if (order.paymentMethod == 'cash') ...[
                const SizedBox(height: 8),
                StatefulBuilder(
                  builder: (_, setInner) {
                    final raw = cashReceivedCtrl.text.trim().replaceAll(
                      ',',
                      '.',
                    );
                    final received = num.tryParse(raw);
                    final change =
                        received != null && received > order.totalAmount
                        ? received - order.totalAmount
                        : 0;
                    final due = received != null && received < order.totalAmount
                        ? order.totalAmount - received
                        : 0;
                    if (change <= 0 && !cashChangeGiven) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => cashChangeGiven = true);
                      });
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: cashReceivedCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setInner(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Dinheiro recebido (€)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (received != null) ...[
                          Text(
                            'Total: €${formatEuroAmount(order.totalAmount)}',
                          ),
                          if (change > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Troco a devolver ao cliente: €${formatEuroAmount(change)}',
                                  style: const TextStyle(
                                    color: Colors.orangeAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: cashChangeGiven,
                                  onChanged: (value) {
                                    setState(
                                      () => cashChangeGiven = value ?? false,
                                    );
                                    setInner(() {});
                                  },
                                  title: const Text(
                                    'Troco entregue ao cliente',
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                ),
                              ],
                            ),
                          if (due > 0)
                            Text(
                              'Falta receber: €${formatEuroAmount(due)}',
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          if (change == 0 && due == 0)
                            const Text(
                              'Pagamento exato.',
                              style: TextStyle(color: Colors.lightGreenAccent),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: saving ? null : () => _save(token),
                child: Text(saving ? 'A guardar...' : 'Guardar'),
              ),
            ],
            const SizedBox(height: 16),
            const Text('Fotos', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (order.photos.isEmpty)
              const Text('Sem fotos.')
            else
              Wrap(
                spacing: 6,
                children: order.photos
                    .map((p) => Chip(label: Text(p.number)))
                    .toList(),
              ),
            const SizedBox(height: 16),
            if (canDownload)
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final sent = await ref
                          .read(apiProvider)
                          .staffSendDownloadLink(token, order.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            sent ? 'Link enviado.' : 'Falha no envio.',
                          ),
                        ),
                      );
                    },
                    child: const Text('Enviar link'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final path = await ref
                          .read(apiProvider)
                          .staffDownloadAll(token, order.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('ZIP guardado: $path')),
                      );
                    },
                    child: const Text('Download ZIP'),
                  ),
                ],
              ),
            if (!editing && canEdit && order.status != 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                  onPressed: () => setState(() => editing = true),
                  child: const Text('Editar'),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null)
      return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    if (useDesktopLayout(context)) {
      final canWrite = user.hasPermission('orders.update');
      final isPhotographer = _isPhotographerRole(user.role);
      final canEdit = canWrite && !isPhotographer;
      return StaffDesktopShell(
        user: user,
        token: token,
        initialId: 'orders',
        overrideTitle: 'Pedido',
        overrideSubtitle: 'Detalhe',
        overrideShowSearch: false,
        overrideActionsBuilder: (ctx, u, t) => [
          IconButton(
            onPressed: () => setState(() => _loadDetail(token)),
            icon: const Icon(Icons.refresh),
          ),
          if (canEdit)
            IconButton(
              onPressed: () => setState(() => editing = !editing),
              icon: Icon(editing ? Icons.close : Icons.edit),
            ),
        ],
        overrideContent: (ctx, u, t) => _buildOrderDetailBody(ctx, t, u),
      );
    }
    final canWrite = user.hasPermission('orders.update');
    final isPhotographer = _isPhotographerRole(user.role);
    final canEdit = canWrite && !isPhotographer;
    final canDownload =
        user.hasPermission('orders.download') && !isPhotographer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedido'),
        leading: navLeading(context),
        actions: navActions(
          context,
          extra: [
            IconButton(
              onPressed: () => setState(() => _loadDetail(token)),
              icon: const Icon(Icons.refresh),
            ),
            if (canEdit)
              IconButton(
                onPressed: () => setState(() => editing = !editing),
                icon: Icon(editing ? Icons.close : Icons.edit),
              ),
          ],
        ),
      ),
      body: _buildOrderDetailBody(context, token, user),
    );
  }
}

class StaffSettingsPage extends ConsumerStatefulWidget {
  const StaffSettingsPage({super.key});

  @override
  ConsumerState<StaffSettingsPage> createState() => _StaffSettingsPageState();
}

class _StaffSettingsPageState extends ConsumerState<StaffSettingsPage> {
  late final TextEditingController nameCtrl;
  late final TextEditingController usernameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController passwordCtrl;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    saveStaffLastRoute('settings', userId: ref.read(staffUserProvider)?.id);
    final user = ref.read(staffUserProvider);
    nameCtrl = TextEditingController(text: user?.name ?? '');
    usernameCtrl = TextEditingController(text: user?.username ?? '');
    emailCtrl = TextEditingController(text: user?.email ?? '');
    passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null)
      return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    if (useDesktopLayout(context)) {
      return StaffDesktopShell(user: user, token: token, initialId: 'settings');
    }

    return Scaffold(
      appBar: buildNavAppBar(context, 'Definições'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Username (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nova password (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      if (name.isEmpty || email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nome e email são obrigatórios.'),
                          ),
                        );
                        return;
                      }
                      setState(() => saving = true);
                      try {
                        final updated = await ref
                            .read(apiProvider)
                            .updateProfile(
                              token,
                              name: name,
                              email: email,
                              username: usernameCtrl.text.trim(),
                              password: passwordCtrl.text.trim(),
                            );
                        ref.read(staffUserProvider.notifier).state = updated;
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Definições atualizadas.'),
                          ),
                        );
                        passwordCtrl.clear();
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                      } finally {
                        if (mounted) setState(() => saving = false);
                      }
                    },
              child: Text(saving ? 'A guardar...' : 'Guardar'),
            ),
            if (_isAdminRole(user.role)) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaffAppConfigPage()),
                ),
                icon: const Icon(Icons.router_outlined),
                label: const Text('Ligações e runtime config'),
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(staffTokenProvider.notifier).state = null;
                ref.read(staffUserProvider.notifier).state = null;
                clearStaffSession();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Terminar sessão'),
            ),
          ],
        ),
      ),
    );
  }
}

class StaffAppConfigPage extends ConsumerStatefulWidget {
  const StaffAppConfigPage({super.key});

  @override
  ConsumerState<StaffAppConfigPage> createState() => _StaffAppConfigPageState();
}

class _StaffAppConfigPageState extends ConsumerState<StaffAppConfigPage> {
  @override
  void initState() {
    super.initState();
    saveStaffLastRoute('app-config', userId: ref.read(staffUserProvider)?.id);
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null)
      return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    if (!_isAdminRole(user.role)) {
      return Scaffold(
        appBar: buildNavAppBar(context, 'Ligações'),
        body: const Center(child: Text('Sem acesso.')),
      );
    }
    if (useDesktopLayout(context)) {
      return StaffDesktopShell(
        user: user,
        token: token,
        initialId: 'app-config',
      );
    }
    return Scaffold(
      appBar: buildNavAppBar(context, 'Ligações'),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: AppRuntimeConfigForm(),
      ),
    );
  }
}

class StaffOfflineHostPage extends ConsumerStatefulWidget {
  const StaffOfflineHostPage({super.key, this.seedEvent});

  final StaffEvent? seedEvent;

  @override
  ConsumerState<StaffOfflineHostPage> createState() =>
      _StaffOfflineHostPageState();
}

class _StaffOfflineHostPageState extends ConsumerState<StaffOfflineHostPage> {
  @override
  void initState() {
    super.initState();
    saveStaffLastRoute('offline-host', userId: ref.read(staffUserProvider)?.id);
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null)
      return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    if (!isDesktopPlatform()) {
      return Scaffold(
        appBar: buildNavAppBar(context, 'Sessão Offline'),
        body: const Center(child: Text('Disponível apenas no PC/Mac.')),
      );
    }
    if (useDesktopLayout(context)) {
      return StaffDesktopShell(
        user: user,
        token: token,
        initialId: 'offline-host',
        overrideTitle: 'Sessão Offline',
        overrideSubtitle: 'Servidor local no PC',
        overrideContent: (ctx, u, t) => DesktopOfflineHostView(
          user: u,
          token: t,
          seedEvent: widget.seedEvent,
        ),
      );
    }
    return Scaffold(
      appBar: buildNavAppBar(context, 'Sessão Offline'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: OfflineHostForm(seedEvent: widget.seedEvent),
      ),
    );
  }
}

class OfflineBootstrapPage extends StatelessWidget {
  const OfflineBootstrapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildNavAppBar(context, 'Sessão Offline'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: OfflineHostForm(
          onStarted: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
              (_) => false,
            );
          },
        ),
      ),
    );
  }
}

class DesktopOfflineHostView extends StatelessWidget {
  const DesktopOfflineHostView({
    super.key,
    required this.user,
    required this.token,
    this.seedEvent,
  });

  final StaffUser user;
  final String token;
  final StaffEvent? seedEvent;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDeskGutter),
      child: OfflineHostForm(seedEvent: seedEvent, embedded: true),
    );
  }
}

class OfflineHostForm extends ConsumerStatefulWidget {
  const OfflineHostForm({
    super.key,
    this.seedEvent,
    this.embedded = false,
    this.onStarted,
  });

  final StaffEvent? seedEvent;
  final bool embedded;
  final FutureOr<void> Function()? onStarted;

  @override
  ConsumerState<OfflineHostForm> createState() => _OfflineHostFormState();
}

class _OfflineHostFormState extends ConsumerState<OfflineHostForm> {
  late final TextEditingController nameCtrl;
  late final TextEditingController dateCtrl;
  late final TextEditingController typeCtrl;
  late final TextEditingController locationCtrl;
  late final TextEditingController priceCtrl;
  late final TextEditingController pinCtrl;
  late final TextEditingController folderCtrl;
  late final TextEditingController usernameCtrl;
  late final TextEditingController passwordCtrl;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(offlineHostSessionProvider);
    final seed = widget.seedEvent;
    nameCtrl = TextEditingController(
      text: seed?.name ?? current?.eventName ?? '',
    );
    dateCtrl = TextEditingController(
      text:
          seed?.eventDate ??
          current?.eventDate ??
          DateTime.now().toIso8601String().substring(0, 10),
    );
    typeCtrl = TextEditingController(
      text: seed?.eventType ?? current?.eventType ?? 'casamento',
    );
    locationCtrl = TextEditingController(
      text: seed?.location ?? current?.location ?? '',
    );
    priceCtrl = TextEditingController(
      text: (seed?.pricePerPhoto ?? current?.pricePerPhoto ?? 5).toString(),
    );
    pinCtrl = TextEditingController(
      text: seed?.accessPin ?? current?.accessPin ?? '0000',
    );
    folderCtrl = TextEditingController(text: current?.photoDir ?? '');
    usernameCtrl = TextEditingController(
      text:
          current?.staffUsername ??
          generateOfflineUsername(seed?.name ?? 'offline'),
    );
    passwordCtrl = TextEditingController(
      text: current?.staffPassword ?? generateOfflinePassword(),
    );
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    dateCtrl.dispose();
    typeCtrl.dispose();
    locationCtrl.dispose();
    priceCtrl.dispose();
    pinCtrl.dispose();
    folderCtrl.dispose();
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  StaffUser _localStaffUser(OfflineHostSession session) => StaffUser(
    id: session.staffUserId,
    name: session.staffName,
    email: '',
    role: 'staff',
    permissions: const [
      'dashboard.view',
      'events.list',
      'events.view',
      'orders.list',
      'orders.view',
      'orders.update',
      'offline.export',
      'offline.import',
    ],
    username: session.staffUsername,
  );

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null || path.trim().isEmpty) return;
    setState(() => folderCtrl.text = path);
  }

  Future<void> _start() async {
    if (saving) return;
    final name = nameCtrl.text.trim();
    final date = dateCtrl.text.trim();
    final folder = folderCtrl.text.trim();
    final username = usernameCtrl.text.trim();
    final password = passwordCtrl.text.trim();
    final pin = pinCtrl.text.trim();
    final price = num.tryParse(priceCtrl.text.trim().replaceAll(',', '.'));
    if (name.isEmpty ||
        date.isEmpty ||
        folder.isEmpty ||
        username.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preenche os campos obrigatórios.')),
      );
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN com 4 dígitos.')));
      return;
    }
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preço por foto inválido.')));
      return;
    }
    setState(() => saving = true);
    try {
      final photos = await scanOfflinePhotos(folder);
      if (photos.isEmpty) {
        throw Exception('Sem fotos na pasta selecionada.');
      }
      final now = DateTime.now().toIso8601String();
      final currentConfig = ref.read(appRuntimeConfigProvider);
      if (!looksLikeLocalApiBaseUrl(currentConfig.apiBaseUrl)) {
        await backupRuntimeConfig(currentConfig);
        await backupCurrentStaffSession();
      }
      final seed = widget.seedEvent;
      final existing = ref.read(offlineHostSessionProvider);
      final session = OfflineHostSession(
        isActive: true,
        sessionId: const Uuid().v4(),
        eventId:
            seed?.id ??
            existing?.eventId ??
            DateTime.now().millisecondsSinceEpoch,
        eventName: name,
        eventDate: date,
        eventType: typeCtrl.text.trim(),
        location: locationCtrl.text.trim(),
        pricePerPhoto: price,
        basePrice: seed?.basePrice ?? existing?.basePrice ?? 0,
        accessPin: pin,
        qrToken: existing?.qrToken ?? generateOfflineToken(),
        guestToken: existing?.guestToken ?? generateOfflineToken(),
        photoDir: folder,
        photos: photos,
        orders: existing != null && existing.photoDir == folder
            ? existing.orders
            : const [],
        eventMeta:
            seed?.eventMeta ?? existing?.eventMeta ?? const <String, dynamic>{},
        staffUsername: username,
        staffPassword: password,
        staffToken: existing?.staffToken ?? generateOfflineToken(),
        staffName: ref.read(staffUserProvider)?.name ?? 'Offline Staff',
        staffUserId: existing?.staffUserId ?? 1,
        port: existing?.port ?? 4000,
        serverHost: existing?.serverHost ?? '127.0.0.1',
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      final started = await OfflineHostServer.instance.start(session);
      final localConfig = currentConfig.copyWith(
        apiBaseUrl: started.localApiBaseUrl,
        apiFallbackIp: '',
      );
      await saveAppRuntimeConfig(localConfig);
      ref.read(appRuntimeConfigProvider.notifier).state = localConfig;
      ref.read(offlineHostSessionProvider.notifier).state = started.session;
      final localUser = _localStaffUser(started.session);
      ref.read(staffTokenProvider.notifier).state = started.session.staffToken;
      ref.read(staffUserProvider.notifier).state = localUser;
      await saveStaffSession(started.session.staffToken, localUser);
      await saveStaffLastRoute('offline-host', userId: localUser.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sessão offline ativa com ${photos.length} fotos.'),
        ),
      );
      await widget.onStarted?.call();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _stop() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await OfflineHostServer.instance.stop();
      await clearOfflineHostSession();
      ref.read(offlineHostSessionProvider.notifier).state = null;
      final restoredConfig =
          await restoreBackedUpRuntimeConfig() ?? AppRuntimeConfig.defaults;
      await saveAppRuntimeConfig(restoredConfig);
      ref.read(appRuntimeConfigProvider.notifier).state = restoredConfig;
      final restoredStaff = await restoreBackedUpStaffSession();
      await clearBackedUpRuntimeConfig();
      await clearBackedUpStaffSession();
      if (restoredStaff != null) {
        ref.read(staffTokenProvider.notifier).state = restoredStaff.token;
        ref.read(staffUserProvider.notifier).state = restoredStaff.user;
        await saveStaffSession(restoredStaff.token, restoredStaff.user);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
          (_) => false,
        );
        return;
      }
      ref.read(staffTokenProvider.notifier).state = null;
      ref.read(staffUserProvider.notifier).state = null;
      await clearStaffSession();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const HomePage(skipStaffAutoOpen: true),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(offlineHostSessionProvider);
    final effectiveSession = OfflineHostServer.instance.session ?? session;
    final header = widget.embedded
        ? const _DeskSectionHeader('Sessão offline')
        : const SizedBox.shrink();
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (effectiveSession != null) ...[
          Text(
            effectiveSession.isActive
                ? 'Ativa: ${effectiveSession.lanApiBaseUrl}'
                : 'Sessão guardada',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Evento',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: dateCtrl,
          decoration: const InputDecoration(
            labelText: 'Data (YYYY-MM-DD)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: typeCtrl,
          decoration: const InputDecoration(
            labelText: 'Tipo',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: locationCtrl,
          decoration: const InputDecoration(
            labelText: 'Local',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: priceCtrl,
          decoration: const InputDecoration(
            labelText: 'Preço por foto',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: pinCtrl,
          decoration: const InputDecoration(
            labelText: 'PIN cliente',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: folderCtrl,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Pasta das fotos',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: saving ? null : _pickFolder,
              icon: const Icon(Icons.folder_open),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: usernameCtrl,
          decoration: const InputDecoration(
            labelText: 'Username temporário',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: passwordCtrl,
          decoration: InputDecoration(
            labelText: 'Password temporária',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: saving
                  ? null
                  : () => setState(
                      () => passwordCtrl.text = generateOfflinePassword(),
                    ),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: saving ? null : _start,
              icon: const Icon(Icons.play_arrow),
              label: Text(saving ? 'A processar...' : 'Iniciar sessão'),
            ),
            if (effectiveSession != null && effectiveSession.isActive)
              OutlinedButton.icon(
                onPressed: saving ? null : _stop,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Fechar sessão'),
              ),
          ],
        ),
        if (effectiveSession != null && effectiveSession.isActive) ...[
          const SizedBox(height: 20),
          Text('API local: ${effectiveSession.lanApiBaseUrl}'),
          Text('Username: ${effectiveSession.staffUsername}'),
          Text('Password: ${effectiveSession.staffPassword}'),
          Text('PIN cliente: ${effectiveSession.accessPin}'),
          Text('Fotos: ${effectiveSession.photos.length}'),
          Text('JSON: ${effectiveSession.ordersFilePath}'),
          const SizedBox(height: 12),
          Container(
            color: kBrandRose,
            padding: const EdgeInsets.all(8),
            child: QrImageView(
              data: effectiveSession.publicQrUrl,
              size: 220,
              backgroundColor: kBrandRose,
              foregroundColor: kBrandBlack,
            ),
          ),
        ],
      ],
    );
    if (!widget.embedded) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 12),
        _DeskCard(child: body),
      ],
    );
  }
}

class AppRuntimeConfigForm extends ConsumerStatefulWidget {
  const AppRuntimeConfigForm({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<AppRuntimeConfigForm> createState() =>
      _AppRuntimeConfigFormState();
}

class _AppRuntimeConfigFormState extends ConsumerState<AppRuntimeConfigForm> {
  late final TextEditingController apiBaseUrlCtrl;
  late final TextEditingController apiFallbackIpCtrl;
  late final TextEditingController merchantCountryCodeCtrl;
  late final TextEditingController applePayMerchantIdCtrl;
  late final TextEditingController stripeUrlSchemeCtrl;
  late final TextEditingController stripePercentFeeCtrl;
  late final TextEditingController stripeFixedFeeCtrl;
  late final TextEditingController commissionRateCtrl;
  bool enablePlatformPay = true;
  bool saving = false;
  bool testing = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(appRuntimeConfigProvider);
    apiBaseUrlCtrl = TextEditingController(text: config.apiBaseUrl);
    apiFallbackIpCtrl = TextEditingController(text: config.apiFallbackIp);
    merchantCountryCodeCtrl = TextEditingController(
      text: config.merchantCountryCode,
    );
    applePayMerchantIdCtrl = TextEditingController(
      text: config.applePayMerchantId,
    );
    stripeUrlSchemeCtrl = TextEditingController(text: config.stripeUrlScheme);
    stripePercentFeeCtrl = TextEditingController(
      text: config.stripePercentFee.toString(),
    );
    stripeFixedFeeCtrl = TextEditingController(
      text: config.stripeFixedFee.toString(),
    );
    commissionRateCtrl = TextEditingController(
      text: config.commissionRate.toString(),
    );
    enablePlatformPay = config.enablePlatformPay;
  }

  @override
  void dispose() {
    apiBaseUrlCtrl.dispose();
    apiFallbackIpCtrl.dispose();
    merchantCountryCodeCtrl.dispose();
    applePayMerchantIdCtrl.dispose();
    stripeUrlSchemeCtrl.dispose();
    stripePercentFeeCtrl.dispose();
    stripeFixedFeeCtrl.dispose();
    commissionRateCtrl.dispose();
    super.dispose();
  }

  AppRuntimeConfig _candidateConfig() => AppRuntimeConfig(
    apiBaseUrl: apiBaseUrlCtrl.text.trim(),
    apiFallbackIp: apiFallbackIpCtrl.text.trim(),
    merchantCountryCode: merchantCountryCodeCtrl.text.trim(),
    applePayMerchantId: applePayMerchantIdCtrl.text.trim(),
    enablePlatformPay: enablePlatformPay,
    stripeUrlScheme: stripeUrlSchemeCtrl.text.trim(),
    stripePercentFee:
        double.tryParse(
          stripePercentFeeCtrl.text.trim().replaceAll(',', '.'),
        ) ??
        AppRuntimeConfig.defaults.stripePercentFee,
    stripeFixedFee:
        double.tryParse(stripeFixedFeeCtrl.text.trim().replaceAll(',', '.')) ??
        AppRuntimeConfig.defaults.stripeFixedFee,
    commissionRate:
        double.tryParse(commissionRateCtrl.text.trim().replaceAll(',', '.')) ??
        AppRuntimeConfig.defaults.commissionRate,
  );

  Future<void> _goHomeClearingSessions() async {
    ref.read(guestSessionProvider.notifier).state = null;
    ref.read(staffTokenProvider.notifier).state = null;
    ref.read(staffUserProvider.notifier).state = null;
    await clearStaffSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePage(skipStaffAutoOpen: true),
      ),
      (_) => false,
    );
  }

  String? _validate(AppRuntimeConfig config) {
    final uri = Uri.tryParse(config.apiBaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      return 'API Base URL inválida.';
    }
    if (config.merchantCountryCode.isEmpty) {
      return 'Merchant Country Code é obrigatório.';
    }
    if (config.stripeUrlScheme.isEmpty) {
      return 'Stripe URL Scheme é obrigatório.';
    }
    return null;
  }

  Future<void> _testConnection() async {
    final config = _candidateConfig();
    final error = _validate(config);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => testing = true);
    try {
      final ok = await ApiService(config).pingPublic();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Ligação válida.' : 'Sem resposta do servidor.'),
        ),
      );
    } finally {
      if (mounted) setState(() => testing = false);
    }
  }

  Future<void> _save() async {
    final config = _candidateConfig();
    final error = _validate(config);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => saving = true);
    try {
      await saveAppRuntimeConfig(config);
      ref.read(appRuntimeConfigProvider.notifier).state = config;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuração guardada. A sessão será reiniciada.'),
        ),
      );
      await _goHomeClearingSessions();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _resetDefaults() async {
    final config = AppRuntimeConfig.defaults;
    apiBaseUrlCtrl.text = config.apiBaseUrl;
    apiFallbackIpCtrl.text = config.apiFallbackIp;
    merchantCountryCodeCtrl.text = config.merchantCountryCode;
    applePayMerchantIdCtrl.text = config.applePayMerchantId;
    stripeUrlSchemeCtrl.text = config.stripeUrlScheme;
    stripePercentFeeCtrl.text = config.stripePercentFee.toString();
    stripeFixedFeeCtrl.text = config.stripeFixedFee.toString();
    commissionRateCtrl.text = config.commissionRate.toString();
    setState(() => enablePlatformPay = config.enablePlatformPay);
    await clearAppRuntimeConfig();
    ref.read(appRuntimeConfigProvider.notifier).state = config;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Valores repostos aos defaults da build.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appRuntimeConfigProvider);
    final header = widget.embedded
        ? const _DeskSectionHeader('Ligações e runtime config')
        : const SizedBox.shrink();
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ativo: ${config.apiBaseUrl}',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: apiBaseUrlCtrl,
          decoration: const InputDecoration(
            labelText: 'API Base URL',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: apiFallbackIpCtrl,
          decoration: const InputDecoration(
            labelText: 'API Fallback IP',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: merchantCountryCodeCtrl,
          decoration: const InputDecoration(
            labelText: 'Merchant Country Code',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: applePayMerchantIdCtrl,
          decoration: const InputDecoration(
            labelText: 'Apple Pay Merchant ID',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: stripeUrlSchemeCtrl,
          decoration: const InputDecoration(
            labelText: 'Stripe URL Scheme',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: enablePlatformPay,
          onChanged: (value) => setState(() => enablePlatformPay = value),
          title: const Text('Ativar Platform Pay'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Taxas Stripe (pagamento online)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Adicionadas automaticamente ao total quando o cliente escolhe pagamento online.',
          style: TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: stripePercentFeeCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Taxa % (ex: 1.5)',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: stripeFixedFeeCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Taxa fixa (ex: 0.25)',
                  suffixText: '€',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Comissão de equipa',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Percentagem aplicada ao valor por membro da equipa no final do evento.',
          style: TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: commissionRateCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Taxa de comissão (ex: 15)',
            suffixText: '%',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: saving ? null : _save,
              child: Text(
                saving ? 'A guardar...' : 'Guardar e reiniciar sessão',
              ),
            ),
            OutlinedButton(
              onPressed: testing ? null : _testConnection,
              child: Text(testing ? 'A testar...' : 'Testar ligação'),
            ),
            OutlinedButton(
              onPressed: saving ? null : _resetDefaults,
              child: const Text('Repor defaults'),
            ),
          ],
        ),
      ],
    );

    if (!widget.embedded) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 12),
        _DeskCard(child: body),
      ],
    );
  }
}

class StaffUsersPage extends ConsumerStatefulWidget {
  const StaffUsersPage({super.key});

  @override
  ConsumerState<StaffUsersPage> createState() => _StaffUsersPageState();
}

class _StaffUsersPageState extends ConsumerState<StaffUsersPage> {
  Future<List<StaffUser>>? _future;
  String? _lastToken;

  @override
  void initState() {
    super.initState();
    saveStaffLastRoute('users', userId: ref.read(staffUserProvider)?.id);
    _reload();
  }

  void _reload() {
    final token = ref.read(staffTokenProvider);
    if (token == null) return;
    _lastToken = token;
    _future = ref.read(apiProvider).staffUsers(token);
    setState(() {});
  }

  Widget _buildUsersBody(BuildContext context, String token) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<StaffUser>>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) {
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Erro: ${snap.error}'),
                  ),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }
          final users = snap.data!;
          if (users.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Sem utilizadores'),
                ),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: users.length,
            itemBuilder: (_, i) {
              final u = users[i];
              final canUpdate =
                  ref.read(staffUserProvider)?.hasPermission('users.update') ==
                  true;
              final canDelete =
                  ref.read(staffUserProvider)?.hasPermission('users.delete') ==
                  true;
              return Card(
                child: ListTile(
                  title: Text(u.name),
                  subtitle: Text(
                    '${u.username ?? '-'} • ${u.email} • ${u.role}',
                  ),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      if (canUpdate)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StaffUserFormPage(user: u),
                              ),
                            );
                            _reload();
                          },
                        ),
                      if (canDelete)
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await _confirm(
                              context,
                              'Apagar utilizador?',
                              u.email,
                            );
                            if (!ok) return;
                            try {
                              await ref
                                  .read(apiProvider)
                                  .deleteUser(token, u.id);
                              if (!context.mounted) return;
                              _reload();
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro: $e')),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    if (token == null)
      return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    final user = ref.watch(staffUserProvider);
    if (user != null && useDesktopLayout(context)) {
      return StaffDesktopShell(
        user: user,
        token: token,
        initialId: 'users',
        overrideTitle: 'Utilizadores',
        overrideSubtitle: 'Gestao de equipa',
        overrideShowSearch: false,
        overrideActionsBuilder: (ctx, u, t) => [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
          if (user.hasPermission('users.create'))
            IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaffUserFormPage()),
                );
                _reload();
              },
              icon: const Icon(Icons.add),
            ),
        ],
        overrideContent: (ctx, u, t) => _buildUsersBody(ctx, t),
      );
    }

    if (_future == null || _lastToken != token) {
      _lastToken = token;
      _future = ref.read(apiProvider).staffUsers(token);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilizadores'),
        leading: navLeading(context),
        actions: navActions(
          context,
          extra: [
            IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
          ],
        ),
      ),
      floatingActionButton: user?.hasPermission('users.create') == true
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaffUserFormPage()),
                );
                _reload();
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: _buildUsersBody(context, token),
    );
  }
}

class StaffUserFormPage extends ConsumerStatefulWidget {
  const StaffUserFormPage({super.key, this.user});
  final StaffUser? user;

  @override
  ConsumerState<StaffUserFormPage> createState() => _StaffUserFormPageState();
}

class _StaffUserFormPageState extends ConsumerState<StaffUserFormPage> {
  late final TextEditingController nameCtrl;
  late final TextEditingController usernameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController passwordCtrl;
  String role = 'photographer';
  final selectedPermissions = <String>{};
  bool saving = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.user?.name ?? '');
    usernameCtrl = TextEditingController(text: widget.user?.username ?? '');
    emailCtrl = TextEditingController(text: widget.user?.email ?? '');
    passwordCtrl = TextEditingController();
    role = _normalizeRole(widget.user?.role ?? 'photographer');
    if (widget.user != null) {
      selectedPermissions.addAll(widget.user!.permissions);
    } else {
      _applyRoleDefaults(role);
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  void _applyRoleDefaults(String nextRole) {
    selectedPermissions.clear();
    if (nextRole == 'admin') {
      selectedPermissions.addAll(kStaffPermissions.keys);
    } else if (nextRole == 'photographer') {
      selectedPermissions.addAll(kStaffDefaultPermissions);
    }
  }

  Widget _buildUserFormBody(
    BuildContext context,
    String token, {
    required bool permissionsLocked,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: usernameCtrl,
            decoration: const InputDecoration(
              labelText: 'Username (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: role,
            items: const [
              DropdownMenuItem(value: 'photographer', child: Text('Fotógrafo')),
              DropdownMenuItem(value: 'admin', child: Text('Administrador')),
            ],
            onChanged: (v) => setState(() {
              role = _normalizeRole(v ?? 'photographer');
              _applyRoleDefaults(role);
            }),
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Permissões',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...kStaffPermissions.entries.map(
            (e) => CheckboxListTile(
              value: selectedPermissions.contains(e.key),
              onChanged: permissionsLocked
                  ? null
                  : (v) => setState(() {
                      if (v == true) {
                        selectedPermissions.add(e.key);
                      } else {
                        selectedPermissions.remove(e.key);
                      }
                    }),
              title: Text(e.value),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    final payload = StaffUserPayload(
                      name: nameCtrl.text.trim(),
                      username: usernameCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      role: role,
                      permissions: selectedPermissions.toList(),
                      password: passwordCtrl.text.trim().isEmpty
                          ? null
                          : passwordCtrl.text.trim(),
                    );
                    if (payload.name.isEmpty || payload.email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nome e email são obrigatórios.'),
                        ),
                      );
                      return;
                    }
                    try {
                      setState(() => saving = true);
                      if (widget.user == null) {
                        await ref.read(apiProvider).createUser(token, payload);
                      } else {
                        await ref
                            .read(apiProvider)
                            .updateUser(token, widget.user!.id, payload);
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
            child: Text(saving ? 'A guardar...' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    if (token == null)
      return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    final permissionsLocked = role == 'admin';
    final user = ref.watch(staffUserProvider);
    if (user != null && useDesktopLayout(context)) {
      return StaffDesktopShell(
        user: user,
        token: token,
        initialId: 'users',
        overrideTitle: widget.user == null
            ? 'Novo utilizador'
            : 'Editar utilizador',
        overrideSubtitle: 'Gestao de equipa',
        overrideShowSearch: false,
        overrideContent: (ctx, u, t) =>
            _buildUserFormBody(ctx, t, permissionsLocked: permissionsLocked),
      );
    }

    return Scaffold(
      appBar: buildNavAppBar(
        context,
        widget.user == null ? 'Novo utilizador' : 'Editar utilizador',
      ),
      body: _buildUserFormBody(
        context,
        token,
        permissionsLocked: permissionsLocked,
      ),
    );
  }
}

class StaffClientsPage extends ConsumerStatefulWidget {
  const StaffClientsPage({super.key});

  @override
  ConsumerState<StaffClientsPage> createState() => _StaffClientsPageState();
}

class _StaffClientsPageState extends ConsumerState<StaffClientsPage> {
  final searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    saveStaffLastRoute('clients', userId: ref.read(staffUserProvider)?.id);
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  Future<List<StaffClient>> _loadClients(String token) =>
      ref.read(apiProvider).staffClients(token, q: searchCtrl.text.trim());

  Widget _buildClientsBody(BuildContext context, String token, StaffUser user) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: searchCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Pesquisar',
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<StaffClient>>(
              future: _loadClients(token),
              builder: (_, snap) {
                if (!snap.hasData) {
                  if (snap.hasError)
                    return Center(child: Text('Erro: ${snap.error}'));
                  return const Center(child: CircularProgressIndicator());
                }
                final clients = snap.data!;
                if (clients.isEmpty)
                  return const Center(child: Text('Sem clientes'));
                return ListView.builder(
                  itemCount: clients.length,
                  itemBuilder: (_, i) {
                    final c = clients[i];
                    final initials = c.name
                        .trim()
                        .split(' ')
                        .take(2)
                        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
                        .join('');
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: kDeskCard,
                        borderRadius: BorderRadius.circular(kDeskRadius),
                        border: Border.all(color: kBrandRose.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: kBrandRose.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(kDeskRadius),
                          onTap: user.hasPermission('clients.update')
                              ? () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          StaffClientFormPage(client: c),
                                    ),
                                  );
                                  setState(() {});
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: kBrandRose.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: kBrandRose.withOpacity(0.4),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: kBrandRose,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (c.phone != null &&
                                          c.phone!.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.phone_outlined,
                                              size: 12,
                                              color: kDeskMuted,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              c.phone!,
                                              style: const TextStyle(
                                                color: kDeskMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (c.email != null &&
                                          c.email!.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.email_outlined,
                                              size: 12,
                                              color: kDeskMuted,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                c.email!,
                                                style: const TextStyle(
                                                  color: kDeskMuted,
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (user.hasPermission('clients.delete'))
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                    ),
                                    color: kDeskMuted,
                                    onPressed: () async {
                                      final ok = await _confirm(
                                        context,
                                        'Remover cliente?',
                                        c.name,
                                      );
                                      if (!ok) return;
                                      await ref
                                          .read(apiProvider)
                                          .deleteClient(token, c.id);
                                      if (!context.mounted) return;
                                      setState(() {});
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null)
      return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    if (useDesktopLayout(context)) {
      return StaffDesktopShell(
        user: user,
        token: token,
        initialId: 'clients',
        overrideTitle: 'Clientes',
        overrideSubtitle: 'Base de clientes',
        overrideShowSearch: false,
        overrideActionsBuilder: (ctx, u, t) => [
          IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
          if (user.hasPermission('clients.create'))
            IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StaffClientFormPage(),
                  ),
                );
                setState(() {});
              },
              icon: const Icon(Icons.add),
            ),
        ],
        overrideContent: (ctx, u, t) => _buildClientsBody(ctx, t, u),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        leading: navLeading(context),
        actions: navActions(
          context,
          extra: [
            IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      floatingActionButton: user.hasPermission('clients.create')
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StaffClientFormPage(),
                  ),
                );
                setState(() {});
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: _buildClientsBody(context, token, user),
    );
  }
}

class StaffClientFormPage extends ConsumerStatefulWidget {
  const StaffClientFormPage({super.key, this.client});
  final StaffClient? client;

  @override
  ConsumerState<StaffClientFormPage> createState() =>
      _StaffClientFormPageState();
}

class _StaffClientFormPageState extends ConsumerState<StaffClientFormPage> {
  late final TextEditingController nameCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController notesCtrl;
  bool marketingConsent = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.client?.name ?? '');
    phoneCtrl = TextEditingController(text: widget.client?.phone ?? '');
    emailCtrl = TextEditingController(text: widget.client?.email ?? '');
    notesCtrl = TextEditingController(text: widget.client?.notes ?? '');
    marketingConsent = widget.client?.marketingConsent ?? false;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  Widget _buildClientFormBody(BuildContext context, String token) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nome',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: phoneCtrl,
          decoration: const InputDecoration(
            labelText: 'Telemóvel',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: emailCtrl,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: notesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notas',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: marketingConsent,
          onChanged: (v) => setState(() => marketingConsent = v),
          title: const Text('Consentimento marketing'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  final payload = StaffClientPayload(
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                    marketingConsent: marketingConsent,
                  );
                  if (payload.name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nome é obrigatório.')),
                    );
                    return;
                  }
                  try {
                    setState(() => saving = true);
                    if (widget.client == null) {
                      await ref.read(apiProvider).createClient(token, payload);
                    } else {
                      await ref
                          .read(apiProvider)
                          .updateClient(token, widget.client!.id, payload);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                  } finally {
                    if (mounted) setState(() => saving = false);
                  }
                },
          child: Text(saving ? 'A guardar...' : 'Guardar'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    if (token == null)
      return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    final user = ref.watch(staffUserProvider);
    if (user != null && useDesktopLayout(context)) {
      return StaffDesktopShell(
        user: user,
        token: token,
        initialId: 'clients',
        overrideTitle: widget.client == null
            ? 'Novo cliente'
            : 'Editar cliente',
        overrideSubtitle: 'Base de clientes',
        overrideShowSearch: false,
        overrideContent: (ctx, u, t) => _buildClientFormBody(ctx, t),
      );
    }

    return Scaffold(
      appBar: buildNavAppBar(
        context,
        widget.client == null ? 'Novo cliente' : 'Editar cliente',
      ),
      body: _buildClientFormBody(context, token),
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String message) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  ).then((value) => value ?? false);
}

class SecureScreen extends StatefulWidget {
  final Widget child;
  const SecureScreen({super.key, required this.child});

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  static const channel = MethodChannel('studio59/screen_record');
  static int _secureScreenCount = 0;
  final FlutterPreventScreenCapture _preventScreenCapture =
      FlutterPreventScreenCapture();
  Timer? timer;
  Timer? screenshotTimer;
  StreamSubscription<bool>? _screenRecordsSubscription;
  bool isRecording = false;
  bool screenshotDetected = false;

  Future<void> _applyAndroidSecureFlag() async {
    if (!Platform.isAndroid) return;
    final enabled = _secureScreenCount > 0;
    try {
      await channel.invokeMethod('setSecure', {'enabled': enabled});
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _secureScreenCount += 1;
    _applyAndroidSecureFlag();
    if (Platform.isIOS) {
      _checkScreenRecord();
      _screenRecordsSubscription = _preventScreenCapture.screenRecordsIOS
          .listen(_updateRecordStatus);
      channel.setMethodCallHandler((call) async {
        if (call.method == 'screenshotTaken') {
          if (!mounted) return;
          setState(() => screenshotDetected = true);
          screenshotTimer?.cancel();
          screenshotTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) setState(() => screenshotDetected = false);
          });
        } else if (call.method == 'captureChanged') {
          if (!mounted) return;
          final captured = call.arguments is Map
              ? (call.arguments['captured'] == true)
              : false;
          setState(() => isRecording = captured);
        }
      });
      timer = Timer.periodic(const Duration(seconds: 1), (_) async {
        try {
          final captured =
              await channel.invokeMethod<bool>('isCaptured') ?? false;
          if (mounted) setState(() => isRecording = captured);
        } catch (_) {}
      });
    }
  }

  Future<void> _checkScreenRecord() async {
    try {
      final recordStatus = await _preventScreenCapture.checkScreenRecord();
      _updateRecordStatus(recordStatus);
    } catch (_) {}
  }

  void _updateRecordStatus(bool record) {
    if (!mounted) return;
    setState(() => isRecording = record);
  }

  @override
  void dispose() {
    timer?.cancel();
    screenshotTimer?.cancel();
    _screenRecordsSubscription?.cancel();
    _secureScreenCount -= 1;
    if (_secureScreenCount < 0) _secureScreenCount = 0;
    _applyAndroidSecureFlag();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isRecording && !screenshotDetected) return widget.child;
    return Stack(
      children: [
        IgnorePointer(child: widget.child),
        Positioned.fill(
          child: Container(
            color: kBrandBlack.withOpacity(0.9),
            alignment: Alignment.center,
            child: const Text(
              'Conteúdo protegido\nCaptura de ecrã detetada',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kBrandRose,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CartItem {
  CartItem({
    required this.photoId,
    required this.number,
    this.previewUrl,
    this.quantity = 1,
  });
  final int photoId;
  final String number;
  final String? previewUrl;
  final int quantity;

  CartItem copyWith({int? quantity}) => CartItem(
    photoId: photoId,
    number: number,
    previewUrl: previewUrl,
    quantity: quantity ?? this.quantity,
  );
}

class CartItemPayload {
  CartItemPayload({required this.photoId, required this.quantity});
  final int photoId;
  final int quantity;
}

class StripeIntentPayload {
  StripeIntentPayload({
    required this.orderCode,
    required this.clientSecret,
    required this.publishableKey,
  });
  final String orderCode;
  final String clientSecret;
  final String publishableKey;

  factory StripeIntentPayload.fromJson(Map<String, dynamic> j) =>
      StripeIntentPayload(
        orderCode: j['order_code'] as String? ?? '',
        clientSecret: j['client_secret'] as String? ?? '',
        publishableKey: j['publishable_key'] as String? ?? '',
      );
}

class StripeCheckoutPayload {
  StripeCheckoutPayload({required this.orderCode, required this.checkoutUrl});
  final String orderCode;
  final String checkoutUrl;

  factory StripeCheckoutPayload.fromJson(Map<String, dynamic> j) =>
      StripeCheckoutPayload(
        orderCode: j['order_code'] as String? ?? '',
        checkoutUrl: j['checkout_url'] as String? ?? '',
      );
}

class CartNotifier extends StateNotifier<Map<int, CartItem>> {
  CartNotifier() : super({});

  void toggle(PhotoItem photo) {
    final next = {...state};
    if (next.containsKey(photo.id)) {
      next.remove(photo.id);
    } else {
      next[photo.id] = CartItem(
        photoId: photo.id,
        number: photo.number,
        previewUrl: photo.previewUrl,
        quantity: 1,
      );
    }
    state = next;
  }

  void increment(int id) {
    final item = state[id];
    if (item == null) return;
    state = {...state, id: item.copyWith(quantity: item.quantity + 1)};
  }

  void decrement(int id) {
    final item = state[id];
    if (item == null) return;
    final nextQty = item.quantity - 1;
    if (nextQty <= 0) {
      final next = {...state}..remove(id);
      state = next;
    } else {
      state = {...state, id: item.copyWith(quantity: nextQty)};
    }
  }

  void remove(int id) {
    final next = {...state}..remove(id);
    state = next;
  }

  void clear() => state = {};
}

class SavedOrdersNotifier extends StateNotifier<List<String>> {
  SavedOrdersNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList('order_codes') ?? [];
  }

  Future<void> add(String code) async {
    if (state.contains(code)) return;
    final next = [...state, code];
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('order_codes', next);
  }
}

class ApiService {
  ApiService(this.config)
    : _activeBaseUrl = config.apiBaseUrl,
      _activeFallbackIp = config.apiFallbackIp,
      _dio = _buildDio(config.apiBaseUrl, config.apiFallbackIp) {
    _attachRecoveryInterceptor(_dio);
  }

  final AppRuntimeConfig config;
  String _activeBaseUrl;
  String _activeFallbackIp;
  Dio _dio;

  String get baseUrl => _activeBaseUrl;
  Dio get dio => _dio;

  static Dio _buildDio(String baseUrl, String fallbackIp) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 45),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => _createHttpClient(baseUrl, fallbackIp),
    );
    return dio;
  }

  static HttpClient _createHttpClient(String baseUrl, String fallbackIp) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 30)
      ..findProxy = (_) => 'DIRECT';
    final apiHost = Uri.tryParse(baseUrl)?.host;
    final resolvedFallbackIp = fallbackIp.trim();
    client.connectionFactory = (uri, _, __) async {
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final host =
          resolvedFallbackIp.isNotEmpty &&
              apiHost != null &&
              uri.host == apiHost
          ? resolvedFallbackIp
          : uri.host;
      final task = await Socket.startConnect(host, port);
      if (uri.scheme != 'https') return task;
      return ConnectionTask.fromSocket(
        task.socket.then(
          (socket) => SecureSocket.secure(socket, host: uri.host),
        ),
        task.cancel,
      );
    };
    return client;
  }

  void _attachRecoveryInterceptor(Dio client) {
    client.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (!_shouldAttemptRecovery(error)) {
            handler.next(error);
            return;
          }
          final switched = await _recoverEndpoint();
          if (!switched) {
            handler.next(error);
            return;
          }
          try {
            final retried = await _dio.fetch<dynamic>(
              error.requestOptions.copyWith(
                baseUrl: _activeBaseUrl,
                extra: {
                  ...error.requestOptions.extra,
                  'api_recovery_attempted': true,
                },
              ),
            );
            handler.resolve(retried);
          } catch (_) {
            handler.next(error);
          }
        },
      ),
    );
  }

  bool _shouldAttemptRecovery(DioException error) {
    final isConnectionIssue =
        error.type == DioExceptionType.connectionError ||
        error.error is SocketException;
    if (!isConnectionIssue) return false;
    return error.requestOptions.extra['api_recovery_attempted'] != true;
  }

  Future<bool> _recoverEndpoint() async {
    final candidates = <({String baseUrl, String fallbackIp})>[];
    if (looksLikeLocalApiBaseUrl(_activeBaseUrl)) {
      final onlineConfig =
          await restoreBackedUpRuntimeConfig() ?? AppRuntimeConfig.defaults;
      candidates.add((
        baseUrl: onlineConfig.apiBaseUrl,
        fallbackIp: onlineConfig.apiFallbackIp,
      ));
      final discovery = await discoverOfflineSession(
        timeout: const Duration(seconds: 2),
      );
      if (discovery != null) {
        candidates.add((baseUrl: discovery.serverUrl, fallbackIp: ''));
      }
    } else {
      final discovery = await discoverOfflineSession(
        timeout: const Duration(seconds: 2),
      );
      if (discovery != null) {
        candidates.add((baseUrl: discovery.serverUrl, fallbackIp: ''));
      }
    }

    for (final candidate in candidates) {
      if (candidate.baseUrl == _activeBaseUrl &&
          candidate.fallbackIp == _activeFallbackIp) {
        continue;
      }
      if (!await _canReachApiBaseUrl(candidate.baseUrl, candidate.fallbackIp)) {
        continue;
      }
      await _switchEndpoint(candidate.baseUrl, candidate.fallbackIp);
      return true;
    }
    return false;
  }

  Future<void> _switchEndpoint(String baseUrl, String fallbackIp) async {
    final previousBaseUrl = _activeBaseUrl;
    final previousFallbackIp = _activeFallbackIp;
    final nextConfig = config.copyWith(
      apiBaseUrl: baseUrl,
      apiFallbackIp: fallbackIp,
    );

    if (!looksLikeLocalApiBaseUrl(baseUrl) &&
        looksLikeLocalApiBaseUrl(previousBaseUrl)) {
      await clearBackedUpRuntimeConfig();
    } else if (looksLikeLocalApiBaseUrl(baseUrl) &&
        !looksLikeLocalApiBaseUrl(previousBaseUrl)) {
      await backupRuntimeConfig(
        config.copyWith(
          apiBaseUrl: previousBaseUrl,
          apiFallbackIp: previousFallbackIp,
        ),
      );
    }

    _activeBaseUrl = baseUrl;
    _activeFallbackIp = fallbackIp;
    _dio = _buildDio(baseUrl, fallbackIp);
    _attachRecoveryInterceptor(_dio);
    await saveAppRuntimeConfig(nextConfig);
  }

  Future<bool> _canReachApiBaseUrl(String baseUrl, String fallbackIp) async {
    try {
      final probe = _buildDio(baseUrl, fallbackIp);
      final response = await probe.get(
        '/public/events/today',
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
          extra: {'api_recovery_attempted': true},
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pingPublic() async {
    try {
      final r = await dio.get(
        '/public/events/today',
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Uri get _publicBaseUri {
    final normalized = baseUrl.endsWith('/api')
        ? baseUrl.substring(0, baseUrl.length - 4)
        : baseUrl;
    return Uri.parse(normalized);
  }

  String publicQrUrl(String token) {
    final base = _publicBaseUri;
    final basePath = base.path == '/' ? '' : base.path;
    final path = '$basePath/api/public/events/qr/$token';
    return base.replace(path: path).toString();
  }

  String _normalizeExternalUrl(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme) return url;
    final isLocalHost =
        parsed.host == '127.0.0.1' || parsed.host == 'localhost';
    if (!isLocalHost) return url;

    final scheme = _publicBaseUri.scheme.isNotEmpty
        ? _publicBaseUri.scheme
        : parsed.scheme;
    final host = _publicBaseUri.host;
    final port = _publicBaseUri.hasPort ? _publicBaseUri.port : parsed.port;
    return parsed.replace(scheme: scheme, host: host, port: port).toString();
  }

  Future<List<EventItem>> todayEvents() async {
    final r = await dio.get('/public/events/today');
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final list = (r.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(EventItem.fromJson).toList();
  }

  Future<GuestSession> enterEvent(int id, String pin) async {
    final r = await dio.post('/public/events/$id/enter', data: {'pin': pin});
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return GuestSession.fromJson(r.data);
  }

  Future<GuestSession> enterEventByPin(String pin) async {
    final r = await dio.post('/public/events/pin', data: {'pin': pin});
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return GuestSession.fromJson(r.data);
  }

  Future<GuestSession> enterEventByQr(String token) async {
    final clean = extractQrToken(token);
    final r = await dio.get('/public/events/qr/$clean');
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return GuestSession.fromJson(r.data);
  }

  Future<PhotosPage> eventPhotosPage(
    int eventId,
    String token, {
    String search = '',
    int page = 1,
    int perPage = 50,
  }) async {
    final r = await dio.get(
      '/public/events/$eventId/photos',
      queryParameters: {'search': search, 'page': page, 'per_page': perPage},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final data = (r.data['data'] as List).cast<Map<String, dynamic>>();
    final items = data.map((json) {
      final map = Map<String, dynamic>.from(json);
      final preview = map['preview_url'] as String?;
      if (preview != null && preview.isNotEmpty) {
        map['preview_url'] = _normalizeExternalUrl(preview);
      }
      return PhotoItem.fromJson(map);
    }).toList();
    return PhotosPage(
      items: items,
      total: (r.data['total'] as num?)?.toInt() ?? items.length,
      currentPage: (r.data['current_page'] as num?)?.toInt() ?? page,
      lastPage: (r.data['last_page'] as num?)?.toInt() ?? 1,
      perPage: (r.data['per_page'] as num?)?.toInt() ?? perPage,
    );
  }

  Future<List<PhotoItem>> faceSearch(
    int eventId,
    String token,
    String selfiePath,
  ) async {
    final form = FormData.fromMap({
      'selfie': await MultipartFile.fromFile(
        selfiePath,
        filename: 'selfie.jpg',
      ),
    });
    final r = await dio.post(
      '/public/events/$eventId/face-search',
      data: form,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        contentType: 'multipart/form-data',
        receiveTimeout: const Duration(minutes: 5),
        sendTimeout: const Duration(minutes: 5),
      ),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final list = (r.data['suggested'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    return list.map((json) {
      final map = Map<String, dynamic>.from(json);
      final preview = map['preview_url'] as String?;
      if (preview != null && preview.isNotEmpty) {
        map['preview_url'] = _normalizeExternalUrl(preview);
      }
      return PhotoItem.fromJson(map);
    }).toList();
  }

  Future<StripeIntentPayload> createStripeIntent({
    required int eventId,
    required String token,
    required String customerName,
    required String phone,
    required String email,
    required List<CartItemPayload> photoItems,
    required String productType,
    required String? deliveryType,
    required String deliveryAddress,
    required bool wantsFilm,
    double processingFee = 0.0,
  }) async {
    final payload = {
      'event_id': eventId,
      'customer_name': customerName,
      'customer_phone': phone.isEmpty ? null : phone,
      'customer_email': email.isEmpty ? null : email,
      'payment_method': 'online',
      'product_type': productType,
      'delivery_type': deliveryType,
      'delivery_address': deliveryAddress.isEmpty ? null : deliveryAddress,
      'wants_film': wantsFilm,
      'processing_fee': processingFee,
      'photo_items': photoItems
          .map((i) => {'photo_id': i.photoId, 'quantity': i.quantity})
          .toList(),
    };

    final r = await dio.post(
      '/public/orders/stripe-intent',
      data: payload,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 201) throw _errorFromResponse(r);
    return StripeIntentPayload.fromJson(
      (r.data as Map).cast<String, dynamic>(),
    );
  }

  Future<StripeCheckoutPayload> createStripeCheckoutSession({
    required int eventId,
    required String token,
    required String customerName,
    required String phone,
    required String email,
    required List<CartItemPayload> photoItems,
    required String productType,
    required String? deliveryType,
    required String deliveryAddress,
    required bool wantsFilm,
    required String paymentMethodType,
    double processingFee = 0.0,
  }) async {
    final payload = {
      'event_id': eventId,
      'customer_name': customerName,
      'customer_phone': phone.isEmpty ? null : phone,
      'customer_email': email.isEmpty ? null : email,
      'payment_method_type': paymentMethodType,
      'product_type': productType,
      'delivery_type': deliveryType,
      'delivery_address': deliveryAddress.isEmpty ? null : deliveryAddress,
      'wants_film': wantsFilm,
      'processing_fee': processingFee,
      'photo_items': photoItems
          .map((i) => {'photo_id': i.photoId, 'quantity': i.quantity})
          .toList(),
    };

    final r = await dio.post(
      '/public/orders/stripe-checkout',
      data: payload,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 201) throw _errorFromResponse(r);
    return StripeCheckoutPayload.fromJson(
      (r.data as Map).cast<String, dynamic>(),
    );
  }

  Future<void> logClientIssue({
    required String token,
    required String message,
    Map<String, dynamic>? context,
  }) async {
    try {
      await dio.post(
        '/public/logs',
        data: {'message': message, 'context': context ?? {}},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {
      // Best-effort logging only.
    }
  }

  Future<String> createOrder({
    required int eventId,
    required String token,
    required String customerName,
    required String phone,
    required String email,
    required String paymentMethod,
    required List<CartItemPayload> photoItems,
    required num pricePerPhoto,
    required String productType,
    required String? deliveryType,
    required String deliveryAddress,
    required bool wantsFilm,
  }) async {
    final itemsTotal = photoItems.fold<num>(
      0,
      (sum, item) => sum + (item.quantity * pricePerPhoto),
    );
    final shippingFee = deliveryType == 'shipping' ? 5.0 : 0.0;
    final filmFee = wantsFilm ? 30.0 : 0.0;
    final extrasTotal = shippingFee + filmFee;
    final totalAmount = itemsTotal + extrasTotal;
    final payload = {
      'event_id': eventId,
      'customer_name': customerName,
      'customer_phone': phone.isEmpty ? null : phone,
      'customer_email': email.isEmpty ? null : email,
      'payment_method': paymentMethod,
      'product_type': productType,
      'delivery_type': deliveryType,
      'delivery_address': deliveryAddress.isEmpty ? null : deliveryAddress,
      'wants_film': wantsFilm,
      'photo_items': photoItems
          .map((i) => {'photo_id': i.photoId, 'quantity': i.quantity})
          .toList(),
    };
    try {
      final r = await dio.post(
        '/public/orders',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (r.statusCode != 201) throw _errorFromResponse(r);
      return r.data['order_code'] as String;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.error is SocketException) {
        if (paymentMethod == 'online') {
          throw Exception('Sem internet para pagamento online.');
        }
        final localCode = 'OFF-${DateTime.now().millisecondsSinceEpoch}';
        await enqueueOfflineOrder(eventId, {
          'order_code': localCode,
          'customer_name': customerName,
          'customer_phone': phone.isEmpty ? null : phone,
          'customer_email': email.isEmpty ? null : email,
          'product_type': productType,
          'delivery_type': deliveryType,
          'delivery_address': deliveryAddress.isEmpty ? null : deliveryAddress,
          'wants_film': wantsFilm,
          'film_fee': filmFee,
          'shipping_fee': shippingFee,
          'extras_total': extrasTotal.toStringAsFixed(2),
          'items_total': itemsTotal.toStringAsFixed(2),
          'payment_method': paymentMethod,
          'status': 'paid',
          'total_amount': totalAmount.toStringAsFixed(2),
          'items': photoItems
              .map(
                (i) => {
                  'photo_id': i.photoId,
                  'price': pricePerPhoto,
                  'quantity': i.quantity,
                },
              )
              .toList(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        return localCode;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> offlineExportJson(
    String token,
    int eventId,
  ) async {
    final r = await dio.get(
      '/offline/events/$eventId/export',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<void> offlineImportFile(
    String token,
    int eventId,
    String filePath,
    String deviceId, {
    List<String> photoPaths = const [],
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final formPayload = <String, dynamic>{
      'device_id': deviceId,
      'payload': await MultipartFile.fromFile(
        filePath,
        filename: path.basename(filePath),
      ),
    };
    if (photoPaths.isNotEmpty) {
      formPayload['photos'] = [
        for (final photoPath in photoPaths)
          await MultipartFile.fromFile(
            photoPath,
            filename: path.basename(photoPath),
          ),
      ];
    }
    final form = FormData.fromMap(formPayload);
    final r = await dio.post(
      '/offline/events/$eventId/import',
      data: form,
      onSendProgress: onSendProgress,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 10),
      ),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
  }

  Future<void> offlineImportPhotoBatch(
    String token,
    int eventId,
    List<String> photoPaths, {
    List<dynamic> photosMeta = const [],
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final form = FormData();
    for (final photoPath in photoPaths) {
      form.files.add(
        MapEntry(
          'photos[]',
          await MultipartFile.fromFile(
            photoPath,
            filename: path.basename(photoPath),
          ),
        ),
      );
    }
    if (photosMeta.isNotEmpty) {
      form.fields.add(MapEntry('photos_meta', jsonEncode(photosMeta)));
    }
    final r = await dio.post(
      '/offline/events/$eventId/import-photos',
      data: form,
      onSendProgress: onSendProgress,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 10),
      ),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
  }

  Future<OrderDetail> orderDetail(String code) async {
    final r = await dio.get('/public/orders/$code');
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return OrderDetail.fromJson(r.data);
  }

  Future<String> orderDownloadLink({
    required String orderCode,
    required int photoId,
  }) async {
    final r = await dio.post(
      '/public/orders/$orderCode/download-link',
      data: {'photo_id': photoId},
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final rawUrl = r.data['download_url'] as String?;
    if (rawUrl == null || rawUrl.isEmpty) {
      throw 'Resposta sem URL de download';
    }
    return _normalizeExternalUrl(rawUrl);
  }

  Future<StaffAuthResponse> staffLogin(String login, String password) async {
    final r = await dio.post(
      '/auth/login',
      data: {'login': login, 'password': password},
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return StaffAuthResponse.fromJson(r.data as Map<String, dynamic>);
  }

  Future<StaffUser> updateProfile(
    String token, {
    required String name,
    required String email,
    String? username,
    String? password,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'email': email,
      if (username != null && username.isNotEmpty) 'username': username,
      if (password != null && password.isNotEmpty) 'password': password,
    };
    final r = await dio.put(
      '/auth/me',
      data: data,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return StaffUser.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<List<StaffOrderItem>> staffOrders(
    String token,
    int eventId,
    String q,
    String status,
  ) async {
    final r = await dio.get(
      '/events/$eventId/orders',
      queryParameters: {'q': q, if (status.isNotEmpty) 'status': status},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final list = (r.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(StaffOrderItem.fromJson).toList();
  }

  Future<bool> markOrderPaid(
    String token,
    int orderId, {
    int? eventId,
    num? cashReceivedAmount,
    num? cashChangeAmount,
    bool? cashChangeGiven,
    num? cashDueAmount,
    String? notes,
  }) async {
    try {
      final r = await dio.post(
        '/orders/$orderId/mark-paid',
        data: {
          'cash_received_amount': cashReceivedAmount,
          'cash_change_amount': cashChangeAmount,
          'cash_change_given': cashChangeGiven,
          'cash_due_amount': cashDueAmount,
          'notes': notes,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (r.statusCode != 200) throw _errorFromResponse(r);
      if (r.data is Map<String, dynamic>) {
        return r.data['download_link_emailed'] == true;
      }
      return false;
    } on DioException catch (e) {
      if (eventId != null &&
          (e.type == DioExceptionType.connectionError ||
              e.error is SocketException)) {
        await enqueueOrderUpdate(
          eventId,
          orderId,
          'paid',
          cashReceivedAmount: cashReceivedAmount,
          cashChangeAmount: cashChangeAmount,
          cashChangeGiven: cashChangeGiven,
          cashDueAmount: cashDueAmount,
          notes: notes,
        );
        return false;
      }
      rethrow;
    }
  }

  Future<void> markOrderDelivered(
    String token,
    int orderId, {
    int? eventId,
  }) async {
    try {
      final r = await dio.post(
        '/orders/$orderId/mark-delivered',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (r.statusCode != 200) throw _errorFromResponse(r);
    } on DioException catch (e) {
      if (eventId != null &&
          (e.type == DioExceptionType.connectionError ||
              e.error is SocketException)) {
        await enqueueOrderUpdate(eventId, orderId, 'delivered');
        return;
      }
      rethrow;
    }
  }

  Future<List<StaffEvent>> staffEvents(
    String token, {
    String? eventType,
    bool assignedOnly = false,
    String? eventDate,
    String? fromDate,
    String? q,
  }) async {
    final params = <String, dynamic>{};
    final type = eventType?.trim() ?? '';
    if (type.isNotEmpty) params['event_type'] = type;
    if (assignedOnly) params['assigned_only'] = 1;
    if (eventDate != null && eventDate.isNotEmpty) params['event_date'] = eventDate;
    if (fromDate != null && fromDate.isNotEmpty) params['from_date'] = fromDate;
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
    params['per_page'] = 200;
    var page = 1;
    var lastPage = 1;
    final events = <StaffEvent>[];
    do {
      params['page'] = page;
      final r = await dio.get(
        '/events',
        queryParameters: params,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (r.statusCode != 200) throw _errorFromResponse(r);
      final data = (r.data['data'] as List).cast<Map<String, dynamic>>();
      events.addAll(data.map(StaffEvent.fromJson));
      lastPage = (r.data['last_page'] as num?)?.toInt() ?? 1;
      page = (r.data['current_page'] as num?)?.toInt() ?? page;
      page += 1;
    } while (page <= lastPage);
    return events;
  }

  Future<void> registerDeviceToken(
    String token,
    String deviceToken,
    String platform, {
    String? deviceId,
  }) async {
    final data = <String, dynamic>{
      'token': deviceToken,
      'platform': platform,
      if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
    };
    final r = await dio.post(
      '/device-tokens',
      data: data,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200 && r.statusCode != 201) throw _errorFromResponse(r);
  }

  Future<String?> staffNextReportNumber(String token) async {
    final r = await dio.get(
      '/events/next-report-number',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final next = r.data['next_report_number'];
    if (next == null) return null;
    return next.toString();
  }

  Future<List<StaffServiceTemplate>> staffServiceTemplates(String token) async {
    final r = await dio.get(
      '/events/service-templates',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final list = ((r.data['data'] as List?) ?? const []);
    return list
        .map(
          (item) => StaffServiceTemplate.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<Uint8List> staffEventPdf(String token, int eventId) async {
    final r = await dio.get(
      '/events/$eventId/pdf',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.bytes,
      ),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    if (r.data is Uint8List) return r.data as Uint8List;
    return Uint8List.fromList((r.data as List).cast<int>());
  }

  Future<List<StaffEventStaff>> staffEventStaff(
    String token,
    int eventId,
  ) async {
    final r = await dio.get(
      '/events/$eventId/staff',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final list = (r.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(StaffEventStaff.fromJson).toList();
  }

  Future<List<StaffUser>> staffAssignableUsers(
    String token,
    int eventId,
  ) async {
    final r = await dio.get(
      '/events/$eventId/staff/users',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final list = (r.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(StaffUser.fromJson).toList();
  }

  Future<void> staffAssignEventStaff(
    String token,
    int eventId,
    List<int> userIds, {
    required String role,
    required bool sendInvite,
    required String channel,
    String? message,
  }) async {
    final r = await dio.post(
      '/events/$eventId/staff',
      data: {
        'user_ids': userIds,
        'role': role,
        'send_invite': sendInvite,
        'channel': channel,
        'message': message?.trim().isEmpty == true ? null : message,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 201) throw _errorFromResponse(r);
  }

  Future<void> staffRemoveEventStaff(
    String token,
    int eventId,
    int userId,
  ) async {
    final r = await dio.delete(
      '/events/$eventId/staff/$userId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
  }

  Future<StaffEvent> createEvent(
    String token,
    StaffEventPayload payload,
  ) async {
    final r = await dio.post(
      '/events',
      data: payload.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 201) throw _errorFromResponse(r);
    return StaffEvent.fromJson(r.data as Map<String, dynamic>);
  }

  Future<StaffEvent> updateEvent(
    String token,
    int eventId,
    StaffEventPayload payload,
  ) async {
    final r = await dio.put(
      '/events/$eventId',
      data: payload.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return StaffEvent.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deleteEvent(String token, int eventId) async {
    final r = await dio.delete(
      '/events/$eventId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
  }

  Future<List<StaffPhoto>> staffEventPhotos(
    String token,
    int eventId,
    String search,
  ) async {
    final r = await dio.get(
      '/events/$eventId/photos',
      queryParameters: {'search': search},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final list = (r.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map((json) {
      final map = Map<String, dynamic>.from(json);
      final preview = map['preview_url'] as String?;
      if (preview != null && preview.isNotEmpty) {
        map['preview_url'] = _normalizeExternalUrl(preview);
      }
      return StaffPhoto.fromJson(map);
    }).toList();
  }

  Future<int> staffEventPhotosTotal(
    String token,
    int eventId, {
    String search = '',
  }) async {
    final r = await dio.get(
      '/events/$eventId/photos',
      queryParameters: {'search': search},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return (r.data['total'] as num?)?.toInt() ??
        ((r.data['data'] as List?)?.length ?? 0);
  }

  Future<void> staffDeletePhoto(String token, int eventId, int photoId) async {
    final r = await dio.delete(
      '/events/$eventId/photos/$photoId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
  }

  Future<int> staffBulkDeletePhotos(
    String token,
    int eventId,
    List<int> photoIds,
  ) async {
    final r = await dio.post(
      '/events/$eventId/photos/bulk-delete',
      data: {'photo_ids': photoIds},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    if (r.data is Map<String, dynamic>) {
      return (r.data['deleted'] as int?) ?? 0;
    }
    return 0;
  }

  Future<void> staffRetryPreview(String token, int eventId, int photoId) async {
    final r = await dio.post(
      '/events/$eventId/photos/$photoId/retry-preview',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
  }

  Future<UploadStatus> staffUploadStatus(
    String token,
    int eventId,
    String uploadId,
  ) async {
    final r = await dio.get(
      '/events/$eventId/uploads/status',
      queryParameters: {'upload_id': uploadId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return UploadStatus.fromJson(r.data as Map<String, dynamic>);
  }

  Future<UploadChunkResult> staffUploadChunk({
    required String token,
    required int eventId,
    required String uploadId,
    required int chunkIndex,
    required int totalChunks,
    required String fileName,
    required Uint8List chunkBytes,
  }) async {
    final form = FormData.fromMap({
      'upload_id': uploadId,
      'chunk_index': chunkIndex,
      'total_chunks': totalChunks,
      'file_name': fileName,
      'chunk': MultipartFile.fromBytes(chunkBytes, filename: fileName),
    });
    final r = await dio.post(
      '/events/$eventId/uploads/chunk',
      data: form,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        contentType: 'multipart/form-data',
        receiveTimeout: const Duration(minutes: 5),
        sendTimeout: const Duration(minutes: 5),
      ),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return UploadChunkResult.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<OrderListItem>> staffOrdersList(
    String token, {
    int? eventId,
    List<int>? eventIds,
    String eventDate = '',
    String eventType = '',
    String status = '',
    String q = '',
  }) async {
    final params = <String, dynamic>{};
    if (q.isNotEmpty) params['q'] = q;
    if (status.isNotEmpty) params['status'] = status;
    if (eventId != null) params['event_id'] = eventId;
    if (eventIds != null && eventIds.isNotEmpty)
      params['event_ids'] = eventIds.join(',');
    if (eventDate.isNotEmpty) params['event_date'] = eventDate;
    if (eventType.isNotEmpty) params['event_type'] = eventType;
    final r = await dio.get(
      '/orders',
      queryParameters: params,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final list = (r.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(OrderListItem.fromJson).toList();
  }

  Future<int> staffOrdersTotal(
    String token, {
    int? eventId,
    String status = '',
  }) async {
    final params = <String, dynamic>{};
    if (status.isNotEmpty) params['status'] = status;
    if (eventId != null) params['event_id'] = eventId;
    final r = await dio.get(
      '/orders',
      queryParameters: params,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return (r.data['total'] as num?)?.toInt() ??
        ((r.data['data'] as List?)?.length ?? 0);
  }

  Future<StaffOrderDetail> staffOrderDetail(String token, int orderId) async {
    final r = await dio.get(
      '/orders/$orderId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return StaffOrderDetail.fromJson(r.data as Map<String, dynamic>);
  }

  Future<StaffOrderDetail> updateOrder(
    String token,
    int orderId,
    StaffOrderUpdatePayload payload,
  ) async {
    final r = await dio.put(
      '/orders/$orderId',
      data: payload.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return StaffOrderDetail.fromJson(r.data as Map<String, dynamic>);
  }

  Future<int> staffBulkOrderStatus(
    String token,
    List<int> orderIds,
    String status,
  ) async {
    final r = await dio.post(
      '/orders/bulk-status',
      data: {'order_ids': orderIds, 'status': status},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return (r.data['updated'] as int?) ?? 0;
  }

  Future<bool> staffSendDownloadLink(String token, int orderId) async {
    final r = await dio.post(
      '/orders/$orderId/send-download-link',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    if (r.data is Map<String, dynamic>) {
      return r.data['sent'] == true;
    }
    return false;
  }

  Future<String> staffDownloadAll(String token, int orderId) async {
    final tempDir = await getTemporaryDirectory();
    final savePath = '${tempDir.path}/order-$orderId.zip';
    final r = await dio.download(
      '/orders/$orderId/download-all',
      savePath,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return savePath;
  }

  Future<String> staffExportOrdersCsv(String token, int eventId) async {
    final tempDir = await getTemporaryDirectory();
    final savePath = '${tempDir.path}/orders-event-$eventId.csv';
    final r = await dio.download(
      '/events/$eventId/orders/export',
      savePath,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return savePath;
  }

  Future<String> staffExportOrdersTxt(String token, int eventId) async {
    final tempDir = await getTemporaryDirectory();
    final savePath = '${tempDir.path}/orders-event-$eventId.txt';
    final r = await dio.download(
      '/events/$eventId/orders/export-txt',
      savePath,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return savePath;
  }

  Future<String> staffExportOrdersPdf(String token, int eventId) async {
    final tempDir = await getTemporaryDirectory();
    final savePath =
        '${tempDir.path}/pedidos-evento-$eventId-${DateTime.now().microsecondsSinceEpoch}.pdf';
    final r = await dio.download(
      '/events/$eventId/orders/export-orders-pdf',
      savePath,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return savePath;
  }

  Future<String> staffExportSalesPdf(
    String token,
    int eventId, {
    double commissionRate = 15.0,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final savePath =
        '${tempDir.path}/vendas-evento-$eventId-${DateTime.now().microsecondsSinceEpoch}.pdf';
    final r = await dio.download(
      '/events/$eventId/orders/export-sales-pdf',
      savePath,
      queryParameters: {'commission_rate': commissionRate},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return savePath;
  }

  Future<List<StaffUser>> staffUsers(String token) async {
    final r = await dio.get(
      '/users',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final list = (r.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(StaffUser.fromJson).toList();
  }

  Future<List<StaffClient>> staffClients(String token, {String q = ''}) async {
    final r = await dio.get(
      '/clients',
      queryParameters: {'q': q},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final list = (r.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(StaffClient.fromJson).toList();
  }

  Future<StaffClient> createClient(
    String token,
    StaffClientPayload payload,
  ) async {
    final r = await dio.post(
      '/clients',
      data: payload.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 201) throw _errorFromResponse(r);
    return StaffClient.fromJson(r.data as Map<String, dynamic>);
  }

  Future<StaffClient> updateClient(
    String token,
    int clientId,
    StaffClientPayload payload,
  ) async {
    final r = await dio.put(
      '/clients/$clientId',
      data: payload.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return StaffClient.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deleteClient(String token, int clientId) async {
    final r = await dio.delete(
      '/clients/$clientId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
  }

  Future<StaffUser> createUser(String token, StaffUserPayload payload) async {
    final r = await dio.post(
      '/users',
      data: payload.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 201) throw _errorFromResponse(r);
    return StaffUser.fromJson(r.data as Map<String, dynamic>);
  }

  Future<StaffUser> updateUser(
    String token,
    int userId,
    StaffUserPayload payload,
  ) async {
    final r = await dio.put(
      '/users/$userId',
      data: payload.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return StaffUser.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deleteUser(String token, int userId) async {
    final r = await dio.delete(
      '/users/$userId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
  }

  String _errorFromResponse(Response<dynamic> r) {
    if (r.statusCode == 302) {
      return 'Sessão inválida ou pedido incompleto. Verifica os dados e tenta novamente.';
    }

    final data = r.data;
    if (data is Map<String, dynamic>) {
      if (data['message'] is String &&
          (data['message'] as String).trim().isNotEmpty) {
        return data['message'] as String;
      }
      if (data['errors'] is Map<String, dynamic>) {
        final errors = data['errors'] as Map<String, dynamic>;
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }
        }
      }
    }

    return 'Erro ${r.statusCode ?? 'desconhecido'}';
  }
}

class EventItem {
  EventItem({
    required this.id,
    required this.name,
    required this.eventDate,
    this.location,
  });
  final int id;
  final String name;
  final String eventDate;
  final String? location;

  factory EventItem.fromJson(Map<String, dynamic> j) => EventItem(
    id: j['id'] as int,
    name: j['name'] as String,
    eventDate: j['event_date'] as String,
    location: j['location'] as String?,
  );
}

class GuestSession {
  GuestSession({
    required this.token,
    required this.eventId,
    required this.eventName,
    this.basePrice,
    required this.pricePerPhoto,
    required this.eventType,
    required this.eventMeta,
    required this.eventDate,
    required this.location,
    required this.qrToken,
    required this.offlineMode,
  });
  final String token;
  final int eventId;
  final String eventName;
  final num? basePrice;
  final num pricePerPhoto;
  final String? eventType;
  final Map<String, dynamic> eventMeta;
  final String? eventDate;
  final String? location;
  final String? qrToken;
  final bool offlineMode;

  factory GuestSession.fromJson(Map<String, dynamic> j) {
    final e = j['event'] as Map<String, dynamic>;
    return GuestSession(
      token: j['event_session_token'] as String,
      eventId: e['id'] as int,
      eventName: e['name'] as String,
      basePrice: e['base_price'] == null
          ? null
          : (e['base_price'] is num
                ? e['base_price'] as num
                : num.tryParse(e['base_price'].toString())),
      pricePerPhoto: e['price_per_photo'] is num
          ? e['price_per_photo'] as num
          : num.tryParse(e['price_per_photo']?.toString() ?? '') ?? 0,
      eventType: e['event_type'] as String?,
      eventMeta: e['event_meta'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(e['event_meta'])
          : <String, dynamic>{},
      eventDate: e['event_date'] as String?,
      location: e['location'] as String?,
      qrToken: e['qr_token'] as String?,
      offlineMode: j['offline_mode'] == true || j['offline_mode'] == 1,
    );
  }
}

class PhotoItem {
  PhotoItem({required this.id, required this.number, this.previewUrl});
  final int id;
  final String number;
  final String? previewUrl;

  factory PhotoItem.fromJson(Map<String, dynamic> j) => PhotoItem(
    id: j['id'] as int,
    number: j['number'] as String,
    previewUrl: j['preview_url'] as String?,
  );
}

class PhotosPage {
  PhotosPage({
    required this.items,
    required this.total,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
  });
  final List<PhotoItem> items;
  final int total;
  final int currentPage;
  final int lastPage;
  final int perPage;
}

class OrderDetail {
  OrderDetail({
    required this.orderCode,
    required this.customerName,
    required this.paymentMethod,
    required this.status,
    required this.totalAmount,
    required this.photos,
    required this.itemsTotal,
    required this.extrasTotal,
    required this.shippingFee,
    required this.filmFee,
    required this.productType,
    required this.deliveryType,
    required this.deliveryAddress,
    required this.wantsFilm,
    required this.cashReceivedAmount,
    required this.cashChangeAmount,
    required this.cashChangeGiven,
    required this.cashDueAmount,
    required this.isOffline,
  });
  final String orderCode;
  final String customerName;
  final String paymentMethod;
  final String status;
  final num totalAmount;
  final List<OrderPhoto> photos;
  final num itemsTotal;
  final num extrasTotal;
  final num shippingFee;
  final num filmFee;
  final String? productType;
  final String? deliveryType;
  final String? deliveryAddress;
  final bool wantsFilm;
  final num? cashReceivedAmount;
  final num? cashChangeAmount;
  final bool cashChangeGiven;
  final num? cashDueAmount;
  final bool isOffline;

  factory OrderDetail.fromJson(Map<String, dynamic> j) => OrderDetail(
    orderCode: j['order_code'] as String? ?? '',
    customerName: j['customer_name'] as String? ?? '',
    paymentMethod: j['payment_method'] as String? ?? '',
    status: j['status'] as String,
    totalAmount: _toNum(j['total_amount']),
    photos: ((j['photos'] as List).cast<Map<String, dynamic>>())
        .map(OrderPhoto.fromJson)
        .toList(),
    itemsTotal: _toNum(j['items_total']),
    extrasTotal: _toNum(j['extras_total']),
    shippingFee: _toNum(j['shipping_fee']),
    filmFee: _toNum(j['film_fee']),
    productType: j['product_type'] as String?,
    deliveryType: j['delivery_type'] as String?,
    deliveryAddress: j['delivery_address'] as String?,
    wantsFilm: j['wants_film'] == true || j['wants_film'] == 1,
    cashReceivedAmount: _toNullableNum(j['cash_received_amount']),
    cashChangeAmount: _toNullableNum(j['cash_change_amount']),
    cashChangeGiven:
        j['cash_change_given'] == true || j['cash_change_given'] == 1,
    cashDueAmount: _toNullableNum(j['cash_due_amount']),
    isOffline: j['offline_mode'] == true || j['offline_mode'] == 1,
  );

  static num _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  static num? _toNullableNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }
}

class OrderPhoto {
  OrderPhoto({required this.id, required this.number, required this.quantity});
  final int id;
  final String number;
  final int quantity;

  factory OrderPhoto.fromJson(Map<String, dynamic> j) => OrderPhoto(
    id: j['id'] as int,
    number: j['number'] as String,
    quantity: j['quantity'] is int
        ? j['quantity'] as int
        : int.tryParse(j['quantity']?.toString() ?? '1') ?? 1,
  );
}

class StaffOrderItem {
  StaffOrderItem({
    required this.id,
    required this.orderCode,
    required this.customerName,
    required this.status,
  });
  final int id;
  final String orderCode;
  final String customerName;
  final String status;

  factory StaffOrderItem.fromJson(Map<String, dynamic> j) => StaffOrderItem(
    id: j['id'] as int,
    orderCode: j['order_code'] as String,
    customerName: j['customer_name'] as String,
    status: j['status'] as String,
  );
}

class StaffAuthResponse {
  StaffAuthResponse({required this.token, required this.user});
  final String token;
  final StaffUser user;

  factory StaffAuthResponse.fromJson(Map<String, dynamic> j) =>
      StaffAuthResponse(
        token: j['token'] as String,
        user: StaffUser.fromJson((j['user'] as Map).cast<String, dynamic>()),
      );
}

class StaffUser {
  StaffUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.permissions,
    this.username,
  });
  final int id;
  final String name;
  final String email;
  final String role;
  final List<String> permissions;
  final String? username;

  factory StaffUser.fromJson(Map<String, dynamic> j) {
    final rawRole = j['role'] as String? ?? 'photographer';
    return StaffUser(
      id: j['id'] as int,
      name: j['name'] as String? ?? '',
      email: j['email'] as String? ?? '',
      role: _normalizeRole(rawRole),
      permissions: ((j['permissions'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      username: j['username'] as String?,
    );
  }

  bool hasPermission(String permission) {
    final normalizedRole = _normalizeRole(role);
    if (normalizedRole == 'admin') return true;

    const legacyMap = {
      'events.list': ['events.read', 'events.calendar'],
      'events.view': ['events.read'],
      'events.create': ['events.write'],
      'events.update': ['events.write'],
      'events.delete': ['events.write'],
      'uploads.list': ['uploads.manage'],
      'uploads.create': ['uploads.manage'],
      'photos.list': ['photos.manage'],
      'photos.update': ['photos.manage'],
      'photos.delete': ['photos.manage'],
      'photos.bulk_delete': ['photos.manage'],
      'photos.original': ['photos.manage'],
      'orders.list': ['orders.read'],
      'orders.view': ['orders.read'],
      'orders.update': ['orders.write'],
      'orders.bulk': ['orders.write'],
      'orders.download': ['orders.download'],
      'orders.export': ['orders.export'],
      'users.list': ['users.manage'],
      'users.view': ['users.manage'],
      'users.create': ['users.manage'],
      'users.update': ['users.manage'],
      'users.delete': ['users.manage'],
      'clients.list': ['clients.read'],
      'clients.view': ['clients.read'],
      'clients.create': ['clients.write'],
      'clients.update': ['clients.write'],
      'clients.delete': ['clients.write'],
      'offline.export': ['events.read'],
      'offline.import': ['events.write'],
    };

    if (permissions.contains(permission)) return true;
    for (final legacy in legacyMap[permission] ?? const <String>[]) {
      if (permissions.contains(legacy)) return true;
    }

    if (normalizedRole == 'photographer') {
      const allowed = {
        'dashboard.view',
        'events.list',
        'events.view',
        'events.pricing.view',
        'events.internal.view',
        'uploads.list',
        'uploads.create',
        'orders.list',
        'orders.view',
        'orders.update',
      };
      return allowed.contains(permission);
    }

    return false;
  }
}

bool _canViewEventPricing(StaffUser? user) =>
    user?.hasPermission('events.pricing.view') ?? false;

bool _canViewEventInternal(StaffUser? user) =>
    user?.hasPermission('events.internal.view') ?? false;

class StaffUserPayload {
  StaffUserPayload({
    required this.name,
    required this.email,
    required this.role,
    required this.permissions,
    this.username,
    this.password,
  });
  final String name;
  final String email;
  final String role;
  final List<String> permissions;
  final String? username;
  final String? password;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (username != null && username!.isNotEmpty) 'username': username,
    'email': email,
    'role': role,
    if (password != null && password!.isNotEmpty) 'password': password,
    'permissions': permissions,
  };
}

class StaffClient {
  StaffClient({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.notes,
    this.marketingConsent = false,
  });
  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final bool marketingConsent;

  factory StaffClient.fromJson(Map<String, dynamic> j) => StaffClient(
    id: j['id'] as int,
    name: j['name'] as String? ?? '',
    phone: j['phone'] as String?,
    email: j['email'] as String?,
    notes: j['notes'] as String?,
    marketingConsent:
        j['marketing_consent'] == true || j['marketing_consent'] == 1,
  );
}

class StaffClientPayload {
  StaffClientPayload({
    required this.name,
    this.phone,
    this.email,
    this.notes,
    this.marketingConsent = false,
  });
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final bool marketingConsent;

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone?.trim().isEmpty == true ? null : phone,
    'email': email?.trim().isEmpty == true ? null : email,
    'notes': notes?.trim().isEmpty == true ? null : notes,
    'marketing_consent': marketingConsent,
  };
}

class StaffEvent {
  StaffEvent({
    required this.id,
    required this.name,
    this.legacyReportNumber,
    this.reportNumber,
    required this.eventDate,
    this.eventTime,
    required this.pricePerPhoto,
    this.basePrice,
    required this.isActiveToday,
    this.location,
    this.city,
    this.address,
    this.address2,
    this.deliveryDate,
    this.guestCount,
    this.eventType,
    this.eventMeta,
    this.qrToken,
    this.accessPin,
    this.notes,
    this.isLocked = false,
  });
  final int id;
  final String name;
  final String? legacyReportNumber;
  final String? reportNumber;
  final String eventDate;
  final String? eventTime;
  final num pricePerPhoto;
  final num? basePrice;
  final bool isActiveToday;
  final String? location;
  final String? city;
  final String? address;
  final String? address2;
  final String? deliveryDate;
  final int? guestCount;
  final String? eventType;
  final Map<String, dynamic>? eventMeta;
  final String? qrToken;
  final String? accessPin;
  final String? notes;
  final bool isLocked;

  factory StaffEvent.fromJson(Map<String, dynamic> j) => StaffEvent(
    id: j['id'] as int,
    name: j['name'] as String? ?? '',
    legacyReportNumber: j['legacy_report_number']?.toString(),
    reportNumber: j['report_number']?.toString(),
    eventDate: j['event_date'] as String? ?? '',
    eventTime: j['event_time'] as String?,
    pricePerPhoto: j['price_per_photo'] is num
        ? j['price_per_photo'] as num
        : num.tryParse(j['price_per_photo']?.toString() ?? '') ?? 0,
    basePrice: j['base_price'] == null
        ? null
        : (j['base_price'] is num
              ? j['base_price'] as num
              : num.tryParse(j['base_price'].toString())),
    isActiveToday: j['is_active_today'] == true || j['is_active_today'] == 1,
    location: j['location'] as String?,
    city: j['city'] as String?,
    address: j['address'] as String?,
    address2: j['address2'] as String?,
    deliveryDate: j['delivery_date'] as String?,
    guestCount: (j['guest_count'] as num?)?.toInt(),
    eventType: j['event_type'] as String?,
    eventMeta: j['event_meta'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(j['event_meta'])
        : null,
    qrToken: j['qr_token'] as String?,
    accessPin: j['access_pin'] as String?,
    notes: j['notes'] as String?,
    isLocked: j['is_locked'] == true || j['is_locked'] == 1,
  );
}

class StaffEventStaff {
  StaffEventStaff({
    required this.id,
    required this.role,
    required this.status,
    required this.user,
  });
  final int id;
  final String role;
  final String status;
  final StaffUser user;

  factory StaffEventStaff.fromJson(Map<String, dynamic> j) => StaffEventStaff(
    id: j['id'] as int,
    role: j['role'] as String? ?? 'photographer',
    status: j['status'] as String? ?? 'invited',
    user: StaffUser.fromJson((j['user'] as Map).cast<String, dynamic>()),
  );
}

class StaffEventPayload {
  StaffEventPayload({
    this.name,
    this.legacyReportNumber,
    required this.eventDate,
    required this.eventTime,
    required this.pricePerPhoto,
    this.basePrice,
    required this.eventType,
    this.location,
    this.city,
    this.address,
    this.address2,
    this.deliveryDate,
    this.guestCount,
    required this.eventMeta,
    required this.notes,
    required this.isLocked,
  });
  final String? name;
  final String? legacyReportNumber;
  final String eventDate;
  final String eventTime;
  final num pricePerPhoto;
  final num? basePrice;
  final String eventType;
  final String? location;
  final String? city;
  final String? address;
  final String? address2;
  final String? deliveryDate;
  final int? guestCount;
  final Map<String, dynamic> eventMeta;
  final String notes;
  final bool isLocked;

  Map<String, dynamic> toJson() => {
    if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
    if (legacyReportNumber != null && legacyReportNumber!.trim().isNotEmpty)
      'legacy_report_number': legacyReportNumber!.trim(),
    'event_date': eventDate,
    if (eventTime.trim().isNotEmpty) 'event_time': eventTime.trim(),
    'price_per_photo': pricePerPhoto,
    if (basePrice != null) 'base_price': basePrice,
    'event_type': eventType.isEmpty ? null : eventType,
    if (location != null && location!.trim().isNotEmpty) 'location': location!.trim(),
    if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
    if (address != null && address!.trim().isNotEmpty) 'address': address!.trim(),
    if (address2 != null && address2!.trim().isNotEmpty) 'address2': address2!.trim(),
    if (deliveryDate != null && deliveryDate!.trim().isNotEmpty) 'delivery_date': deliveryDate!.trim(),
    if (guestCount != null) 'guest_count': guestCount,
    'event_meta': eventMeta,
    if (notes.trim().isNotEmpty) 'notes': notes.trim(),
    if (isLocked) 'is_locked': true,
  };
}

class StaffServiceTemplate {
  StaffServiceTemplate({
    required this.id,
    required this.slug,
    required this.name,
    required this.fields,
    this.description,
    this.sortOrder = 0,
    this.settings = const {},
  });

  final int id;
  final String slug;
  final String name;
  final String? description;
  final int sortOrder;
  final Map<String, dynamic> settings;
  final List<StaffServiceTemplateField> fields;

  factory StaffServiceTemplate.fromJson(Map<String, dynamic> j) =>
      StaffServiceTemplate(
        id: (j['id'] as num?)?.toInt() ?? 0,
        slug: j['slug']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        description: j['description']?.toString(),
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
        settings: j['settings'] is Map
            ? Map<String, dynamic>.from(j['settings'] as Map)
            : const {},
        fields: ((j['fields'] as List?) ?? const [])
            .map(
              (item) => StaffServiceTemplateField.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );
}

class StaffServiceTemplateField {
  StaffServiceTemplateField({
    required this.key,
    required this.label,
    required this.source,
    required this.section,
    required this.sectionOrder,
    required this.order,
    required this.type,
    required this.width,
    required this.required,
    required this.showInForm,
    required this.showInPdf,
    required this.options,
    this.placeholder,
  });

  final String key;
  final String label;
  final String source;
  final String section;
  final int sectionOrder;
  final int order;
  final String type;
  final String width;
  final bool required;
  final bool showInForm;
  final bool showInPdf;
  final List<String> options;
  final String? placeholder;

  factory StaffServiceTemplateField.fromJson(Map<String, dynamic> j) =>
      StaffServiceTemplateField(
        key: j['key']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        source: j['source']?.toString() == 'event' ? 'event' : 'meta',
        section: j['section']?.toString() ?? 'Ficha',
        sectionOrder: (j['section_order'] as num?)?.toInt() ?? 100,
        order: (j['order'] as num?)?.toInt() ?? 100,
        type: j['type']?.toString() ?? 'text',
        width: j['width']?.toString() ?? 'half',
        required: j['required'] == true || j['required'] == 1,
        showInForm: j['show_in_form'] != false,
        showInPdf: j['show_in_pdf'] != false,
        options: ((j['options'] as List?) ?? const [])
            .map((item) => item.toString())
            .toList(),
        placeholder: j['placeholder']?.toString(),
      );
}

class StaffPhoto {
  StaffPhoto({
    required this.id,
    required this.number,
    this.previewUrl,
    this.previewStatus,
    this.previewError,
  });
  final int id;
  final String number;
  final String? previewUrl;
  final String? previewStatus;
  final String? previewError;

  factory StaffPhoto.fromJson(Map<String, dynamic> j) => StaffPhoto(
    id: j['id'] as int,
    number: j['number'] as String? ?? '',
    previewUrl: j['preview_url'] as String?,
    previewStatus: j['preview_status'] as String?,
    previewError: j['preview_error'] as String?,
  );
}

class UploadStatus {
  UploadStatus({
    required this.exists,
    required this.receivedChunks,
    required this.totalChunks,
    required this.isCompleted,
    this.photoId,
  });
  final bool exists;
  final int receivedChunks;
  final int totalChunks;
  final bool isCompleted;
  final int? photoId;

  factory UploadStatus.fromJson(Map<String, dynamic> j) => UploadStatus(
    exists: j['exists'] == true,
    receivedChunks: (j['received_chunks'] as int?) ?? 0,
    totalChunks: (j['total_chunks'] as int?) ?? 0,
    isCompleted: j['is_completed'] == true,
    photoId: j['photo_id'] as int?,
  );
}

class UploadChunkResult {
  UploadChunkResult({
    required this.uploaded,
    this.receivedChunks,
    this.totalChunks,
    this.photo,
  });
  final bool uploaded;
  final int? receivedChunks;
  final int? totalChunks;
  final StaffPhoto? photo;

  factory UploadChunkResult.fromJson(Map<String, dynamic> j) =>
      UploadChunkResult(
        uploaded: j['uploaded'] == true,
        receivedChunks: j['received_chunks'] as int?,
        totalChunks: j['total_chunks'] as int?,
        photo: j['photo'] is Map<String, dynamic>
            ? StaffPhoto.fromJson((j['photo'] as Map).cast<String, dynamic>())
            : null,
      );
}

class OrderListItem {
  OrderListItem({
    required this.id,
    required this.orderCode,
    required this.customerName,
    required this.status,
    required this.paymentMethod,
    this.eventName,
    this.eventId,
    this.totalAmount,
    this.cashReceivedAmount,
    this.cashChangeAmount,
    this.cashChangeGiven = false,
    this.cashDueAmount,
    this.productType,
  });
  final int id;
  final String orderCode;
  final String customerName;
  final String status;
  final String paymentMethod;
  final String? eventName;
  final int? eventId;
  final num? totalAmount;
  final num? cashReceivedAmount;
  final num? cashChangeAmount;
  final bool cashChangeGiven;
  final num? cashDueAmount;
  final String? productType;

  factory OrderListItem.fromJson(Map<String, dynamic> j) => OrderListItem(
    id: j['id'] as int,
    orderCode: j['order_code'] as String? ?? '',
    customerName: j['customer_name'] as String? ?? '',
    status: j['status'] as String? ?? '',
    paymentMethod: j['payment_method'] as String? ?? '',
    eventName: (j['event'] is Map<String, dynamic>)
        ? (j['event']['name'] as String?)
        : null,
    eventId: (j['event'] is Map<String, dynamic>)
        ? (j['event']['id'] as int?)
        : null,
    totalAmount: j['total_amount'] is num
        ? j['total_amount'] as num
        : num.tryParse(j['total_amount']?.toString() ?? ''),
    cashReceivedAmount: OrderDetail._toNullableNum(j['cash_received_amount']),
    cashChangeAmount: OrderDetail._toNullableNum(j['cash_change_amount']),
    cashChangeGiven:
        j['cash_change_given'] == true || j['cash_change_given'] == 1,
    cashDueAmount: OrderDetail._toNullableNum(j['cash_due_amount']),
    productType: j['product_type'] as String?,
  );
}

class StaffOrderDetail {
  StaffOrderDetail({
    required this.id,
    required this.orderCode,
    required this.customerName,
    required this.status,
    required this.paymentMethod,
    required this.totalAmount,
    required this.photos,
    this.eventName,
    this.customerEmail,
    this.customerPhone,
    this.cashReceivedAmount,
    this.cashChangeAmount,
    this.cashChangeGiven = false,
    this.cashDueAmount,
    this.productType,
    this.deliveryType,
    this.deliveryAddress,
    this.notes,
  });
  final int id;
  final String orderCode;
  final String customerName;
  final String status;
  final String paymentMethod;
  final num totalAmount;
  final List<OrderPhoto> photos;
  final String? eventName;
  final String? customerEmail;
  final String? customerPhone;
  final num? cashReceivedAmount;
  final num? cashChangeAmount;
  final bool cashChangeGiven;
  final num? cashDueAmount;
  final String? productType;
  final String? deliveryType;
  final String? deliveryAddress;
  final String? notes;

  factory StaffOrderDetail.fromJson(Map<String, dynamic> j) => StaffOrderDetail(
    id: j['id'] as int,
    orderCode: j['order_code'] as String? ?? '',
    customerName: j['customer_name'] as String? ?? '',
    status: j['status'] as String? ?? '',
    paymentMethod: j['payment_method'] as String? ?? '',
    totalAmount: j['total_amount'] is num
        ? j['total_amount'] as num
        : num.tryParse(j['total_amount']?.toString() ?? '') ?? 0,
    photos: ((j['photos'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .map(OrderPhoto.fromJson)
        .toList(),
    eventName: (j['event'] is Map<String, dynamic>)
        ? (j['event']['name'] as String?)
        : null,
    customerEmail: j['customer_email'] as String?,
    customerPhone: j['customer_phone'] as String?,
    cashReceivedAmount: OrderDetail._toNullableNum(j['cash_received_amount']),
    cashChangeAmount: OrderDetail._toNullableNum(j['cash_change_amount']),
    cashChangeGiven:
        j['cash_change_given'] == true || j['cash_change_given'] == 1,
    cashDueAmount: OrderDetail._toNullableNum(j['cash_due_amount']),
    productType: j['product_type'] as String?,
    deliveryType: j['delivery_type'] as String?,
    deliveryAddress: j['delivery_address'] as String?,
    notes: j['notes'] as String?,
  );
}

class StaffOrderUpdatePayload {
  StaffOrderUpdatePayload({
    required this.customerName,
    required this.status,
    this.customerEmail,
    this.customerPhone,
    this.paymentMethod,
    this.notes,
    this.cashReceivedAmount,
    this.cashChangeAmount,
    this.cashChangeGiven,
    this.cashDueAmount,
  });
  final String customerName;
  final String status;
  final String? customerEmail;
  final String? customerPhone;
  final String? paymentMethod;
  final String? notes;
  final num? cashReceivedAmount;
  final num? cashChangeAmount;
  final bool? cashChangeGiven;
  final num? cashDueAmount;

  Map<String, dynamic> toJson() => {
    'customer_name': customerName,
    'customer_email': customerEmail,
    'customer_phone': customerPhone,
    'payment_method': paymentMethod,
    'status': status,
    'notes': notes,
    if (cashReceivedAmount != null) 'cash_received_amount': cashReceivedAmount,
    if (cashChangeAmount != null) 'cash_change_amount': cashChangeAmount,
    if (cashChangeGiven != null) 'cash_change_given': cashChangeGiven,
    if (cashDueAmount != null) 'cash_due_amount': cashDueAmount,
  };
}

class StaffSyncPage extends ConsumerStatefulWidget {
  const StaffSyncPage({super.key});

  @override
  ConsumerState<StaffSyncPage> createState() => _StaffSyncPageState();
}

class _StaffSyncPageState extends ConsumerState<StaffSyncPage> {
  @override
  void initState() {
    super.initState();
    saveStaffLastRoute('sync', userId: ref.read(staffUserProvider)?.id);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(staffUserProvider);
    final hasOfflineSession =
        ref.watch(offlineHostSessionProvider)?.isActive == true;
    if (user != null &&
        !user.hasPermission('offline.import') &&
        !hasOfflineSession) {
      return Scaffold(
        appBar: buildNavAppBar(context, 'Sincronizar'),
        body: const Center(child: Text('Sem acesso.')),
      );
    }
    final token = ref.watch(staffTokenProvider);
    if (user != null && token != null && useDesktopLayout(context)) {
      return StaffDesktopShell(user: user, token: token, initialId: 'sync');
    }

    return Scaffold(
      appBar: buildNavAppBar(context, 'Sincronizar'),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: OfflineSyncPanel(),
      ),
    );
  }
}

class OfflineSyncPanel extends ConsumerStatefulWidget {
  const OfflineSyncPanel({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<OfflineSyncPanel> createState() => _OfflineSyncPanelState();
}

class _OfflineSyncPanelState extends ConsumerState<OfflineSyncPanel> {
  static const int _photoBatchSize = 24;
  static const int _parallelPhotoUploads = 6;
  static const int _maxPhotoBatchBytes = 32 * 1024 * 1024;

  List<StaffEvent> _events = [];
  int? _eventId;
  bool _loading = false;
  bool _loadingEvents = false;
  String? _jsonPath;
  List<String> _photoPaths = const [];
  String? _photoSourceLabel;
  String? _statusMessage;
  Future<Map<String, int>>? _summaryFuture;
  int? _summaryEventId;
  String? _progressPhase;
  double _progressValue = 0;
  int _progressSentBytes = 0;
  int _progressTotalBytes = 0;
  double _progressBytesPerSecond = 0;
  double _progressInstantBytesPerSecond = 0;
  int _progressCompletedBytes = 0;
  final Map<String, int> _progressActiveBytes = {};
  final Stopwatch _progressStopwatch = Stopwatch();
  DateTime? _lastProgressAt;
  DateTime? _lastProgressSampleAt;
  int _lastProgressSampleBytes = 0;
  Timer? _progressTicker;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _progressTicker?.cancel();
    super.dispose();
  }

  Future<bool> _ensureOnlineApi() async {
    final current = ref.read(appRuntimeConfigProvider);
    if (!looksLikeLocalApiBaseUrl(current.apiBaseUrl)) {
      return ref.read(apiProvider).pingPublic();
    }
    final backupConfig =
        await restoreBackedUpRuntimeConfig() ?? AppRuntimeConfig.defaults;
    final reachable = await ApiService(backupConfig).pingPublic();
    if (!reachable) return false;
    await saveAppRuntimeConfig(backupConfig);
    ref.read(appRuntimeConfigProvider.notifier).state = backupConfig;
    ref.invalidate(apiProvider);
    return ref.read(apiProvider).pingPublic();
  }

  Future<void> _loadEvents() async {
    final token = ref.read(staffTokenProvider);
    final user = ref.read(staffUserProvider);
    if (token == null || user == null) return;
    if (mounted) {
      setState(() => _loadingEvents = true);
    }
    try {
      if (!await _ensureOnlineApi()) {
        if (!mounted) return;
        setState(() {
          _loadingEvents = false;
          _statusMessage =
              'Sem ligação ao servidor online. Fecha a sessão offline ou verifica a internet.';
        });
        return;
      }
      final events = await ref
          .read(apiProvider)
          .staffEvents(token, assignedOnly: !_canSeeAllEvents(user));
      final visibleEvents = _filterEventsForUser(events, user);
      if (!mounted) return;
      visibleEvents.sort((a, b) {
        final aNum = _numericReportNumberValue(a);
        final bNum = _numericReportNumberValue(b);
        if (aNum != bNum) return bNum.compareTo(aNum);
        final aDate = _parseEventDate(a.eventDate);
        final bDate = _parseEventDate(b.eventDate);
        if (aDate != null && bDate != null) {
          return bDate.compareTo(aDate);
        }
        return b.id.compareTo(a.id);
      });
      setState(() {
        _loadingEvents = false;
        _events = visibleEvents;
        _eventId ??= visibleEvents.isNotEmpty ? visibleEvents.first.id : null;
        if (_eventId != null && _summaryEventId != _eventId) {
          _summaryEventId = _eventId;
          _summaryFuture = _loadSummary(token, _eventId!);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingEvents = false;
        _statusMessage = 'Erro ao carregar eventos: ${formatUiError(e)}';
      });
    }
  }

  StaffEvent? _selectedEvent() {
    for (final event in _events) {
      if (event.id == _eventId) return event;
    }
    return null;
  }

  String _eventPickerLabel(StaffEvent event) {
    final report = _displayReportNumber(event);
    final pieces = <String>[
      if (report != null && report.isNotEmpty) '#$report',
      event.name,
      if (event.eventDate.trim().isNotEmpty) event.eventDate.trim(),
    ];
    return pieces.join(' • ');
  }

  Future<void> _pickEventFromSearch() async {
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        final searchCtrl = TextEditingController();
        var query = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final visible = query.isEmpty
                ? _events
                : _events.where((event) {
                    return _eventSearchBlob(event).contains(query);
                  }).toList();
            return AlertDialog(
              title: const Text('Selecionar evento'),
              content: SizedBox(
                width: 640,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      onChanged: (value) => setDialogState(() {
                        query = value.trim().toLowerCase();
                      }),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Pesquisar evento, reportagem ou nome',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(child: Text('Sem resultados.'))
                          : ListView.separated(
                              itemCount: visible.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final event = visible[index];
                                return ListTile(
                                  title: Text(
                                    event.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    _eventPickerLabel(event),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () =>
                                      Navigator.of(dialogContext).pop(event.id),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() {
      _eventId = result;
      _summaryFuture = null;
      _summaryEventId = null;
    });
  }

  Future<void> _pickJsonFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final selectedPath = picked.files.single.path;
    if (selectedPath == null || !mounted) return;
    setState(() {
      _jsonPath = selectedPath;
      _statusMessage = null;
    });
  }

  Future<void> _pickPhotos() async {
    if (isDesktopPlatform()) {
      final directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Selecionar pasta das fotos',
      );
      if (directoryPath != null) {
        final files = listOfflinePhotoPathsFromDirectory(directoryPath);
        if (!mounted) return;
        setState(() {
          _photoPaths = files;
          _photoSourceLabel = directoryPath;
          _statusMessage = null;
        });
        return;
      }
    }

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: kOfflinePhotoExtensions.toList(),
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final files = picked.files
        .map((file) => file.path)
        .whereType<String>()
        .toList();
    setState(() {
      _photoPaths = files;
      _photoSourceLabel = files.isEmpty ? null : '${files.length} ficheiros';
      _statusMessage = null;
    });
  }

  Future<Map<String, int>> _loadSummary(String token, int eventId) async {
    if (!await _ensureOnlineApi()) {
      throw Exception(
        'Sem ligação ao servidor online. Fecha a sessão offline ou verifica a internet.',
      );
    }
    final results = await Future.wait([
      ref.read(apiProvider).staffOrdersTotal(token, eventId: eventId),
      ref.read(apiProvider).staffEventPhotosTotal(token, eventId),
    ]);
    return {'orders': results[0] as int, 'photos': results[1] as int};
  }

  Future<int> _sumFileSizes(Iterable<String> filePaths) async {
    var total = 0;
    for (final filePath in filePaths) {
      try {
        total += await File(filePath).length();
      } catch (_) {}
    }
    return total;
  }

  void _startProgress(int totalBytes) {
    _progressTicker?.cancel();
    _progressStopwatch
      ..reset()
      ..start();
    _progressCompletedBytes = 0;
    _progressActiveBytes.clear();
    _progressValue = 0;
    _progressSentBytes = 0;
    _progressTotalBytes = max(0, totalBytes);
    _progressBytesPerSecond = 0;
    _progressInstantBytesPerSecond = 0;
    _progressPhase = 'A preparar sincronização...';
    _lastProgressAt = DateTime.now();
    _lastProgressSampleAt = _lastProgressAt;
    _lastProgressSampleBytes = 0;
    _progressTicker = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted || !_loading) return;
      setState(() {
        _recalculateProgress();
      });
    });
  }

  void _setProgressPhase(String phase) {
    _progressPhase = phase;
  }

  void _updateProgress(String key, int sentBytes) {
    _progressActiveBytes[key] = max(0, sentBytes);
    _lastProgressAt = DateTime.now();
    _recalculateProgress();
  }

  void _completeProgress(String key, int payloadBytes) {
    _progressActiveBytes.remove(key);
    _progressCompletedBytes += max(0, payloadBytes);
    _lastProgressAt = DateTime.now();
    _recalculateProgress();
  }

  void _dropProgress(String key) {
    _progressActiveBytes.remove(key);
    _recalculateProgress();
  }

  void _finishProgress() {
    _progressActiveBytes.clear();
    _progressCompletedBytes = _progressTotalBytes;
    _progressValue = 1;
    _progressSentBytes = _progressTotalBytes;
    _progressBytesPerSecond = _progressStopwatch.elapsedMilliseconds > 0
        ? _progressSentBytes / (_progressStopwatch.elapsedMilliseconds / 1000)
        : 0;
    _progressInstantBytesPerSecond = _progressBytesPerSecond;
    _progressPhase = 'Concluído.';
    _lastProgressAt = DateTime.now();
    _progressStopwatch.stop();
    _progressTicker?.cancel();
    _progressTicker = null;
  }

  void _clearProgress() {
    _progressTicker?.cancel();
    _progressTicker = null;
    _progressStopwatch.stop();
    _progressActiveBytes.clear();
    _progressCompletedBytes = 0;
    _progressValue = 0;
    _progressSentBytes = 0;
    _progressTotalBytes = 0;
    _progressBytesPerSecond = 0;
    _progressInstantBytesPerSecond = 0;
    _progressPhase = null;
    _lastProgressAt = null;
    _lastProgressSampleAt = null;
    _lastProgressSampleBytes = 0;
  }

  void _recalculateProgress() {
    final activeSent = _progressActiveBytes.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final sent = min(_progressTotalBytes, _progressCompletedBytes + activeSent);
    _progressSentBytes = sent;
    _progressValue = _progressTotalBytes <= 0
        ? 0
        : sent / _progressTotalBytes;
    _progressBytesPerSecond = _progressStopwatch.elapsedMilliseconds > 0
        ? sent / (_progressStopwatch.elapsedMilliseconds / 1000)
        : 0;
    final now = DateTime.now();
    final sampleAt = _lastProgressSampleAt;
    if (sampleAt != null) {
      final elapsedMs = now.difference(sampleAt).inMilliseconds;
      if (elapsedMs >= 180) {
        final deltaBytes = max(0, sent - _lastProgressSampleBytes);
        final instant = deltaBytes / (elapsedMs / 1000);
        _progressInstantBytesPerSecond = _progressInstantBytesPerSecond <= 0
            ? instant
            : (_progressInstantBytesPerSecond * 0.6) + (instant * 0.4);
        _lastProgressSampleAt = now;
        _lastProgressSampleBytes = sent;
      }
    } else {
      _lastProgressSampleAt = now;
      _lastProgressSampleBytes = sent;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final decimals = value >= 100 ? 0 : value >= 10 ? 1 : 2;
    return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
  }

  String _progressIdleLabel() {
    if (_lastProgressAt == null) return '0 ms';
    final idle = DateTime.now().difference(_lastProgressAt!).inMilliseconds;
    if (idle < 1000) return '$idle ms';
    return '${(idle / 1000).toStringAsFixed(2)} s';
  }

  String _formatEta(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes < 60) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    final hours = duration.inHours;
    final remainingMinutes = duration.inMinutes % 60;
    return '${hours}h ${remainingMinutes.toString().padLeft(2, '0')}m';
  }

  String _progressEtaLabel() {
    final remainingBytes = max(0, _progressTotalBytes - _progressSentBytes);
    if (remainingBytes <= 0) return '0s';
    final averageSpeed = _progressBytesPerSecond;
    final currentSpeed = _progressInstantBytesPerSecond;
    final etaSpeed = averageSpeed > 0
        ? (currentSpeed > 0
              ? max(averageSpeed * 0.85, currentSpeed * 0.35 + averageSpeed * 0.65)
              : averageSpeed)
        : currentSpeed;
    if (etaSpeed <= 0) return '--';
    final etaSeconds = max(1, (remainingBytes / etaSpeed).round());
    return _formatEta(Duration(seconds: etaSeconds));
  }

  Future<Map<String, int>> _buildPhotoSizeIndex(
    Iterable<String> photoPaths,
  ) async {
    final sizes = <String, int>{};
    for (final photoPath in photoPaths) {
      try {
        sizes[photoPath] = await File(photoPath).length();
      } catch (_) {
        sizes[photoPath] = 0;
      }
    }
    return sizes;
  }

  Future<Map<String, dynamic>> _loadOfflinePhotosMetaIndex(
    String jsonPath,
  ) async {
    final raw = await File(jsonPath).readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const {};
    }
    final photos = decoded['photos'];
    if (photos is! List) {
      return const {};
    }
    final index = <String, dynamic>{};
    for (final photo in photos.whereType<Map>()) {
      final map = Map<String, dynamic>.from(photo.cast<String, dynamic>());
      final originalPath = map['original_path']?.toString();
      final previewPath = map['preview_path']?.toString();
      final fileName = originalPath != null && originalPath.isNotEmpty
          ? path.basename(originalPath)
          : previewPath != null && previewPath.isNotEmpty
          ? path.basename(previewPath)
          : null;
      if (fileName != null && fileName.isNotEmpty) {
        index[fileName.toLowerCase()] = map;
      }
    }
    return index;
  }

  List<dynamic> _matchPhotosMetaForBatch(
    Map<String, dynamic> photoMetaIndex,
    List<String> batchPaths,
  ) {
    final matched = <dynamic>[];
    for (final photoPath in batchPaths) {
      final fileName = path.basename(photoPath).toLowerCase();
      final meta = photoMetaIndex[fileName];
      if (meta != null) {
        matched.add(meta);
      }
    }
    return matched;
  }

  bool _isPayloadTooLargeError(Object error) =>
      error is DioException && error.response?.statusCode == 413;

  Future<List<List<String>>> _photoBatches(
    List<String> photoPaths,
    Map<String, int> sizeByPath,
  ) async {
    final batches = <List<String>>[];
    var current = <String>[];
    var currentBytes = 0;
    for (final photoPath in photoPaths) {
      final fileBytes = sizeByPath[photoPath] ?? 0;
      final shouldSplit = current.isNotEmpty &&
          (current.length >= _photoBatchSize ||
              currentBytes + fileBytes > _maxPhotoBatchBytes);
      if (shouldSplit) {
        batches.add(current);
        current = <String>[];
        currentBytes = 0;
      }
      current.add(photoPath);
      currentBytes += fileBytes;
    }
    if (current.isNotEmpty) {
      batches.add(current);
    }
    return batches;
  }

  Future<void> _uploadPhotoBatchSafely(
    String token,
    int eventId,
    List<String> batch,
    Map<String, dynamic> photoMetaIndex, {
    required String requestKey,
    required int payloadBytes,
  }) async {
    try {
      await ref.read(apiProvider).offlineImportPhotoBatch(
        token,
        eventId,
        batch,
        photosMeta: _matchPhotosMetaForBatch(photoMetaIndex, batch),
        onSendProgress: (sent, total) {
          final effectiveSent = total > 0
              ? ((sent / total) * payloadBytes).round()
              : min(sent, payloadBytes);
          if (!mounted) return;
          setState(() => _updateProgress(requestKey, effectiveSent));
        },
      );
      if (!mounted) return;
      setState(() => _completeProgress(requestKey, payloadBytes));
    } catch (error) {
      if (_isPayloadTooLargeError(error) && batch.length > 1) {
        final mid = batch.length ~/ 2;
        final first = batch.sublist(0, mid);
        final second = batch.sublist(mid);
        final firstBytes = await _sumFileSizes(first);
        final secondBytes = max(0, payloadBytes - firstBytes);
        if (!mounted) return;
        setState(() {
          _dropProgress(requestKey);
          _setProgressPhase(
            'Lote demasiado grande. A dividir automaticamente...',
          );
        });
        await _uploadPhotoBatchSafely(
          token,
          eventId,
          first,
          photoMetaIndex,
          requestKey: '$requestKey-a',
          payloadBytes: firstBytes,
        );
        await _uploadPhotoBatchSafely(
          token,
          eventId,
          second,
          photoMetaIndex,
          requestKey: '$requestKey-b',
          payloadBytes: secondBytes,
        );
        return;
      }
      if (_isPayloadTooLargeError(error) && batch.length == 1) {
        final fileName = path.basename(batch.first);
        if (mounted) {
          setState(() => _dropProgress(requestKey));
        }
        throw Exception(
          'O ficheiro $fileName excede o limite do servidor. Reduz o tamanho dessa foto e tenta novamente.',
        );
      }
      if (mounted) {
        setState(() => _dropProgress(requestKey));
      }
      rethrow;
    }
  }

  Future<void> _uploadPhotoBatches(
    String token,
    int eventId,
    Map<String, dynamic> photoMetaIndex,
    Map<String, int> sizeByPath,
  ) async {
    final batches = await _photoBatches(_photoPaths, sizeByPath);
    final batchSizes = <int>[];
    for (final batch in batches) {
      batchSizes.add(
        batch.fold<int>(0, (sum, filePath) => sum + (sizeByPath[filePath] ?? 0)),
      );
    }
    var uploadedPhotos = 0;
    for (var i = 0; i < batches.length; i += _parallelPhotoUploads) {
      final window = batches.skip(i).take(_parallelPhotoUploads).toList();
      final batchPhotoCount = window.fold<int>(
        0,
        (sum, batch) => sum + batch.length,
      );
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'A importar fotos ${uploadedPhotos + 1}-${min(uploadedPhotos + batchPhotoCount, _photoPaths.length)} de ${_photoPaths.length}...';
        _setProgressPhase(_statusMessage!);
      });
      await Future.wait(
        window.asMap().entries.map((entry) async {
          final batchIndex = i + entry.key;
          final batch = entry.value;
          final payloadBytes = batchSizes[batchIndex];
          final requestKey = 'photos-$batchIndex';
          await _uploadPhotoBatchSafely(
            token,
            eventId,
            batch,
            photoMetaIndex,
            requestKey: requestKey,
            payloadBytes: payloadBytes,
          );
        }),
      );
      uploadedPhotos += batchPhotoCount;
    }
  }

  Future<void> _importPackage() async {
    final token = ref.read(staffTokenProvider);
    if (token == null || _eventId == null || _jsonPath == null) return;
    setState(() => _loading = true);
    try {
      if (!await _ensureOnlineApi()) {
        throw Exception(
          'Sem ligação ao servidor online. Fecha a sessão offline ou verifica a internet.',
        );
      }
      final totalBytes =
          await File(_jsonPath!).length();
      final photoSizeIndex = await _buildPhotoSizeIndex(_photoPaths);
      final totalPhotoBytes = photoSizeIndex.values.fold<int>(
        0,
        (sum, value) => sum + value,
      );
      if (!mounted) return;
      setState(() => _startProgress(totalBytes + totalPhotoBytes));
      final photoMetaIndex = await _loadOfflinePhotosMetaIndex(_jsonPath!);
      if (_photoPaths.isNotEmpty) {
        await _uploadPhotoBatches(
          token,
          _eventId!,
          photoMetaIndex,
          photoSizeIndex,
        );
      }
      if (!mounted) return;
      setState(() {
        _statusMessage = 'A importar JSON...';
        _setProgressPhase(_statusMessage!);
      });
      final deviceId = await getDeviceId();
      final jsonBytes = await File(_jsonPath!).length();
      const jsonRequestKey = 'payload-json';
      try {
        await ref.read(apiProvider).offlineImportFile(
          token,
          _eventId!,
          _jsonPath!,
          deviceId,
          onSendProgress: (sent, total) {
            final effectiveSent = total > 0
                ? ((sent / total) * jsonBytes).round()
                : min(sent, jsonBytes);
            if (!mounted) return;
            setState(() => _updateProgress(jsonRequestKey, effectiveSent));
          },
        );
        if (!mounted) return;
        setState(() => _completeProgress(jsonRequestKey, jsonBytes));
      } catch (_) {
        if (mounted) {
          setState(() => _dropProgress(jsonRequestKey));
        }
        rethrow;
      }
      StaffEvent? importedEvent;
      for (final event in _events) {
        if (event.id == _eventId) {
          importedEvent = event;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _finishProgress();
        _statusMessage = 'Importação concluída.';
        _jsonPath = null;
        _photoPaths = const [];
        _photoSourceLabel = null;
        _summaryFuture = null;
        _summaryEventId = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Importação concluída.')));
      if (importedEvent != null) {
        final targetEvent = importedEvent;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _StaffEventGalleryPage(event: targetEvent),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = formatUiError(e);
      setState(() {
        _clearProgress();
        _statusMessage = 'Erro: $message';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro import: $message')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          if ((_statusMessage ?? '') != 'Importação concluída.') {
            _clearProgress();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    if (token == null) {
      return const SizedBox.shrink();
    }
    if (_eventId != null &&
        (_summaryFuture == null || _summaryEventId != _eventId)) {
      _summaryEventId = _eventId;
      _summaryFuture = _loadSummary(token, _eventId!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.embedded) ...[
          const _DeskSectionHeader('Sincronizacao offline'),
          const SizedBox(height: 12),
        ],
        InkWell(
          onTap: _loading || _loadingEvents || _events.isEmpty
              ? null
              : _pickEventFromSearch,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: '1. Evento',
              helperText: _loadingEvents
                  ? 'A carregar eventos...'
                  : 'Pesquisa por nome, reportagem ou data',
              border: const OutlineInputBorder(),
              suffixIcon: _loadingEvents
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search),
            ),
            child: Text(
              _selectedEvent() != null
                  ? _eventPickerLabel(_selectedEvent()!)
                  : 'Selecionar evento',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _selectedEvent() != null
                    ? Colors.white
                    : Colors.white.withOpacity(0.55),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _loading ? null : _pickPhotos,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(
            _photoPaths.isEmpty
                ? '2. Escolher fotos JPG/JPEG'
                : '2. Fotos selecionadas: ${_photoPaths.length}',
          ),
        ),
        if ((_photoSourceLabel ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _photoSourceLabel!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loading ? null : _pickJsonFile,
          icon: const Icon(Icons.description_outlined),
          label: Text(
            _jsonPath == null
                ? '3. Escolher ficheiro JSON'
                : '3. JSON: ${path.basename(_jsonPath!)}',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loading || _eventId == null || _jsonPath == null
                ? null
                : _importPackage,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_loading ? 'A importar...' : 'Importar'),
          ),
        ),
        if ((_loading || _progressValue > 0) && _progressTotalBytes > 0) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _progressValue.clamp(0, 1).toDouble(),
              minHeight: 12,
              backgroundColor: Colors.white.withOpacity(0.08),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_progressValue * 100).toStringAsFixed(1)}%  •  ${_formatBytes(_progressSentBytes)} / ${_formatBytes(_progressTotalBytes)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Atual ${_formatBytes(_progressInstantBytesPerSecond.round())}/s  •  Média ${_formatBytes(_progressBytesPerSecond.round())}/s  •  ETA ${_progressEtaLabel()}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Último avanço há ${_progressIdleLabel()}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 12,
            ),
          ),
          if ((_progressPhase ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _progressPhase!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 12,
              ),
            ),
          ],
        ],
        if ((_statusMessage ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(_statusMessage!),
        ],
        const SizedBox(height: 18),
        if (_eventId != null) ...[
          FutureBuilder<Map<String, int>>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              final orders = snapshot.data?['orders'] ?? 0;
              final photos = snapshot.data?['photos'] ?? 0;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _DeskCard(
                    child: SizedBox(
                      width: 260,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Base de dados',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text('Pedidos no evento: $orders'),
                          const SizedBox(height: 6),
                          Text('Fotos no evento: $photos'),
                        ],
                      ),
                    ),
                  ),
                  _DeskCard(
                    child: SizedBox(
                      width: 260,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pacote selecionado',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text('Fotos: ${_photoPaths.length}'),
                          const SizedBox(height: 6),
                          Text(
                            _jsonPath == null
                                ? 'JSON: nenhum'
                                : 'JSON: ${path.basename(_jsonPath!)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
