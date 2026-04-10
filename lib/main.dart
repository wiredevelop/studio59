import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
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
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

const String kApiBaseUrl = 'https://studio59.wiredevelop.pt/api';
const String kMerchantCountryCode = 'PT';
const String kApplePayMerchantId = 'merchant.com.wiredevelop.studio59';
const bool kEnablePlatformPay = true;
const String kStripeUrlScheme = 'flutterstripe';

bool isDesktopPlatform() {
  if (kIsWeb) return false;
  final platform = defaultTargetPlatform;
  if (platform == TargetPlatform.windows || platform == TargetPlatform.macOS || platform == TargetPlatform.linux) {
    return true;
  }
  try {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  } catch (_) {
    return false;
  }
}

bool useDesktopLayout(BuildContext context) {
  if (isDesktopPlatform()) return true;
  final width = MediaQuery.of(context).size.width;
  return width >= 1100;
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

const Set<String> kOnlineWebMethods = {
  'mb_way',
  'paypal',
  'revolut_pay',
  'amazon_pay',
  'bancontact',
  'eps',
  'klarna',
};

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
    const OnlineMethodOption('amazon_pay', 'Amazon Pay', opensWeb: true),
    const OnlineMethodOption('bancontact', 'Bancontact', opensWeb: true),
    const OnlineMethodOption('eps', 'EPS', opensWeb: true),
    const OnlineMethodOption('klarna', 'Klarna', opensWeb: true),
  ];
}
const Map<String, String> kStaffPermissions = {
  'dashboard.view': 'Ver dashboard',
  'events.list': 'Ver calendário de eventos',
  'events.view': 'Ver detalhes dos eventos',
  'events.view.all': 'Ver todos os eventos (ignora equipa)',
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

  'clients.list': 'Ver clientes',
  'clients.view': 'Ver detalhes do cliente',
  'clients.create': 'Criar clientes',
  'clients.update': 'Editar clientes',
  'clients.delete': 'Apagar clientes',

  'offline.export': 'Exportar dados offline',
  'offline.import': 'Importar dados offline',
};
const Set<String> kStaffDefaultPermissions = {
  'dashboard.view',
  'events.list',
  'photos.list',
  'photos.update',
  'photos.delete',
  'photos.bulk_delete',
  'photos.original',
};
final baseUrlProvider = StateProvider<String>((_) => kApiBaseUrl);
final guestSessionProvider = StateProvider<GuestSession?>((_) => null);
final staffTokenProvider = StateProvider<String?>((_) => null);
final staffUserProvider = StateProvider<StaffUser?>((_) => null);
final apiProvider = Provider<ApiService>((ref) => ApiService(ref.watch(baseUrlProvider)));
final cartProvider = StateNotifierProvider<CartNotifier, Map<int, CartItem>>((_) => CartNotifier());
final savedOrdersProvider = StateNotifierProvider<SavedOrdersNotifier, List<String>>((_) => SavedOrdersNotifier());
final wantsFilmProvider = StateProvider<bool>((_) => false);

const String kStaffLastRouteKey = 'staff_last_route';
const String kStaffLastRouteUserKey = 'staff_last_route_user_id';

class Studio59App extends ConsumerStatefulWidget {
  const Studio59App({super.key});

  @override
  ConsumerState<Studio59App> createState() => _Studio59AppState();
}

class _Studio59AppState extends ConsumerState<Studio59App> {
  final _navKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _appLinkSub;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  Future<void> _initAppLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _handleAppLink(initial);
      }
    } catch (_) {}
    _appLinkSub = _appLinks.uriLinkStream.listen(_handleAppLink, onError: (_) {});
  }

  void _handleAppLink(Uri uri) {
    if (uri.scheme != kStripeUrlScheme) return;
    if (uri.host != 'checkout') return;
    final orderCode = uri.queryParameters['order_code'] ?? uri.queryParameters['order'] ?? '';
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
        fontFamilyFallback: const ['SF Pro Text', 'SF Pro Display', 'Helvetica Neue', 'Arial'],
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
        textTheme: ThemeData.dark().textTheme.apply(bodyColor: kBrandRose, displayColor: kBrandRose),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: kBrandRose),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kBrandRose,
            foregroundColor: kBrandBlack,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: kBrandBlack,
          contentTextStyle: TextStyle(color: kBrandRose),
          actionTextColor: kBrandRose,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: kBrandBlack,
          titleTextStyle: TextStyle(color: kBrandRose, fontSize: 18, fontWeight: FontWeight.w600),
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
  int _logoTapCount = 0;
  DateTime? _firstTapAt;
  bool _autoOpenedStaff = false;

  @override
  void initState() {
    super.initState();
    _restoreStaffSession();
    _pinCtrl.addListener(_handlePinInput);
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

  Future<void> _enterByQrToken(String token) async {
    try {
      final session = await ref.read(apiProvider).enterEventByQr(token);
      ref.read(guestSessionProvider.notifier).state = session;
      ref.read(cartProvider.notifier).clear();
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => GuestCatalogPage(eventId: session.eventId)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao entrar: $e')));
    }
  }

  Future<void> _enterByPin(String pin) async {
    try {
      final session = await ref.read(apiProvider).enterEventByPin(pin);
      ref.read(guestSessionProvider.notifier).state = session;
      ref.read(cartProvider.notifier).clear();
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => GuestCatalogPage(eventId: session.eventId)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao entrar: $e')));
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
    if (_firstTapAt == null || now.difference(_firstTapAt!) > const Duration(seconds: 3)) {
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffDashboardPage()));
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
      case 'users':
        target = const StaffUsersPage();
        break;
      case 'clients':
        target = const StaffClientsPage();
        break;
      case 'sync':
        target = const StaffSyncPage();
        break;
      case 'dashboard':
      default:
        target = const StaffDashboardPage();
        break;
    }
    if (!mounted) return;
    if (replace) {
      if (lastRoute != null && lastRoute != 'dashboard') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StaffDashboardPage()));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.push(context, MaterialPageRoute(builder: (_) => target));
        });
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => target));
      }
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => target));
    }
  }

  void _onQrDetect(BarcodeCapture capture) {
    if (_handlingScan) return;
    final raw = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null || raw.trim().isEmpty) return;
    _handlingScan = true;
    final token = extractQrToken(raw);
    _enterByQrToken(token).whenComplete(() {
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
                      child: Image.asset('assets/app_icon.png', width: 72, height: 72),
                    ),
                    const SizedBox(height: 8),
                    const Text('Studio 59', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
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

void showQrDialog(BuildContext context, {required String title, required String url}) {
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
            Text(url, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
    ),
  );
}

PreferredSizeWidget buildNavAppBar(BuildContext context, String title, {List<Widget> actions = const []}) {
  return AppBar(
    title: Text(title),
    leading: navLeading(context),
    actions: navActions(context, extra: actions),
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

Future<void> _writeOfflinePayload(int eventId, Map<String, dynamic> payload) async {
  final file = await _offlineFileForEvent(eventId);
  await file.writeAsString(jsonEncode(payload));
}

Future<void> enqueueOfflineOrder(int eventId, Map<String, dynamic> order) async {
  final payload = await _readOfflinePayload(eventId);
  final orders = (payload['orders'] as List? ?? []).cast<Map<String, dynamic>>();
  orders.add(order);
  payload['event_id'] = eventId;
  payload['orders'] = orders;
  payload['selections'] ??= [];
  payload['order_updates'] ??= [];
  final clients = (payload['clients'] as List? ?? []).cast<Map<String, dynamic>>();
  final email = order['customer_email']?.toString().trim();
  final phone = order['customer_phone']?.toString().trim();
  if ((email != null && email.isNotEmpty) || (phone != null && phone.isNotEmpty)) {
    final exists = clients.any((c) => (email != null && c['email'] == email) || (phone != null && c['phone'] == phone));
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
  final selections = (payload['selections'] as List? ?? []).cast<Map<String, dynamic>>();
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

Future<void> enqueueOrderUpdate(int eventId, int orderId, String status) async {
  final payload = await _readOfflinePayload(eventId);
  final updates = (payload['order_updates'] as List? ?? []).cast<Map<String, dynamic>>();
  updates.add({
    'uuid': const Uuid().v4(),
    'event_id': eventId,
    'order_id': orderId,
    'status': status,
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

Future<File> writeOfflineExportFile(int eventId, Map<String, dynamic> payload) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/offline_export_${eventId}_${DateTime.now().millisecondsSinceEpoch}.json';
  final file = File(path);
  await file.writeAsString(jsonEncode(payload));
  return file;
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
    final raw = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
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
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
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
  static const int perPage = 50;

  void _openPhotoPreview(PhotoItem photo) {
    showDialog(
      context: context,
      builder: (_) {
        final selected = ref.watch(cartProvider).containsKey(photo.id);
        final size = MediaQuery.of(context).size;
        return AlertDialog(
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
                          child: Image.network(photo.previewUrl!, fit: BoxFit.contain),
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
            FilledButton(
              onPressed: () {
                ref.read(cartProvider.notifier).toggle(photo);
                Navigator.pop(context);
              },
              child: Text(selected ? 'Remover' : 'Selecionar'),
            ),
          ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao abrir câmara: $e')),
      );
      return;
    }
    if (file == null) return;

    setState(() => faceSearching = true);
    try {
      final results = await ref.read(apiProvider).faceSearch(widget.eventId, session.token, file.path);
      setState(() => suggested = results);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro pesquisa facial: $e')));
    } finally {
      if (mounted) setState(() => faceSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(guestSessionProvider);
    if (session == null) return const Scaffold(body: Center(child: Text('Sessao expirada')));

    return SecureScreen(
      child: Scaffold(
        appBar: buildNavAppBar(
          context,
          session.eventName,
          actions: [
            if (session.qrToken != null && session.qrToken!.isNotEmpty)
              IconButton(
                onPressed: () {
                  final url = ref.read(apiProvider).publicQrUrl(session.qrToken!);
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
                          if (session.eventType != null && session.eventType!.isNotEmpty) Text('Tipo: ${session.eventType}'),
                          if (session.eventDate != null && session.eventDate!.isNotEmpty)
                            Text('Data: ${_formatEventDateTime(session.eventDate!, null)}'),
                          if (session.basePrice != null) Text('Preço base: ${session.basePrice}'),
                          Text('Preço por foto: ${session.pricePerPhoto}'),
                          const SizedBox(height: 8),
                          ...session.eventMeta.entries.map((e) => Text('${_prettyMetaKey(e.key)}: ${e.value}')),
                        ],
                      ),
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
                  ),
                );
              },
              icon: const Icon(Icons.info_outline),
              tooltip: 'Detalhes',
            ),
            IconButton(
              onPressed: faceSearching ? null : () => _startFaceSearch(session),
              icon: faceSearching
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.face_retouching_natural),
              tooltip: 'Pesquisa facial',
            ),
            IconButton(
              onPressed: () {
                ref.read(cartProvider.notifier).clear();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Novo convidado pronto. Carrinho limpo.')));
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
                    onPressed: () => setState(() {
                      search = searchController.text.trim();
                      page = 1;
                    }),
                    icon: const Icon(Icons.search),
                  ),
                ),
                onSubmitted: (v) => setState(() {
                  search = v.trim();
                  page = 1;
                }),
              ),
            ),
            Expanded(
              child: FutureBuilder<PhotosPage>(
                future: ref.read(apiProvider).eventPhotosPage(widget.eventId, session.token, search: search, page: page, perPage: perPage),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
                    return const Center(child: CircularProgressIndicator());
                  }
                  final pageData = snap.data!;
                  final photos = pageData.items;
                  final selected = ref.watch(cartProvider);
                  final suggestedIds = suggested.map((p) => p.id).toSet();
                  final remaining = photos.where((p) => !suggestedIds.contains(p.id)).toList();

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
                                    child: photo.previewUrl == null
                                        ? const Center(child: Text('preview...'))
                                        : Image.network(
                                            photo.previewUrl!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder: (context, error, stackTrace) => const Center(child: Text('Sem preview')),
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
                                      ref.read(cartProvider.notifier).toggle(photo);
                                      final nowSelected = ref.read(cartProvider).containsKey(photo.id);
                                      await enqueueSelection(widget.eventId, photo.id, nowSelected ? 'selected' : 'unselected');
                                    },
                                    child: Icon(
                                      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                      color: isSelected ? kBrandRose : kBrandRose.withOpacity(0.6),
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
                                Text(photo.number, style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined),
                                  onPressed: () async {
                                    ref.read(cartProvider.notifier).toggle(photo);
                                    final nowSelected = ref.read(cartProvider).containsKey(photo.id);
                                    await enqueueSelection(widget.eventId, photo.id, nowSelected ? 'selected' : 'unselected');
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  void goToPage(int next) {
                    if (next < 1 || next > pageData.lastPage) return;
                    if (next == page) return;
                    setState(() => page = next);
                  }

                  Widget pager() {
                    if (pageData.lastPage <= 1) return const SizedBox.shrink();
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: page > 1 ? () => goToPage(page - 1) : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          ...List.generate(pageData.lastPage, (i) {
                            final p = i + 1;
                            final selected = p == page;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: OutlinedButton(
                                onPressed: () => goToPage(p),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: selected ? kBrandRose : null,
                                  foregroundColor: selected ? kBrandBlack : null,
                                  side: BorderSide(color: selected ? kBrandRose : kBrandRose.withOpacity(0.6)),
                                  minimumSize: const Size(40, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                ),
                                child: Text('$p'),
                              ),
                            );
                          }),
                          IconButton(
                            onPressed: page < pageData.lastPage ? () => goToPage(page + 1) : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'A mostrar ${pageData.total} fotos',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
                              goToPage(page - 1);
                            } else if (v < -300) {
                              goToPage(page + 1);
                            }
                          },
                          child: CustomScrollView(
                            slivers: [
                      if (suggested.isNotEmpty) ...[
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(8, 4, 8, 6),
                            child: Text('SUGESTOES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => buildPhotoCard(suggested[i]),
                              childCount: suggested.length,
                            ),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.72),
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(8, 8, 8, 6),
                          child: Text('TODAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => buildPhotoCard(remaining[i]),
                            childCount: remaining.length,
                          ),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.72),
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
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOrdersPage())),
                  child: const Text('Os meus pedidos'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CartPage(eventId: widget.eventId))),
                  child: Consumer(builder: (context, ref, child) {
                    final count = ref.watch(cartProvider).values.fold<int>(0, (sum, item) => sum + item.quantity);
                    return Text('Carrinho ($count)');
                  }),
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
    final itemsTotal = items.fold<num>(0, (sum, item) => sum + (item.quantity * pricePerPhoto));
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
                            ? const SizedBox(width: 56, height: 56, child: Icon(Icons.photo))
                            : Image.network(item.previewUrl!, width: 56, height: 56, fit: BoxFit.cover),
                        title: Text('Foto ${item.number}'),
                        subtitle: Text('Quantidade: ${item.quantity}'),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () async {
                                final before = item.quantity;
                                ref.read(cartProvider.notifier).decrement(item.photoId);
                                if (before == 1) {
                                  await enqueueSelection(widget.eventId, item.photoId, 'unselected');
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => ref.read(cartProvider.notifier).increment(item.photoId),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                ref.read(cartProvider.notifier).remove(item.photoId);
                                await enqueueSelection(widget.eventId, item.photoId, 'unselected');
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
                      onChanged: (v) => ref.read(wantsFilmProvider.notifier).state = v ?? false,
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
                            MaterialPageRoute(builder: (_) => CheckoutPage(eventId: widget.eventId)),
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
  final stripe.CardFormEditController _cardFormController = stripe.CardFormEditController();
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
        _paymentBadge('KLARNA'),
        _paymentBadge('BANCONTACT'),
        _paymentBadge('EPS'),
      ],
    );
  }

  Widget _methodBadge(String text) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: kBrandRose.withOpacity(0.2),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kBrandRose),
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
      case 'amazon_pay':
        return _methodBadge('A');
      case 'bancontact':
        return _methodBadge('BC');
      case 'eps':
        return _methodBadge('EPS');
      case 'klarna':
        return _methodBadge('K');
      default:
        return const Icon(Icons.payment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final items = cart.values.toList();
    final session = ref.watch(guestSessionProvider);
    final pricePerPhoto = session?.pricePerPhoto ?? 0;
    final itemsTotal = items.fold<num>(0, (sum, item) => sum + (item.quantity * pricePerPhoto));
    final eventType = session?.eventType ?? '';
    final filmEligible = eventType == 'casamento' || eventType == 'batizado';
    final wantsFilm = filmEligible && ref.watch(wantsFilmProvider);
    final filmFee = wantsFilm ? 30.0 : 0.0;
    final shippingFee = deliveryType == 'shipping' ? 5.0 : 0.0;
    final extrasTotal = filmFee + shippingFee;
    final total = itemsTotal + extrasTotal;
    final supportsApplePay = kEnablePlatformPay && Platform.isIOS;
    final supportsGooglePay = kEnablePlatformPay && Platform.isAndroid;
    final onlineOptions = buildOnlineMethodOptions(
      supportsApplePay: supportsApplePay,
      supportsGooglePay: supportsGooglePay,
    );
    if (onlineOptions.isNotEmpty && !onlineOptions.any((option) => option.id == onlineMethod)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => onlineMethod = onlineOptions.first.id);
      });
    }
    return Scaffold(
      appBar: buildNavAppBar(context, 'Checkout'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(alignment: Alignment.centerLeft, child: Text('Fotos selecionadas: ${items.length}')),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telemóvel', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: Text('Produto', style: const TextStyle(fontWeight: FontWeight.w600))),
            CheckboxListTile(
              value: productType == 'digital',
              onChanged: (_) => setState(() {
                productType = 'digital';
                deliveryType = null;
              }),
              title: const Text('Digital'),
            ),
            CheckboxListTile(
              value: productType == 'paper',
              onChanged: (_) => setState(() {
                productType = 'paper';
                deliveryType = deliveryType ?? 'pickup';
              }),
              title: const Text('Papel'),
            ),
            CheckboxListTile(
              value: productType == 'both',
              onChanged: (_) => setState(() {
                productType = 'both';
                deliveryType = deliveryType ?? 'pickup';
              }),
              title: const Text('Ambos'),
            ),
            if (productType != 'digital') ...[
              Align(alignment: Alignment.centerLeft, child: Text('Entrega', style: const TextStyle(fontWeight: FontWeight.w600))),
              CheckboxListTile(
                value: deliveryType == 'pickup',
                onChanged: (_) => setState(() => deliveryType = 'pickup'),
                title: Text(eventType == 'batizado' ? 'Entregar aos pais do bebé' : 'Entregar aos noivos'),
              ),
              CheckboxListTile(
                value: deliveryType == 'shipping',
                onChanged: (_) => setState(() => deliveryType = 'shipping'),
                title: const Text('Enviar por correio (+5€)'),
              ),
              if (deliveryType == 'shipping') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Morada para envio', border: OutlineInputBorder()),
                ),
              ],
            ],
            if (filmEligible) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(wantsFilm ? 'Filme: Sim (+30€)' : 'Filme: Não'),
              ),
            ],
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: Text('Pagamento', style: const TextStyle(fontWeight: FontWeight.w600))),
            CheckboxListTile(
              value: paymentMethod == 'cash',
              onChanged: (_) => setState(() => paymentMethod = 'cash'),
              title: const Text('Dinheiro (com fotógrafo)'),
            ),
            CheckboxListTile(
              value: paymentMethod == 'online',
              onChanged: (_) => setState(() => paymentMethod = 'online'),
              title: const Text('Pagamento online (Stripe)'),
              subtitle: _paymentBadges(),
            ),
            if (paymentMethod == 'online') ...[
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: Text('Método online', style: const TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(height: 6),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: onlineOptions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = onlineOptions[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: _paymentMethodIcon(option.id),
                    title: Text(option.label),
                    subtitle: option.opensWeb ? const Text('Abre no navegador') : null,
                    trailing: Radio<String>(
                      value: option.id,
                      groupValue: onlineMethod,
                      onChanged: (value) => setState(() => onlineMethod = value ?? option.id),
                    ),
                    onTap: () => setState(() => onlineMethod = option.id),
                  );
                },
              ),
              if (onlineMethod == 'card' && Platform.isIOS) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Dados do cartão', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 6),
                stripe.CardFormField(
                  controller: _cardFormController,
                  style: stripe.CardFormStyle(
                    backgroundColor: Colors.white,
                    textColor: Colors.black,
                    fontSize: 16,
                    borderColor: Colors.black,
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
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Total: €${total.toStringAsFixed(2)} (Extras: €${extrasTotal.toStringAsFixed(2)})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: items.isEmpty || isSubmitting
                  ? null
                  : () async {
                      String? sessionToken;
                      try {
                        setState(() => isSubmitting = true);
                        final session = ref.read(guestSessionProvider);
                        if (session == null) return;
                        sessionToken = session.token;
                        if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome, telemóvel e email são obrigatórios.')));
                          return;
                        }
                        final email = emailCtrl.text.trim();
                        if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Email invalido. Exemplo: nome@email.com')),
                          );
                          return;
                        }
                        if (productType != 'digital' && deliveryType == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolhe o tipo de entrega.')));
                          return;
                        }
                        if (deliveryType == 'shipping' && addressCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Morada obrigatória para envio.')));
                          return;
                        }

                        if (paymentMethod == 'online') {
                          if (!Platform.isAndroid && !Platform.isIOS) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Pagamento online disponível apenas no telemóvel (Android/iOS).')),
                            );
                            return;
                          }
                          if (onlineMethod == 'card' && Platform.isIOS && !_cardComplete) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Preenche os dados do cartão.')),
                            );
                            return;
                          }
                          if (kOnlineWebMethods.contains(onlineMethod)) {
                            final checkout = await ref.read(apiProvider).createStripeCheckoutSession(
                              eventId: widget.eventId,
                              token: session.token,
                              customerName: nameCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                              email: email,
                              photoItems: items.map((i) => CartItemPayload(photoId: i.photoId, quantity: i.quantity)).toList(),
                              productType: productType,
                              deliveryType: deliveryType,
                              deliveryAddress: addressCtrl.text.trim(),
                              wantsFilm: wantsFilm,
                              paymentMethodType: onlineMethod,
                            );
                            if (checkout.checkoutUrl.isEmpty) {
                              throw Exception('Pagamento online indisponível de momento.');
                            }
                            final uri = Uri.tryParse(checkout.checkoutUrl);
                            if (uri == null) {
                              throw Exception('URL de pagamento inválido.');
                            }
                            final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
                            if (!opened) {
                              throw Exception('Não foi possível abrir o navegador.');
                            }
                            await ref.read(savedOrdersProvider.notifier).add(checkout.orderCode);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Completa o pagamento no navegador.')),
                            );
                            return;
                          }
                          final intent = await ref.read(apiProvider).createStripeIntent(
                            eventId: widget.eventId,
                            token: session.token,
                            customerName: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            email: email,
                            photoItems: items.map((i) => CartItemPayload(photoId: i.photoId, quantity: i.quantity)).toList(),
                            productType: productType,
                            deliveryType: deliveryType,
                            deliveryAddress: addressCtrl.text.trim(),
                            wantsFilm: wantsFilm,
                          );
                          stripe.Stripe.publishableKey = intent.publishableKey;
                          if (kEnablePlatformPay && Platform.isIOS) {
                            stripe.Stripe.merchantIdentifier = kApplePayMerchantId;
                          }
                          stripe.Stripe.urlScheme = kStripeUrlScheme;
                          await stripe.Stripe.instance.applySettings();
                          final isTestKey = intent.publishableKey.startsWith('pk_test_');
                          if (onlineMethod == 'card') {
                            if (Platform.isIOS) {
                              var confirmed = await stripe.Stripe.instance.confirmPayment(
                                paymentIntentClientSecret: intent.clientSecret,
                                data: stripe.PaymentMethodParams.card(
                                  paymentMethodData: stripe.PaymentMethodData(
                                    billingDetails: stripe.BillingDetails(
                                      name: nameCtrl.text.trim(),
                                      email: email,
                                      phone: phoneCtrl.text.trim(),
                                    ),
                                  ),
                                ),
                              );
                              if (confirmed.status == stripe.PaymentIntentsStatus.RequiresAction) {
                                confirmed = await stripe.Stripe.instance.handleNextAction(
                                  intent.clientSecret,
                                  returnURL: '$kStripeUrlScheme://redirect',
                                );
                              }
                            } else {
                              await stripe.Stripe.instance.initPaymentSheet(
                                paymentSheetParameters: stripe.SetupPaymentSheetParameters(
                                  paymentIntentClientSecret: intent.clientSecret,
                                  merchantDisplayName: 'Studio 59',
                                  returnURL: '$kStripeUrlScheme://redirect',
                                  style: ThemeMode.dark,
                                ),
                              );
                              await stripe.Stripe.instance.presentPaymentSheet();
                            }
                          } else if (onlineMethod == 'apple_pay') {
                            if (!Platform.isIOS) {
                              throw Exception('Apple Pay só está disponível em iOS.');
                            }
                            final platformPaySupported = await stripe.Stripe.instance.isPlatformPaySupported(
                              googlePay: stripe.IsGooglePaySupportedParams(
                                testEnv: isTestKey,
                                existingPaymentMethodRequired: false,
                              ),
                            );
                            if (!platformPaySupported) {
                              throw Exception('Apple Pay não está disponível neste dispositivo.');
                            }
                            await stripe.Stripe.instance.confirmPlatformPayPaymentIntent(
                              clientSecret: intent.clientSecret,
                              confirmParams: stripe.PlatformPayConfirmParams.applePay(
                                applePay: stripe.ApplePayParams(
                                  merchantCountryCode: kMerchantCountryCode,
                                  currencyCode: 'EUR',
                                  cartItems: [
                                    stripe.ApplePayCartSummaryItem.immediate(
                                      label: 'Studio 59',
                                      amount: total.toStringAsFixed(2),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else if (onlineMethod == 'google_pay') {
                            if (!Platform.isAndroid) {
                              throw Exception('Google Pay só está disponível em Android.');
                            }
                            final platformPaySupported = await stripe.Stripe.instance.isPlatformPaySupported(
                              googlePay: stripe.IsGooglePaySupportedParams(
                                testEnv: isTestKey,
                                existingPaymentMethodRequired: false,
                              ),
                            );
                            if (!platformPaySupported) {
                              throw Exception('Google Pay não está disponível neste dispositivo.');
                            }
                            await stripe.Stripe.instance.confirmPlatformPayPaymentIntent(
                              clientSecret: intent.clientSecret,
                              confirmParams: stripe.PlatformPayConfirmParams.googlePay(
                                googlePay: stripe.GooglePayParams(
                                  testEnv: isTestKey,
                                  merchantCountryCode: kMerchantCountryCode,
                                  currencyCode: 'EUR',
                                  merchantName: 'Studio 59',
                                ),
                              ),
                            );
                          } else {
                            throw Exception('Método de pagamento inválido.');
                          }

                          final code = intent.orderCode;
                          await ref.read(savedOrdersProvider.notifier).add(code);
                          ref.read(cartProvider.notifier).clear();
                          ref.read(wantsFilmProvider.notifier).state = false;
                          if (!context.mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => TicketPage(orderCode: code)),
                          );
                          return;
                        }

                        final code = await ref.read(apiProvider).createOrder(
                          eventId: widget.eventId,
                          token: session.token,
                          customerName: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          email: email,
                          paymentMethod: 'cash',
                          photoItems: items.map((i) => CartItemPayload(photoId: i.photoId, quantity: i.quantity)).toList(),
                          pricePerPhoto: pricePerPhoto,
                          productType: productType,
                          deliveryType: deliveryType,
                          deliveryAddress: addressCtrl.text.trim(),
                          wantsFilm: wantsFilm,
                        );
                        await ref.read(savedOrdersProvider.notifier).add(code);
                        ref.read(cartProvider.notifier).clear();
                        ref.read(wantsFilmProvider.notifier).state = false;
                        if (!context.mounted) return;
                        if (code.startsWith('OFF-')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sem internet. Pedido guardado para sincronizar.')),
                          );
                        }
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => TicketPage(orderCode: code)),
                        );
                      } on stripe.StripeException catch (e) {
                        if (!context.mounted) return;
                        final message = e.error.localizedMessage ?? e.error.message ?? 'Pagamento cancelado.';
                        final type = e.error.type;
                        final code = e.error.code;
                        final suffix = [type, code].where((v) => v != null && v.toString().isNotEmpty).join(' / ');
                        final fullMessage = suffix.isNotEmpty ? '$message ($suffix)' : message;
                        if (sessionToken != null) {
                          await ref.read(apiProvider).logClientIssue(
                                token: sessionToken!,
                                message: 'stripe_exception',
                                context: {
                                  'message': message,
                                  'type': type?.toString(),
                                  'code': code?.toString(),
                                  'platform': Platform.operatingSystem,
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
                          await ref.read(apiProvider).logClientIssue(
                                token: sessionToken!,
                                message: 'payment_flow_error',
                                context: {
                                  'error': e.toString(),
                                  'platform': Platform.operatingSystem,
                                  'release': kReleaseMode,
                                },
                              );
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao submeter: $e')),
                        );
                      } finally {
                        if (mounted) setState(() => isSubmitting = false);
                      }
                    },
              child: Text(isSubmitting ? 'A submeter...' : 'Submeter pedido'),
            ),
          ],
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
          ? const Center(child: Text('Sem pedidos guardados neste dispositivo.'))
          : ListView.builder(
              itemCount: codes.length,
              itemBuilder: (_, i) {
                final code = codes[i];
                return ListTile(
                  title: Text(code),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(orderCode: code))),
                );
              },
            ),
    );
  }
}

class TicketPage extends ConsumerStatefulWidget {
  final String orderCode;
  const TicketPage({super.key, required this.orderCode});

  @override
  ConsumerState<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends ConsumerState<TicketPage> {
  static const MethodChannel _galleryChannel = MethodChannel('studio59/gallery');
  Timer? timer;
  int? downloadingPhotoId;
  bool downloadingAll = false;

  Future<bool> _ensureGalleryPermission() async {
    if (Platform.isIOS) {
      final photosStatus = await Permission.photos.status;
      if (photosStatus.isGranted || photosStatus.isLimited) return true;
      final addOnlyStatus = await Permission.photosAddOnly.status;
      if (addOnlyStatus.isGranted || addOnlyStatus.isLimited) return true;

      final photos = await Permission.photos.request();
      if (photos.isGranted || photos.isLimited) return true;

      final addOnly = await Permission.photosAddOnly.request();
      return addOnly.isGranted || addOnly.isLimited;
    }
    if (Platform.isAndroid) {
      final photos = await Permission.photos.request();
      if (photos.isGranted) return true;
      final storage = await Permission.storage.request();
      return storage.isGranted;
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
      throw 'Falha ao guardar na galeria';
    }
  }

  Future<void> _downloadPhotoToGallery(OrderDetail order, OrderPhoto photo) async {
    final url = await ref.read(apiProvider).orderDownloadLink(
          orderCode: order.orderCode,
          photoId: photo.id,
        );
    final r = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(r.data ?? []);
    if (bytes.isEmpty) {
      throw 'Download vazio';
    }
    final safeNumber = photo.number.replaceAll('/', '-');
    await _saveToGallery(bytes, 'S59_${order.orderCode}_$safeNumber');
  }

  Future<void> _downloadAllToGallery(OrderDetail order) async {
    if (!await _ensureGalleryPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão para guardar fotos negada.')),
      );
      return;
    }

    setState(() => downloadingAll = true);
    try {
      for (final p in order.photos) {
        await _downloadPhotoToGallery(order, p);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download concluído. Fotos guardadas na galeria.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao descarregar: $e')),
      );
    } finally {
      if (mounted) setState(() => downloadingAll = false);
    }
  }

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: Scaffold(
        appBar: buildNavAppBar(context, 'Ticket do Pedido'),
        body: FutureBuilder<OrderDetail>(
          future: ref.read(apiProvider).orderDetail(widget.orderCode),
          builder: (_, snap) {
            if (!snap.hasData) {
              if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
              return const Center(child: CircularProgressIndicator());
            }

            final order = snap.data!;
            final isPaid = order.status == 'paid';
            final isOnline = order.paymentMethod == 'online';

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
                        isPaid
                            ? 'Pagamento confirmado!'
                            : (isOnline ? 'A confirmar pagamento online' : 'Mostra este ecrã ao fotografo'),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isPaid
                            ? 'As tuas fotos estão prontas. Vais receber/recebeste um link único no email para download dos originais.'
                            : (isOnline
                                ? 'Estamos a confirmar o pagamento. Assim que estiver pago o download fica disponível.'
                                : 'Dirige-te ao fotografo, paga e mostra este ticket para ele marcar como PAID.'),
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
                        Text('Ticket: ${order.orderCode}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('Nome: ${order.customerName}'),
                        Text('Estado: ${order.status.toUpperCase()}'),
                        Text('Pagamento: ${isOnline ? 'ONLINE (STRIPE)' : 'DINHEIRO'}'),
                        Text('Total: ${order.totalAmount} EUR'),
                        if (order.productType != null) Text('Produto: ${order.productType}'),
                        if (order.deliveryType != null) Text('Entrega: ${order.deliveryType}'),
                        if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) Text('Morada: ${order.deliveryAddress}'),
                        if (order.wantsFilm) Text('Filme: +${order.filmFee}€'),
                        if (order.shippingFee > 0) Text('Envio: +${order.shippingFee}€'),
                        Text('Fotos: ${order.itemsTotal}€ | Extras: ${order.extrasTotal}€'),
                        const SizedBox(height: 8),
                        const Text('Fotos:', style: TextStyle(fontWeight: FontWeight.w700)),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: order.photos
                              .map((p) => Chip(label: Text('#${p.number} x${p.quantity}')))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (isPaid) ...[
                  const Text('Downloads', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: downloadingAll ? null : () => _downloadAllToGallery(order),
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
                                  if (!await _ensureGalleryPermission()) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Permissão para guardar fotos negada.')),
                                    );
                                    return;
                                  }
                                  setState(() => downloadingPhotoId = p.id);
                                  await _downloadPhotoToGallery(order, p);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Foto ${p.number} guardada na galeria.')),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erro no download da foto ${p.number}: $e')),
                                  );
                                } finally {
                                  if (mounted) setState(() => downloadingPhotoId = null);
                                }
                              },
                        icon: loading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
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
              if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
              return const Center(child: CircularProgressIndicator());
            }
            final o = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Status: ${o.status.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Total: ${o.totalAmount} EUR'),
                if (o.productType != null) Text('Produto: ${o.productType}'),
                if (o.deliveryType != null) Text('Entrega: ${o.deliveryType}'),
                if (o.deliveryAddress != null && o.deliveryAddress!.isNotEmpty) Text('Morada: ${o.deliveryAddress}'),
                if (o.wantsFilm) Text('Filme: +${o.filmFee}€'),
                if (o.shippingFee > 0) Text('Envio: +${o.shippingFee}€'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      o.status == 'paid'
                          ? 'Pedido pago. O download e enviado por link unico para o email do pedido.'
                          : 'A aguardar pagamento. Depois o staff envia o link por email.',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...o.photos.map((p) => ListTile(
                  title: Text('Foto ${p.number}'),
                  subtitle: Text('Quantidade: ${p.quantity}'),
                  trailing: const Icon(Icons.image_outlined),
                )),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildNavAppBar(context, 'Staff Login'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: loginCtrl, decoration: const InputDecoration(labelText: 'Email ou username', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                try {
                  final token = await ref.read(apiProvider).staffLogin(loginCtrl.text.trim(), passCtrl.text.trim());
                  ref.read(staffTokenProvider.notifier).state = token.token;
                  ref.read(staffUserProvider.notifier).state = token.user;
                  await saveStaffSession(token.token, token.user);
                  if (!context.mounted) return;
                  Navigator.pop(context, token);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro login: $e')));
                }
              },
              child: const Text('Entrar'),
            ),
          ],
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

DateTime _startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

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
  return event.eventType?.trim().isNotEmpty == true ? event.eventType!.trim() : 'Evento';
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
  final nameParts = name.split(RegExp(r'\\s+')).where((p) => p.isNotEmpty).toList();
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
    if (singleName.isNotEmpty && normalizedTeam.contains(' $singleName ')) return true;
  }
  final normalizedName = _normalizeRaw(name).trim();
  if (normalizedName.isNotEmpty && normalizedTeam.contains(' $normalizedName ')) return true;

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
  for (final key in ['total_sales', 'vendas_total', 'sales_total', 'total_vendas']) {
    final raw = meta[key];
    if (raw == null) continue;
    final value = double.tryParse(raw.toString());
    if (value != null) return value;
  }
  return 0;
}

String _initialsFromName(String? name) {
  if (name == null) return '';
  final parts = name.trim().split(RegExp(r'\\s+')).where((p) => p.isNotEmpty).toList();
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
  return text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: card);
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
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffEventDetailPage(event: event))),
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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kBrandRose),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    if (team.isNotEmpty)
                      Text('Equipa: $team', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
                    const SizedBox(height: 2),
                    Text('Tipo: $typeLabel', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
                    if (studioTime.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Estúdio: $studioTime', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
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

  void _ensureFuture(String token, {required bool assignedOnly, String? fromDate}) {
    if (_future == null || _token != token || _assignedOnly != assignedOnly || _fromDate != fromDate) {
      _token = token;
      _assignedOnly = assignedOnly;
      _fromDate = fromDate;
      _future = ref.read(apiProvider).staffEvents(token, assignedOnly: assignedOnly, fromDate: fromDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    final canSeeAllEvents = _canSeeAllEvents(user);
    final canCalendar = user.hasPermission('events.list') || user.hasPermission('events.view');
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
                  children: [Padding(padding: const EdgeInsets.all(16), child: Text('Erro: ${snap.error}'))],
                );
              }
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))],
              );
            }
            final events = _filterEventsForUser(snap.data!, user);
            if (events.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [Padding(padding: EdgeInsets.all(16), child: Text('Sem eventos'))],
              );
            }
            final eventsByDay = _eventsByDay(events);
            final selected = _selectedDay ?? _focusedDay;
            final selectedKey = _startOfDay(selected);
            final dayEvents = eventsByDay[selectedKey] ?? const <StaffEvent>[];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TableCalendar<StaffEvent>(
                  firstDay: _calendarFirstDay(events),
                  lastDay: _calendarLastDay(events),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: (day) => eventsByDay[_startOfDay(day)] ?? const <StaffEvent>[],
                  availableGestures: AvailableGestures.all,
                  pageJumpingEnabled: true,
                  headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    todayDecoration: BoxDecoration(color: Colors.orange.shade200, shape: BoxShape.circle),
                    selectedDecoration: const BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle),
                    markerDecoration: const BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return const SizedBox.shrink();
                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${events.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                Text('Eventos do dia', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (dayEvents.isEmpty)
                  const Text('Sem eventos neste dia')
                else
                  ...dayEvents.map((e) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.name),
                        subtitle: Text(_formatEventDateTime(e.eventDate, e.eventTime)),
                        onTap: user.hasPermission('events.view')
                            ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffEventDetailPage(event: e)))
                            : null,
                      )),
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

  void _ensureEventsFuture(String token, {required bool assignedOnly, String? fromDate}) {
    if (_eventsFuture == null ||
        _eventsToken != token ||
        _eventsAssignedOnly != assignedOnly ||
        _eventsFromDate != fromDate) {
      _eventsToken = token;
      _eventsAssignedOnly = assignedOnly;
      _eventsFromDate = fromDate;
      _eventsFuture = ref.read(apiProvider).staffEvents(token, assignedOnly: assignedOnly, fromDate: fromDate);
    }
  }

  void _ensurePendingOrdersFuture(String token) {
    if (_pendingOrdersFuture == null || _pendingOrdersToken != token) {
      _pendingOrdersToken = token;
      _pendingOrdersFuture = ref.read(apiProvider).staffOrdersTotal(token, status: 'pending');
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
        await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      }
      if (Platform.isAndroid) {
        await Permission.notification.request();
      }
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await ref.read(apiProvider).registerDeviceToken(
          apiToken,
          fcmToken,
          Platform.isIOS ? 'ios' : 'android',
          deviceId: await getDeviceId(),
        );
      }
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final apiToken = ref.read(staffTokenProvider);
        if (apiToken == null) return;
        await ref.read(apiProvider).registerDeviceToken(
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
    if (token == null || user == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    if (useDesktopLayout(context)) {
      return StaffDesktopShell(user: user, token: token);
    }
    final isWide = MediaQuery.of(context).size.width >= 900;
    final isPhotographer = _isPhotographerRole(user.role);
    final isStaffRole = false;
    final isAdmin = _isAdminRole(user.role);
    final canSeeAllEvents = _canSeeAllEvents(user);
    final canCalendar = user.hasPermission('events.list') || user.hasPermission('events.view');
    final now = DateTime.now();
    final fromDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (canCalendar) {
      _ensureEventsFuture(token, assignedOnly: !canSeeAllEvents, fromDate: fromDate);
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
          Text('Olá, ${user.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                                  MaterialPageRoute(builder: (_) => const StaffOrdersPage()),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Próximos 5 serviços', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (upcoming.isEmpty)
                      const Text('Sem serviços agendados')
                    else
                      ...upcoming.take(5).map((e) => _UpcomingEventCard(event: e)),
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
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffAgendaPage())),
            ),
          if (user.hasPermission('events.view') && !isStaffRole)
            _StaffMenuTile(
              title: 'Eventos',
              subtitle: isPhotographer ? 'Eventos associados' : 'Criar/editar eventos',
              icon: Icons.event,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffEventsPage())),
            ),
          if (user.hasPermission('uploads.list'))
            _StaffMenuTile(
              title: 'Uploads',
              subtitle: 'Enviar fotos para eventos',
              icon: Icons.cloud_upload,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffUploadsPage())),
            ),
          if (user.hasPermission('photos.list'))
            _StaffMenuTile(
              title: 'Fotos',
              subtitle: 'Gerir fotos e previews',
              icon: Icons.photo_library_outlined,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffPhotosPage())),
            ),
          if (user.hasPermission('orders.list'))
            _StaffMenuTile(
              title: 'Pedidos',
              subtitle: isPhotographer ? 'Aprovar pagamentos' : 'Filtrar e atualizar status',
              icon: Icons.receipt_long,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffOrdersPage())),
            ),
          _StaffMenuTile(
            title: 'Definições',
            subtitle: 'Perfil e password',
            icon: Icons.settings,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffSettingsPage())),
          ),
          if (user.hasPermission('users.list'))
            _StaffMenuTile(
              title: 'Utilizadores',
              subtitle: 'CRUD utilizadores e permissões',
              icon: Icons.manage_accounts,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffUsersPage())),
            ),
          if (user.hasPermission('clients.list'))
            _StaffMenuTile(
              title: 'Clientes',
              subtitle: 'Gerir clientes',
              icon: Icons.people_outline,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffClientsPage())),
            ),
          if (user.hasPermission('offline.export') && !isPhotographer)
            _StaffMenuTile(
              title: 'Sincronizar',
              subtitle: 'Exportar/Importar dados offline',
              icon: Icons.sync,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffSyncPage())),
            ),
        ],
      ),
    );
  }
}

class _StaffMenuTile extends StatelessWidget {
  const _StaffMenuTile({required this.title, required this.subtitle, required this.icon, required this.onTap});
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
  final Widget Function(BuildContext context, StaffUser user, String token) builder;
  final bool showSearch;
  final List<Widget> Function(BuildContext context, StaffUser user, String token)? actionsBuilder;
  final bool Function(StaffUser user)? visibleWhen;
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
  final Widget Function(BuildContext context, StaffUser user, String token)? overrideContent;
  final String? overrideTitle;
  final String? overrideSubtitle;
  final bool? overrideShowSearch;
  final List<Widget> Function(BuildContext context, StaffUser user, String token)? overrideActionsBuilder;

  @override
  ConsumerState<StaffDesktopShell> createState() => _StaffDesktopShellState();
}

class _StaffDesktopShellState extends ConsumerState<StaffDesktopShell> {
  late String _selectedId;
  final TextEditingController _searchCtrl = TextEditingController();
  final ValueNotifier<String> _searchValue = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialId ?? 'dashboard';
    readStaffLastRoute(userId: widget.user.id).then((value) {
      if (!mounted) return;
      if (value != null && value.trim().isNotEmpty) {
        setState(() => _selectedId = value);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchValue.dispose();
    super.dispose();
  }

  List<DesktopNavItem> _navItems() {
    final user = widget.user;
    return [
      DesktopNavItem(
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.grid_view_rounded,
        subtitle: 'Resumo operacional',
        builder: (context, user, token) => DesktopDashboardView(user: user, token: token, search: _searchValue),
      ),
      DesktopNavItem(
        id: 'events',
        label: 'Eventos',
        icon: Icons.event_available,
        subtitle: 'Gestao de eventos',
        showSearch: true,
        builder: (context, user, token) => DesktopEventsView(user: user, token: token, search: _searchValue),
        actionsBuilder: (context, user, token) => [
          FilledButton.icon(
            onPressed: user.hasPermission('events.create')
                ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffEventFormPage(initialEventType: 'casamento')))
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Novo evento'),
          ),
        ],
        visibleWhen: (u) => u.hasPermission('events.list') || u.hasPermission('events.view'),
      ),
      DesktopNavItem(
        id: 'services',
        label: 'Agenda',
        icon: Icons.calendar_month,
        subtitle: 'Agenda e atribuicoes',
        builder: (context, user, token) => DesktopServicesView(user: user, token: token),
        visibleWhen: (u) => u.hasPermission('events.list') || u.hasPermission('events.view'),
      ),
      DesktopNavItem(
        id: 'orders',
        label: 'Pedidos',
        icon: Icons.receipt_long,
        subtitle: 'Pagamentos e entregas',
        showSearch: true,
        builder: (context, user, token) => DesktopOrdersView(user: user, token: token, search: _searchValue),
        visibleWhen: (u) => u.hasPermission('orders.list'),
      ),
      DesktopNavItem(
        id: 'photos',
        label: 'Galerias / Fotos',
        icon: Icons.photo_library_outlined,
        subtitle: 'Conteudos e previews',
        showSearch: true,
        builder: (context, user, token) => DesktopPhotosView(user: user, token: token, search: _searchValue),
        visibleWhen: (u) => u.hasPermission('photos.list'),
      ),
      DesktopNavItem(
        id: 'clients',
        label: 'Clientes',
        icon: Icons.people_outline,
        subtitle: 'Base de clientes',
        showSearch: true,
        builder: (context, user, token) => DesktopClientsView(user: user, token: token, search: _searchValue),
        visibleWhen: (u) => u.hasPermission('clients.list'),
      ),
      DesktopNavItem(
        id: 'payments',
        label: 'Pagamentos',
        icon: Icons.payments_outlined,
        subtitle: 'Transacoes e reconciliacao',
        builder: (context, user, token) => DesktopPaymentsView(user: user, token: token),
      ),
      DesktopNavItem(
        id: 'sync',
        label: 'Sincronizacao',
        icon: Icons.sync,
        subtitle: 'Offline e importacao',
        builder: (context, user, token) => DesktopSyncView(user: user, token: token),
        visibleWhen: (u) => u.hasPermission('offline.export'),
      ),
      DesktopNavItem(
        id: 'reports',
        label: 'Relatorios',
        icon: Icons.bar_chart,
        subtitle: 'Analise e metricas',
        builder: (context, user, token) => DesktopReportsView(user: user, token: token),
      ),
      DesktopNavItem(
        id: 'settings',
        label: 'Definicoes',
        icon: Icons.settings,
        subtitle: 'Perfil e configuracoes',
        builder: (context, user, token) => DesktopSettingsView(user: user, token: token),
      ),
    ].where((item) => item.visibleWhen?.call(user) ?? true).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _navItems();
    final current = items.firstWhere((i) => i.id == _selectedId, orElse: () => items.first);
    if (current.id != _selectedId) {
      _selectedId = current.id;
    }
    final overrideKey = widget.initialId ?? 'dashboard';
    final useOverride = widget.overrideContent != null && _selectedId == overrideKey;
    final topTitle = useOverride ? (widget.overrideTitle ?? current.label) : current.label;
    final topSubtitle = useOverride ? (widget.overrideSubtitle ?? current.subtitle) : current.subtitle;
    final topSearch = useOverride ? (widget.overrideShowSearch ?? false) : current.showSearch;
    final topActions = useOverride
        ? (widget.overrideActionsBuilder?.call(context, widget.user, widget.token) ?? const <Widget>[])
        : (current.actionsBuilder?.call(context, widget.user, widget.token) ?? const <Widget>[]);

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
                setState(() {
                  _selectedId = id;
                  _searchCtrl.clear();
                  _searchValue.value = '';
                });
                saveStaffLastRoute(id, userId: widget.user.id);
              },
            ),
            Expanded(
              child: Column(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.items,
    required this.selectedId,
    required this.onSelect,
    required this.user,
  });

  final List<DesktopNavItem> items;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final StaffUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kDeskSidebarWidth,
      decoration: BoxDecoration(
        color: kDeskSurface,
        border: Border(
          right: BorderSide(color: kBrandRose.withOpacity(0.2)),
        ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? kBrandRose.withOpacity(0.16) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? kBrandRose.withOpacity(0.6) : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(item.icon, color: selected ? kBrandRose : kDeskMuted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  color: selected ? kBrandRose : Colors.white.withOpacity(0.8),
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
              border: Border(top: BorderSide(color: kBrandRose.withOpacity(0.2))),
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
                      Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      Text(user.role.toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
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
  });

  final String title;
  final String? subtitle;
  final bool showSearch;
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final List<Widget> actions;
  final StaffUser user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(kDeskGutter, 16, kDeskGutter, 12),
      decoration: BoxDecoration(
        color: kDeskSurface,
        border: Border(
          bottom: BorderSide(color: kBrandRose.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
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
                    borderSide: BorderSide(color: kBrandRose.withOpacity(0.4)),
                  ),
                ),
              ),
            ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 16),
            ...actions.map((w) => Padding(padding: const EdgeInsets.only(right: 8), child: w)),
          ],
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Terminar sessao',
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
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
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
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
                Text(title, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              ],
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
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _DeskTableColumn {
  const _DeskTableColumn(this.label, {this.flex = 1, this.align = CrossAxisAlignment.start});
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6), letterSpacing: 0.6),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      children: [
                        cells[i],
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class DesktopDashboardView extends ConsumerWidget {
  const DesktopDashboardView({super.key, required this.user, required this.token, required this.search});
  final StaffUser user;
  final String token;
  final ValueListenable<String> search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSeeAllEvents = _canSeeAllEvents(user);
    final fromDate = DateTime.now();
    final fromDateParam =
        '${fromDate.year.toString().padLeft(4, '0')}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
    final eventsFuture = ref.read(apiProvider).staffEvents(token, assignedOnly: !canSeeAllEvents, fromDate: fromDateParam);
    final ordersFuture = ref.read(apiProvider).staffOrdersList(token, status: 'pending');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDeskGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<List<StaffEvent>>(
            future: eventsFuture,
            builder: (context, snap) {
              final events = snap.data ?? const <StaffEvent>[];
              final upcoming = _upcomingEvents(_filterEventsForUser(events, user));
              return LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width > 1200 ? 4 : width > 900 ? 3 : 2;
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
                      child: _DeskKpiCard(
                        title: 'Pedidos pendentes',
                        value: '—',
                        subtitle: 'A confirmar',
                        icon: Icons.receipt_long,
                        color: Colors.orangeAccent,
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
                    SizedBox(
                      width: cardWidth,
                      child: _DeskKpiCard(
                        title: 'Fotos por tratar',
                        value: '${(events.length * 12).clamp(4, 128)}',
                        subtitle: 'Estimativa',
                        icon: Icons.photo_library,
                        color: Colors.pinkAccent,
                      ),
                    ),
                  ],
                );
              });
            },
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DeskSectionHeader('Atividade recente'),
                    const SizedBox(height: 10),
                    _DeskCard(
                      child: Column(
                        children: [
                          _DesktopActivityRow(title: 'Pagamento confirmado', subtitle: 'Pedido S59-43MZX', time: 'agora'),
                          _DesktopActivityRow(title: 'Upload concluido', subtitle: 'Evento Casamento Silva', time: 'há 1h'),
                          _DesktopActivityRow(title: 'Servico agendado', subtitle: 'Batizado 14/04', time: 'há 3h'),
                          _DesktopActivityRow(title: 'Cliente criou pedido', subtitle: 'Pedido S59-43MZW', time: 'ontem'),
                        ],
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
                        final rows = visible.isNotEmpty
                            ? visible
                                .map((o) => List<Widget>.of([
                                      Text(o.orderCode, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Text(o.customerName),
                                      _DeskStatusBadge(o.status.toUpperCase(), color: Colors.orangeAccent),
                                      Text('€${(o.totalAmount ?? 0).toStringAsFixed(2)}'),
                                    ]))
                                .toList()
                            : [
                                [
                                  const Text('S59-XX12'),
                                  const Text('Maria Costa'),
                                  const _DeskStatusBadge('PENDENTE', color: Colors.orangeAccent),
                                  const Text('€85.00'),
                                ],
                                [
                                  const Text('S59-XX13'),
                                  const Text('Joao Silva'),
                                  const _DeskStatusBadge('PENDENTE', color: Colors.orangeAccent),
                                  const Text('€50.00'),
                                ],
                              ];
                        return _DeskTable(
                          columns: const [
                            _DeskTableColumn('Pedido', flex: 2),
                            _DeskTableColumn('Cliente', flex: 3),
                            _DeskTableColumn('Estado', flex: 2),
                            _DeskTableColumn('Total', flex: 2, align: CrossAxisAlignment.end),
                          ],
                          rows: rows,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DeskSectionHeader('Proximos eventos'),
                    const SizedBox(height: 10),
                    FutureBuilder<List<StaffEvent>>(
                      future: eventsFuture,
                      builder: (context, snap) {
                        final events = snap.data ?? const <StaffEvent>[];
                        final upcoming = _upcomingEvents(_filterEventsForUser(events, user)).take(5).toList();
                        return _DeskCard(
                          child: Column(
                            children: [
                              if (upcoming.isEmpty) ...[
                                _DesktopEventRow(
                                  title: 'Casamento Costa',
                                  subtitle: '14/04/2026 • 16:00',
                                  badge: 'Agendado',
                                ),
                                _DesktopEventRow(
                                  title: 'Batizado Lima',
                                  subtitle: '21/04/2026 • 10:00',
                                  badge: 'Confirmado',
                                ),
                              ] else ...[
                                ...upcoming.map((e) => _DesktopEventRow(
                                      title: e.name.isNotEmpty ? e.name : 'Evento ${e.id}',
                                      subtitle: _formatEventDateTime(e.eventDate, e.eventTime),
                                      badge: _eventTypeLabel(e),
                                    )),
                              ],
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
                            children: const [
                              _DeskStatusBadge('ONLINE', color: Colors.lightGreenAccent),
                              SizedBox(width: 10),
                              Text('Sincronizacao ativa'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Ultima sync: há 2 minutos', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                          const SizedBox(height: 8),
                          Text('Pendentes: 0 uploads • 1 pedido offline', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _DeskSectionHeader('Resumo mensal'),
                    const SizedBox(height: 10),
                    _DeskCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Vendas totais', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                          const SizedBox(height: 6),
                          const Text('€4 280', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(
                            children: const [
                              Expanded(child: Text('Eventos: 12')),
                              Expanded(child: Text('Pedidos pagos: 86')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopActivityRow extends StatelessWidget {
  const _DesktopActivityRow({required this.title, required this.subtitle, required this.time});
  final String title;
  final String subtitle;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: kBrandRose, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
          Text(time, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
        ],
      ),
    );
  }
}

class _DesktopEventRow extends StatelessWidget {
  const _DesktopEventRow({required this.title, required this.subtitle, required this.badge});
  final String title;
  final String subtitle;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
          _DeskStatusBadge(badge, color: kBrandRose),
        ],
      ),
    );
  }
}

class DesktopEventsView extends ConsumerStatefulWidget {
  const DesktopEventsView({super.key, required this.user, required this.token, required this.search});
  final StaffUser user;
  final String token;
  final ValueListenable<String> search;

  @override
  ConsumerState<DesktopEventsView> createState() => _DesktopEventsViewState();
}

class _DesktopEventsViewState extends ConsumerState<DesktopEventsView> {
  String _eventType = '';
  Future<List<StaffEvent>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(apiProvider).staffEvents(
          widget.token,
          eventType: _eventType.isEmpty ? null : _eventType,
          assignedOnly: !_canSeeAllEvents(widget.user),
        );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDeskGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DeskStatusFilterChip(
                label: 'Todos',
                selected: _eventType.isEmpty,
                onTap: () => setState(() {
                  _eventType = '';
                  _reload();
                }),
              ),
              const SizedBox(width: 8),
              _DeskStatusFilterChip(
                label: 'Casamento',
                selected: _eventType == 'casamento',
                onTap: () => setState(() {
                  _eventType = 'casamento';
                  _reload();
                }),
              ),
              const SizedBox(width: 8),
              _DeskStatusFilterChip(
                label: 'Batizado',
                selected: _eventType == 'batizado',
                onTap: () => setState(() {
                  _eventType = 'batizado';
                  _reload();
                }),
              ),
              const Spacer(),
              OutlinedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('Atualizar')),
            ],
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<String>(
            valueListenable: widget.search,
            builder: (context, value, _) {
              return FutureBuilder<List<StaffEvent>>(
                future: _future,
                builder: (context, snap) {
                  final events = snap.data ?? const <StaffEvent>[];
                  final filtered = _filterEventsForUser(events, widget.user);
                  final search = value.trim().toLowerCase();
                  final visible = search.isEmpty ? filtered : filtered.where((e) => _eventSearchBlob(e).contains(search)).toList();
                  final rows = visible.isNotEmpty
                      ? visible
                          .map((e) => [
                                Text(_formatEventDateTime(e.eventDate, e.eventTime), style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(_eventTypeLabel(e)),
                                Text(_displayReportNumber(e) ?? '—'),
                                Text(_eventTeamLabel(e).isEmpty ? '—' : _eventTeamLabel(e)),
                                Text('${_eventPhotoCount(e)}'),
                                Text('€${_eventSalesTotal(e).toStringAsFixed(0)}'),
                                _DeskStatusBadge('Ativo', color: Colors.lightGreenAccent),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: widget.user.hasPermission('events.view')
                                          ? () => Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => StaffEventDetailPage(event: e)),
                                              )
                                          : null,
                                      child: const Text('Detalhe'),
                                    ),
                                    if (widget.user.hasPermission('events.update')) ...[
                                      const SizedBox(width: 4),
                                      TextButton(
                                        onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => StaffEventStaffPage(event: e)),
                                            ),
                                        child: const Text('Equipe'),
                                      ),
                                    ],
                                  ],
                                ),
                              ])
                          .toList()
                      : [
                          [
                            const Text('Sem resultados'),
                            const Text('—'),
                            const Text('—'),
                            const Text('—'),
                            const Text('—'),
                            const Text('—'),
                            const _DeskStatusBadge('—'),
                            const SizedBox.shrink(),
                          ],
                        ];
                  return _DeskTable(
                    columns: const [
                      _DeskTableColumn('Data', flex: 2),
                      _DeskTableColumn('Tipo'),
                      _DeskTableColumn('Relatorio'),
                      _DeskTableColumn('Equipa', flex: 2),
                      _DeskTableColumn('Fotos'),
                      _DeskTableColumn('Vendas'),
                      _DeskTableColumn('Estado'),
                      _DeskTableColumn('Acoes'),
                    ],
                    rows: rows,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DeskStatusFilterChip extends StatelessWidget {
  const _DeskStatusFilterChip({required this.label, required this.selected, required this.onTap});
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
          border: Border.all(color: selected ? kBrandRose : kBrandRose.withOpacity(0.2)),
        ),
        child: Text(label, style: TextStyle(color: selected ? kBrandRose : Colors.white.withOpacity(0.7))),
      ),
    );
  }
}

class DesktopOrdersView extends ConsumerStatefulWidget {
  const DesktopOrdersView({super.key, required this.user, required this.token, required this.search});
  final StaffUser user;
  final String token;
  final ValueListenable<String> search;

  @override
  ConsumerState<DesktopOrdersView> createState() => _DesktopOrdersViewState();
}

class _DesktopOrdersViewState extends ConsumerState<DesktopOrdersView> {
  String _status = '';
  Future<List<OrderListItem>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(apiProvider).staffOrdersList(
          widget.token,
          status: _status,
        );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDeskGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DeskStatusFilterChip(
                label: 'Todos',
                selected: _status.isEmpty,
                onTap: () => setState(() {
                  _status = '';
                  _reload();
                }),
              ),
              const SizedBox(width: 8),
              _DeskStatusFilterChip(
                label: 'Pendentes',
                selected: _status == 'pending',
                onTap: () => setState(() {
                  _status = 'pending';
                  _reload();
                }),
              ),
              const SizedBox(width: 8),
              _DeskStatusFilterChip(
                label: 'Pagos',
                selected: _status == 'paid',
                onTap: () => setState(() {
                  _status = 'paid';
                  _reload();
                }),
              ),
              const SizedBox(width: 8),
              _DeskStatusFilterChip(
                label: 'Entregues',
                selected: _status == 'delivered',
                onTap: () => setState(() {
                  _status = 'delivered';
                  _reload();
                }),
              ),
              const Spacer(),
              OutlinedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('Atualizar')),
            ],
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<String>(
            valueListenable: widget.search,
            builder: (context, value, _) {
              return FutureBuilder<List<OrderListItem>>(
                future: _future,
                builder: (context, snap) {
                  final orders = snap.data ?? const <OrderListItem>[];
                  final query = value.trim().toLowerCase();
                  final visible = query.isEmpty
                      ? orders
                      : orders
                          .where((o) => o.orderCode.toLowerCase().contains(query) || o.customerName.toLowerCase().contains(query))
                          .toList();
                  final rows = visible.isNotEmpty
                      ? visible
                          .map((o) => [
                                Text(o.orderCode, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(o.customerName),
                                Text(o.eventName ?? '—'),
                                _DeskStatusBadge(o.status.toUpperCase(),
                                    color: o.status == 'paid'
                                        ? Colors.lightGreenAccent
                                        : o.status == 'pending'
                                            ? Colors.orangeAccent
                                            : Colors.lightBlueAccent),
                                Text('€${(o.totalAmount ?? 0).toStringAsFixed(2)}'),
                              ])
                          .toList()
                      : [
                          [
                            const Text('S59-XY01'),
                            const Text('Joana Pinto'),
                            const Text('Casamento'),
                            const _DeskStatusBadge('PENDENTE', color: Colors.orangeAccent),
                            const Text('€65.00'),
                          ],
                        ];
                  return _DeskTable(
                    columns: const [
                      _DeskTableColumn('Pedido', flex: 2),
                      _DeskTableColumn('Cliente', flex: 2),
                      _DeskTableColumn('Evento', flex: 2),
                      _DeskTableColumn('Estado', flex: 2),
                      _DeskTableColumn('Total', flex: 1, align: CrossAxisAlignment.end),
                    ],
                    rows: rows,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class DesktopPhotosView extends StatelessWidget {
  const DesktopPhotosView({super.key, required this.user, required this.token, required this.search});
  final StaffUser user;
  final String token;
  final ValueListenable<String> search;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDeskGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeskSectionHeader('Galerias recentes'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width > 1200 ? 4 : width > 900 ? 3 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.4,
                ),
                itemCount: 8,
                itemBuilder: (context, index) {
                  return _DeskCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 90,
                          decoration: BoxDecoration(
                            color: kDeskCardAlt,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(child: Icon(Icons.photo, size: 32, color: kDeskMuted)),
                        ),
                        const SizedBox(height: 10),
                        Text('Evento ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('250 fotos • 14/04/2026', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class DesktopClientsView extends StatelessWidget {
  const DesktopClientsView({super.key, required this.user, required this.token, required this.search});
  final StaffUser user;
  final String token;
  final ValueListenable<String> search;

  @override
  Widget build(BuildContext context) {
    final rows = [
      [
        const Text('Maria Costa'),
        const Text('maria@email.com'),
        const Text('+351 912 000 000'),
        const _DeskStatusBadge('ATIVO', color: Colors.lightGreenAccent),
      ],
      [
        const Text('Joao Silva'),
        const Text('joao@email.com'),
        const Text('+351 913 000 000'),
        const _DeskStatusBadge('ATIVO', color: Colors.lightGreenAccent),
      ],
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDeskGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeskSectionHeader('Clientes'),
          const SizedBox(height: 12),
          _DeskTable(
            columns: const [
              _DeskTableColumn('Cliente', flex: 2),
              _DeskTableColumn('Email', flex: 2),
              _DeskTableColumn('Telefone', flex: 2),
              _DeskTableColumn('Estado', flex: 1),
            ],
            rows: rows,
          ),
        ],
      ),
    );
  }
}

class DesktopPaymentsView extends StatelessWidget {
  const DesktopPaymentsView({super.key, required this.user, required this.token});
  final StaffUser user;
  final String token;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDeskGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeskSectionHeader('Pagamentos recentes'),
          const SizedBox(height: 12),
          _DeskTable(
            columns: const [
              _DeskTableColumn('Referencia', flex: 2),
              _DeskTableColumn('Cliente', flex: 2),
              _DeskTableColumn('Metodo'),
              _DeskTableColumn('Estado'),
              _DeskTableColumn('Valor', flex: 1, align: CrossAxisAlignment.end),
            ],
            rows: const [
              [
                Text('pi_3T...'),
                Text('Maria Costa'),
                Text('Cartao'),
                _DeskStatusBadge('Pago', color: Colors.lightGreenAccent),
                Text('€85.00'),
              ],
              [
                Text('pi_4A...'),
                Text('Joao Silva'),
                Text('MB WAY'),
                _DeskStatusBadge('Pendente', color: Colors.orangeAccent),
                Text('€50.00'),
              ],
            ],
          ),
        ],
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeskSectionHeader('Sincronizacao offline'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DeskCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Estado', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          _DeskStatusBadge('ONLINE', color: Colors.lightGreenAccent),
                          SizedBox(width: 8),
                          Text('Sincronizacao ativa'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Ultimo sync: há 2 minutos', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.file_download), label: const Text('Exportar')),
                          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.file_upload), label: const Text('Importar')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DeskCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pendentes', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Pedidos offline: 1', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                      const SizedBox(height: 6),
                      Text('Uploads em fila: 0', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                      const SizedBox(height: 6),
                      Text('Erro recente: nenhum', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DesktopReportsView extends StatelessWidget {
  const DesktopReportsView({super.key, required this.user, required this.token});
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
              Expanded(child: _DeskKpiCard(title: 'Vendas', value: '€12 400', subtitle: 'Ultimos 30 dias', icon: Icons.insights)),
              const SizedBox(width: 16),
              Expanded(child: _DeskKpiCard(title: 'Pedidos', value: '214', subtitle: 'Ultimos 30 dias', icon: Icons.receipt_long)),
              const SizedBox(width: 16),
              Expanded(child: _DeskKpiCard(title: 'Fotos', value: '6 820', subtitle: 'Entregues', icon: Icons.photo_library)),
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
              child: const Center(child: Text('Grafico de vendas (placeholder)')),
            ),
          ),
        ],
      ),
    );
  }
}

class DesktopSettingsView extends StatelessWidget {
  const DesktopSettingsView({super.key, required this.user, required this.token});
  final StaffUser user;
  final String token;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDeskGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeskSectionHeader('Definicoes do perfil'),
          const SizedBox(height: 12),
          _DeskCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Nome'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Email'))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Telefone'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Funcao'))),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(onPressed: () {}, child: const Text('Guardar alteracoes')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DesktopServicesView extends ConsumerStatefulWidget {
  const DesktopServicesView({super.key, required this.user, required this.token});
  final StaffUser user;
  final String token;

  @override
  ConsumerState<DesktopServicesView> createState() => _DesktopServicesViewState();
}

class _DesktopServicesViewState extends ConsumerState<DesktopServicesView> {
  Future<List<StaffEvent>>? _future;
  String? _token;
  bool? _assignedOnly;
  String? _fromDate;
  DateTime _focusedDay = _startOfDay(DateTime.now());
  DateTime? _selectedDay;

  void _ensureFuture(String token, {required bool assignedOnly, String? fromDate}) {
    if (_future == null || _token != token || _assignedOnly != assignedOnly || _fromDate != fromDate) {
      _token = token;
      _assignedOnly = assignedOnly;
      _fromDate = fromDate;
      _future = ref.read(apiProvider).staffEvents(token, assignedOnly: assignedOnly, fromDate: fromDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCalendar = widget.user.hasPermission('events.list') || widget.user.hasPermission('events.view');
    final canSeeAllEvents = _canSeeAllEvents(widget.user);
    final now = DateTime.now();
    final fromDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (canCalendar) {
      _ensureFuture(widget.token, assignedOnly: !canSeeAllEvents, fromDate: fromDate);
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
                    child: SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
                  );
                }
                final events = _filterEventsForUser(snap.data ?? const <StaffEvent>[], widget.user);
                if (events.isEmpty) {
                  return const _DeskCard(child: Text('Sem eventos disponíveis.'));
                }
                final eventsByDay = _eventsByDay(events);
                final selected = _selectedDay ?? _focusedDay;
                final selectedKey = _startOfDay(selected);
                final dayEvents = eventsByDay[selectedKey] ?? const <StaffEvent>[];

                final weekStart = selectedKey.subtract(Duration(days: selectedKey.weekday - 1));
                final weekEnd = weekStart.add(const Duration(days: 6));
                final weekCount = events.where((e) {
                  final date = _parseEventDate(e.eventDate);
                  if (date == null) return false;
                  return !date.isBefore(weekStart) && !date.isAfter(weekEnd);
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
                              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                              eventLoader: (day) => eventsByDay[_startOfDay(day)] ?? const <StaffEvent>[],
                              availableGestures: AvailableGestures.all,
                              pageJumpingEnabled: true,
                              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                              calendarStyle: CalendarStyle(
                                outsideDaysVisible: false,
                                todayDecoration: BoxDecoration(color: kBrandRose.withOpacity(0.4), shape: BoxShape.circle),
                                selectedDecoration: const BoxDecoration(color: kBrandRose, shape: BoxShape.circle),
                                markerDecoration: const BoxDecoration(color: kBrandRose, shape: BoxShape.circle),
                              ),
                              calendarBuilders: CalendarBuilders(
                                markerBuilder: (context, date, events) {
                                  if (events.isEmpty) return const SizedBox.shrink();
                                  return Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: kBrandRose,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${events.length}',
                                        style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
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
                              child: Text('Eventos do dia', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                            ),
                            const SizedBox(height: 8),
                            if (dayEvents.isEmpty)
                              const Text('Sem eventos neste dia')
                            else
                              ...dayEvents.map((e) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(e.name),
                                    subtitle: Text(_formatEventDateTime(e.eventDate, e.eventTime)),
                                    trailing: Wrap(
                                      spacing: 8,
                                      children: [
                                        if (widget.user.hasPermission('events.view'))
                                          TextButton(
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => StaffEventDetailPage(event: e)),
                                            ),
                                            child: const Text('Detalhe'),
                                          ),
                                        if (widget.user.hasPermission('events.update'))
                                          TextButton(
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => StaffEventStaffPage(event: e)),
                                            ),
                                            child: const Text('Equipe'),
                                          ),
                                      ],
                                    ),
                                  )),
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
                            const Text('Resumo da agenda', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 10),
                            Text('Servicos esta semana: $weekCount', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                            const SizedBox(height: 6),
                            Text('Eventos totais: ${events.length}', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                            const SizedBox(height: 6),
                            Text('Selecionado: ${_formatEventDateTime(selectedKey.toIso8601String(), '')}'.split(' ').first,
                                style: TextStyle(color: Colors.white.withOpacity(0.6))),
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
  String _eventType = 'casamento';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro a gerar PDF: $e')),
      );
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
    _future = ref.read(apiProvider).staffEvents(
      token,
      eventType: _eventType,
      assignedOnly: assignedOnly,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (_future == null || _lastToken != token || _lastEventType != _eventType) {
      _lastToken = token;
      _lastEventType = _eventType;
      final assignedOnly = user.role != 'admin';
      _future = ref.read(apiProvider).staffEvents(
        token,
        eventType: _eventType,
        assignedOnly: assignedOnly,
      );
    }

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
                  MaterialPageRoute(builder: (_) => StaffEventFormPage(initialEventType: _eventType)),
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
                  children: [Padding(padding: const EdgeInsets.all(16), child: Text('Erro: ${snap.error}'))],
                );
              }
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))],
              );
            }
            final events = _orderEvents(_filterEventsForUser(snap.data!, user));
            if (events.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [Padding(padding: EdgeInsets.all(16), child: Text('Sem eventos'))],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: events.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
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
                              label: const Text('CASAMENTO'),
                              selected: _eventType == 'casamento',
                              onSelected: (v) {
                                if (!v) return;
                                setState(() => _eventType = 'casamento');
                                _reload();
                              },
                              selectedColor: kBrandRose,
                              labelStyle: TextStyle(color: _eventType == 'casamento' ? kBrandBlack : kBrandRose),
                              side: BorderSide(color: kBrandRose.withOpacity(0.8)),
                            ),
                            ChoiceChip(
                              label: const Text('BATIZADO'),
                              selected: _eventType == 'batizado',
                              onSelected: (v) {
                                if (!v) return;
                                setState(() => _eventType = 'batizado');
                                _reload();
                              },
                              selectedColor: kBrandRose,
                              labelStyle: TextStyle(color: _eventType == 'batizado' ? kBrandBlack : kBrandRose),
                              side: BorderSide(color: kBrandRose.withOpacity(0.8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Atualizar'),
                            ),
                            if (isWide && user.hasPermission('events.create'))
                              FilledButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StaffEventFormPage(initialEventType: _eventType),
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
                final e = events[i - 1];
                final report = _displayReportNumber(e);
                final subtitleParts = <String>[
                  if (report != null && report.isNotEmpty) 'Nº $report',
                  if (e.eventDate.isNotEmpty) _formatEventDateTime(e.eventDate, e.eventTime),
                  if (e.location != null && e.location!.isNotEmpty) e.location!,
                ];
                final subtitle = subtitleParts.isEmpty ? '' : subtitleParts.join(' • ');
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: InkWell(
                    onTap: user.hasPermission('events.view')
                        ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffEventDetailPage(event: e)))
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(subtitle, style: TextStyle(color: kBrandRose.withOpacity(0.8))),
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
                                    final url = ref.read(apiProvider).publicQrUrl(e.qrToken!);
                                    showQrDialog(context, title: 'QR Code do Evento', url: url);
                                  },
                                ),
                              if (user.hasPermission('events.update'))
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => StaffEventFormPage(event: e)),
                                    );
                                    _reload();
                                  },
                                ),
                              if (user.hasPermission('events.delete'))
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final ok = await _confirm(context, 'Apagar evento?', 'Isto remove fotos e uploads.');
                                    if (!ok) return;
                                    await ref.read(apiProvider).deleteEvent(token, e.id);
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
    final token = ref.watch(staffTokenProvider);
    if (useDesktopLayout(context) && user != null && token != null) {
      return StaffDesktopShell(
        user: user,
        token: token,
        initialId: 'events',
        overrideTitle: 'Detalhe do Evento',
        overrideSubtitle: event.name,
        overrideShowSearch: false,
        overrideContent: (ctx, u, t) => DesktopEventDetailView(event: event),
      );
    }
    return Scaffold(
      appBar: buildNavAppBar(context, 'Detalhe do Evento'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(event.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_displayReportNumber(event) != null) Text('Nº reportagem: ${_displayReportNumber(event)}'),
          Text('Data: ${_formatEventDateTime(event.eventDate, event.eventTime)}'),
          Text('Tipo: ${event.eventType ?? '-'}'),
          if (event.basePrice != null) Text('Preço base: ${event.basePrice}'),
          Text('Preço por foto: ${event.pricePerPhoto}'),
          if (event.accessPin != null && event.accessPin!.isNotEmpty) Text('PIN: ${event.accessPin}'),
          if (event.notes != null && event.notes!.isNotEmpty) Text('Notas: ${event.notes}'),
          const SizedBox(height: 12),
          if (user != null && user.hasPermission('events.update'))
            FilledButton.tonal(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StaffEventStaffPage(event: event)),
                );
              },
              child: const Text('Gerir staff do evento'),
            ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: token == null
                ? null
                : () async {
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro a gerar PDF: $e')),
                      );
                    } finally {
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
            child: const Text('PDF'),
          ),
          const SizedBox(height: 12),
          if (meta.isNotEmpty) ...[
            const Text('Detalhes', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...meta.entries.map((e) => Text('${_prettyMetaKey(e.key)}: ${e.value}')),
          ],
        ],
      ),
    );
  }
}

class DesktopEventDetailView extends ConsumerWidget {
  const DesktopEventDetailView({super.key, required this.event});
  final StaffEvent event;

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
          _DeskCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_displayReportNumber(event) != null) Text('Nº reportagem: ${_displayReportNumber(event)}'),
                Text('Data: ${_formatEventDateTime(event.eventDate, event.eventTime)}'),
                Text('Tipo: ${event.eventType ?? '-'}'),
                if (event.basePrice != null) Text('Preço base: ${event.basePrice}'),
                Text('Preço por foto: ${event.pricePerPhoto}'),
                if (event.accessPin != null && event.accessPin!.isNotEmpty) Text('PIN: ${event.accessPin}'),
                if (event.notes != null && event.notes!.isNotEmpty) Text('Notas: ${event.notes}'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (user != null && user.hasPermission('events.update'))
                      FilledButton.tonal(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => StaffEventStaffPage(event: event)),
                          );
                        },
                        child: const Text('Gerir staff do evento'),
                      ),
                    FilledButton.tonal(
                      onPressed: token == null
                          ? null
                          : () async {
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erro a gerar PDF: $e')),
                                );
                              } finally {
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                      child: const Text('PDF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _DeskSectionHeader('Detalhes'),
          const SizedBox(height: 12),
          _DeskCard(
            child: meta.isEmpty
                ? const Text('Sem detalhes adicionais.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: meta.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('${entry.key}: ${entry.value}'),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
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

  @override
  void initState() {
    super.initState();
    reportNumberCtrl = TextEditingController(
      text: widget.event != null ? (_displayReportNumber(widget.event!) ?? '') : '',
    );
    basePriceCtrl = TextEditingController(
      text: widget.event?.basePrice != null ? widget.event!.basePrice!.toString() : '0',
    );
    dateCtrl = TextEditingController(text: widget.event?.eventDate ?? '');
    timeCtrl = TextEditingController(text: widget.event?.eventTime ?? '');
    pinCtrl = TextEditingController(
      text: widget.event?.accessPin?.isNotEmpty == true ? widget.event!.accessPin! : '',
    );
    priceCtrl = TextEditingController(text: widget.event?.pricePerPhoto.toString() ?? '5');
    notesCtrl = TextEditingController(text: widget.event?.notes ?? '');
    eventType = widget.event?.eventType ?? widget.initialEventType ?? '';
    isLocked = widget.event?.isLocked ?? false;
    final meta = widget.event?.eventMeta ?? {};
    noivoNomeCtrl = TextEditingController(text: meta['noivo_nome']?.toString() ?? '');
    noivaNomeCtrl = TextEditingController(text: meta['noiva_nome']?.toString() ?? '');
    noivoContactoCtrl = TextEditingController(text: meta['noivo_contacto']?.toString() ?? '');
    noivaContactoCtrl = TextEditingController(text: meta['noiva_contacto']?.toString() ?? '');
    noivoProfissaoCtrl = TextEditingController(text: meta['noivo_profissao']?.toString() ?? '');
    noivaProfissaoCtrl = TextEditingController(text: meta['noiva_profissao']?.toString() ?? '');
    noivoMoradaCtrl = TextEditingController(text: meta['noivo_morada']?.toString() ?? '');
    noivaMoradaCtrl = TextEditingController(text: meta['noiva_morada']?.toString() ?? '');
    noivoInstagramCtrl = TextEditingController(
      text: meta['noivo_instagram']?.toString() ?? meta['instagram_noivos']?.toString() ?? '',
    );
    noivaInstagramCtrl = TextEditingController(text: meta['noiva_instagram']?.toString() ?? '');
    noivoFilhoDe1Ctrl = TextEditingController(text: meta['noivo_filho_de_1']?.toString() ?? '');
    noivoFilhoDe2Ctrl = TextEditingController(text: meta['noivo_filho_de_2']?.toString() ?? '');
    noivaFilhoDe1Ctrl = TextEditingController(text: meta['noiva_filho_de_1']?.toString() ?? '');
    noivaFilhoDe2Ctrl = TextEditingController(text: meta['noiva_filho_de_2']?.toString() ?? '');
    noivoCoordenadasCtrl = TextEditingController(text: meta['noivo_coordenadas']?.toString() ?? '');
    noivaCoordenadasCtrl = TextEditingController(text: meta['noiva_coordenadas']?.toString() ?? '');
    missaHoraCtrl = TextEditingController(text: meta['missa_hora']?.toString() ?? '');
    igrejaTipo = _normalizeCerimoniaTipo(meta['igreja_local']?.toString());
    igrejaLocalidadeCtrl = TextEditingController(text: _resolveCerimoniaLocal(meta));
    refeicaoTipo = _normalizeRefeicaoTipo(meta['quinta_local']?.toString());
    almocoLocalidadeCtrl = TextEditingController(text: _resolveRefeicaoLocal(meta));
    numeroConvidadosCtrl = TextEditingController(text: meta['numero_convidados']?.toString() ?? '');
    instagramPaisCtrl = TextEditingController(text: meta['instagram_pais']?.toString() ?? '');
    casaNoivoChegadaCtrl = TextEditingController(text: meta['casa_noivo_chegada']?.toString() ?? '');
    casaNoivoSaidaCtrl = TextEditingController(text: meta['casa_noivo_saida']?.toString() ?? '');
    casaNoivaChegadaCtrl = TextEditingController(text: meta['casa_noiva_chegada']?.toString() ?? '');
    casaNoivaSaidaCtrl = TextEditingController(text: meta['casa_noiva_saida']?.toString() ?? '');
    dataEntregaCtrl = TextEditingController(text: meta['data_entrega']?.toString() ?? '');
    equipaTrabalhoCtrl = TextEditingController(text: meta['equipa_de_trabalho']?.toString() ?? '');
    teamCountCtrl = TextEditingController(text: meta['servico_num_profissionais']?.toString() ?? '');
    bebeNomeCtrl = TextEditingController(text: meta['bebe_nome']?.toString() ?? '');
    paiNomeCtrl = TextEditingController(text: meta['pai_nome']?.toString() ?? '');
    maeNomeCtrl = TextEditingController(text: meta['mae_nome']?.toString() ?? '');
    padrinhoNomeCtrl = TextEditingController(text: meta['padrinho_nome']?.toString() ?? '');
    madrinhaNomeCtrl = TextEditingController(text: meta['madrinha_nome']?.toString() ?? '');
    contactoPaisCtrl = TextEditingController(text: meta['contacto_pais']?.toString() ?? '');
    batizadoMoradaCtrl = TextEditingController(text: meta['morada']?.toString() ?? '');
    servicoTelaCtrl = TextEditingController(text: meta['servico_tela']?.toString() ?? '');
    servicoUsbCtrl = TextEditingController(text: meta['servico_usb']?.toString() ?? '');
    servicoCondicoesCtrl = TextEditingController(text: meta['servico_condicoes_minimas']?.toString() ?? '');
    servicoMusicasCtrl = TextEditingController(text: meta['servico_musicas']?.toString() ?? '');
    servicoExtrasCtrl = TextEditingController(text: meta['servico_extras']?.toString() ?? '');
    servicoSaveTheDate = _metaFlag(meta, 'servico_save_the_date');
    servicoFotosLoveStory = _metaFlag(meta, 'servico_fotos_love_story');
    servicoVideoLoveStory = _metaFlag(meta, 'servico_video_love_story');
    servicoProjectarLoveStory = _metaFlag(meta, 'servico_projectar_love_story');
    servicoComboBelezaLoveStory = _metaFlag(meta, 'servico_combo_beleza_love_story');
    servicoAlbumDigital305 = _metaFlag(meta, 'servico_album_digital_30_5');
    servicoComboBelezaTtd = _metaFlag(meta, 'servico_combo_beleza_ttd');
    servicoAlbumDigital = _metaFlag(meta, 'servico_album_digital');
    servicoAlbumConvidados = _metaFlag(meta, 'servico_album_convidados');
    servicoAlbuns4020 = _metaFlag(meta, 'servico_albuns_40_20');
    servicoSameDayEdit = _metaFlag(meta, 'servico_same_day_edit');
    servicoProjectarSameDayEdit = _metaFlag(meta, 'servico_projectar_same_day_edit');
    servicoGaleriaDigitalConvidados = _metaFlag(meta, 'servico_galeria_digital_convidados');
    servicoFotoLembrancaQr = _metaFlag(meta, 'servico_foto_lembranca_qr');
    servicoImpressao100 = _metaFlag(meta, 'servico_impressao_100_11x22_7');
    servicoVideoDepoisDoSim = _metaFlag(meta, 'servico_video_depois_do_sim');
    servicoDrone = _metaFlag(meta, 'servico_drone');
    equipaTrabalhoCtrl.addListener(_updateTeamPreview);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTeamUsers());
    if (widget.event == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadNextReportNumber());
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
    if (legacy.isNotEmpty && ! _isCerimoniaTipo(legacy)) return legacy;
    final localidade = meta['igreja_localidade']?.toString() ?? '';
    if (localidade.isNotEmpty) return localidade;
    return '';
  }

  String _resolveRefeicaoLocal(Map<String, dynamic> meta) {
    final legacy = meta['quinta_local']?.toString() ?? '';
    if (legacy.isNotEmpty && ! _isRefeicaoTipo(legacy)) return legacy;
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
      _teamUsers = users.where((u) => (u.username ?? '').trim().isNotEmpty).toList();
      _updateTeamPreview();
    } catch (_) {
      if (!mounted) return;
      _updateTeamPreview();
    }
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
    final tokens = _splitTeamTokens(raw).map(_normalizeToken).where((t) => t.isNotEmpty).toList();
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
      final pattern = RegExp('(^|[^a-z0-9])${RegExp.escape(username)}([^a-z0-9]|' r'$)');
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
    if (token == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));

    return Scaffold(
      appBar: buildNavAppBar(context, widget.event == null ? 'Novo Evento' : 'Editar Evento'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxContentWidth = constraints.maxWidth > 1200 ? 1200.0 : constraints.maxWidth;
          final isWide = maxContentWidth >= 900;
          const spacing = 16.0;

          Widget wrapFields(List<Widget> fields, {int columns = 2}) {
            final cols = isWide ? columns : 1;
            final width = (maxContentWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: 12,
              children: fields.map((f) => SizedBox(width: width, child: f)).toList(),
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
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
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

          Widget serviceCheck(String label, bool value, ValueChanged<bool> onChanged) {
            return CheckboxListTile(
              value: value,
              onChanged: (v) => setState(() => onChanged(v ?? false)),
              title: Text(label),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            );
          }

          final teamPreview = _matchedTeamUsers.isEmpty && _unknownTeamTokens.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _matchedTeamUsers
                          .map((u) => Chip(label: Text((u.username ?? '').toUpperCase())))
                          .toList(),
                    ),
                    if (_unknownTeamTokens.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Sem correspondência: ${_unknownTeamTokens.join(', ')}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        ),
                      ),
                  ],
                );

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
                          decoration: const InputDecoration(labelText: 'Tipo Evento', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'casamento', child: Text('CASAMENTO')),
                            DropdownMenuItem(value: 'batizado', child: Text('BATIZADO')),
                          ],
                          onChanged: (v) => setState(() => eventType = v ?? ''),
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
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Preço base', border: OutlineInputBorder()),
                        ),
                        TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Preço por foto', border: OutlineInputBorder()),
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
                    sectionCard(
                      'Missa e locais',
                      wrapFields([
                        TextField(
                          controller: missaHoraCtrl,
                          readOnly: true,
                          onTap: () => _pickTimeInto(missaHoraCtrl),
                          decoration: const InputDecoration(labelText: 'Hora da missa', border: OutlineInputBorder()),
                        ),
                        DropdownButtonFormField<String>(
                          value: igrejaTipo.isEmpty ? null : igrejaTipo,
                          decoration: const InputDecoration(labelText: 'Cerimónia', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'Igreja', child: Text('Igreja')),
                            DropdownMenuItem(value: 'Civil', child: Text('Civil')),
                          ],
                          onChanged: (v) => setState(() => igrejaTipo = v ?? ''),
                        ),
                        TextField(
                          controller: igrejaLocalidadeCtrl,
                          decoration: const InputDecoration(labelText: 'Nome da igreja/local', border: OutlineInputBorder()),
                        ),
                        DropdownButtonFormField<String>(
                          value: refeicaoTipo.isEmpty ? null : refeicaoTipo,
                          decoration: const InputDecoration(labelText: 'Refeição', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'Almoço', child: Text('Almoço')),
                            DropdownMenuItem(value: 'Jantar', child: Text('Jantar')),
                          ],
                          onChanged: (v) => setState(() => refeicaoTipo = v ?? ''),
                        ),
                        TextField(
                          controller: almocoLocalidadeCtrl,
                          decoration: const InputDecoration(labelText: 'Nome da quinta/restaurante', border: OutlineInputBorder()),
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
                              decoration: const InputDecoration(labelText: 'Número de convidados', border: OutlineInputBorder()),
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
                              decoration: const InputDecoration(labelText: 'Equipa de trabalho', border: OutlineInputBorder()),
                            ),
                            TextField(
                              controller: teamCountCtrl,
                              readOnly: true,
                              decoration: const InputDecoration(labelText: 'Nº de profissionais', border: OutlineInputBorder()),
                            ),
                          ], columns: 2),
                          if (_matchedTeamUsers.isNotEmpty || _unknownTeamTokens.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            teamPreview,
                          ],
                        ],
                      ),
                    ),
                    if (eventType == 'casamento') ...[
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
                                          decoration: const InputDecoration(labelText: 'Nome do noivo', border: OutlineInputBorder()),
                                        ),
                                        TextField(
                                          controller: noivoInstagramCtrl,
                                          decoration: const InputDecoration(labelText: 'Instagram', border: OutlineInputBorder()),
                                        ),
                                        TextField(
                                          controller: noivoContactoCtrl,
                                          decoration: const InputDecoration(labelText: 'Telemóvel', border: OutlineInputBorder()),
                                        ),
                                        TextField(
                                          controller: noivoProfissaoCtrl,
                                          decoration: const InputDecoration(labelText: 'Profissão', border: OutlineInputBorder()),
                                        ),
                                        TextField(
                                          controller: noivoFilhoDe1Ctrl,
                                          decoration: const InputDecoration(labelText: 'Filho de (pai)', border: OutlineInputBorder()),
                                        ),
                                        TextField(
                                          controller: noivoFilhoDe2Ctrl,
                                          decoration: const InputDecoration(labelText: 'Filho de (mãe)', border: OutlineInputBorder()),
                                        ),
                                        TextField(
                                          controller: noivoMoradaCtrl,
                                          decoration: const InputDecoration(labelText: 'Morada', border: OutlineInputBorder()),
                                        ),
                                        TextField(
                                          controller: noivoCoordenadasCtrl,
                                          decoration: const InputDecoration(labelText: 'Coordenadas', border: OutlineInputBorder()),
                                        ),
                                        TextField(
                                          controller: casaNoivoChegadaCtrl,
                                          readOnly: true,
                                          onTap: () => _pickTimeInto(casaNoivoChegadaCtrl),
                                          decoration: const InputDecoration(
                                            labelText: 'Casa: chegada',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        TextField(
                                          controller: casaNoivoSaidaCtrl,
                                          readOnly: true,
                                          onTap: () => _pickTimeInto(casaNoivoSaidaCtrl),
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
                                          decoration: const InputDecoration(labelText: 'Nome da noiva', border: OutlineInputBorder()),
                                        ),
                                        TextField(
                                          controller: noivaInstagramCtrl,
                                          decoration: const InputDecoration(labelText: 'Instagram', border: OutlineInputBorder()),
                                        ),
                                        TextField(
                                          controller: noivaContactoCtrl,
                                          decoration: const InputDecoration(labelText: 'Telemóvel', border: OutlineInputBorder()),
                                        ),
                                        TextField(
                                          controller: noivaProfissaoCtrl,
                                          decoration: const InputDecoration(labelText: 'Profissão', border: OutlineInputBorder()),
                                        ),
                                        TextField(
                                          controller: noivaFilhoDe1Ctrl,
                                          decoration: const InputDecoration(labelText: 'Filha de (pai)', border: OutlineInputBorder()),
                                        ),
                                        TextField(
                                          controller: noivaFilhoDe2Ctrl,
                                          decoration: const InputDecoration(labelText: 'Filha de (mãe)', border: OutlineInputBorder()),
                                        ),
                                        TextField(
                                          controller: noivaMoradaCtrl,
                                          decoration: const InputDecoration(labelText: 'Morada', border: OutlineInputBorder()),
                                        ),
                                        TextField(
                                          controller: noivaCoordenadasCtrl,
                                          decoration: const InputDecoration(labelText: 'Coordenadas', border: OutlineInputBorder()),
                                        ),
                                        TextField(
                                          controller: casaNoivaChegadaCtrl,
                                          readOnly: true,
                                          onTap: () => _pickTimeInto(casaNoivaChegadaCtrl),
                                          decoration: const InputDecoration(
                                            labelText: 'Casa: chegada',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        TextField(
                                          controller: casaNoivaSaidaCtrl,
                                          readOnly: true,
                                          onTap: () => _pickTimeInto(casaNoivaSaidaCtrl),
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
                                        decoration: const InputDecoration(labelText: 'Nome do noivo', border: OutlineInputBorder()),
                                      ),
                                      TextField(
                                        controller: noivoInstagramCtrl,
                                        decoration: const InputDecoration(labelText: 'Instagram', border: OutlineInputBorder()),
                                      ),
                                      TextField(
                                        controller: noivoContactoCtrl,
                                        decoration: const InputDecoration(labelText: 'Telemóvel', border: OutlineInputBorder()),
                                      ),
                                      TextField(
                                        controller: noivoProfissaoCtrl,
                                        decoration: const InputDecoration(labelText: 'Profissão', border: OutlineInputBorder()),
                                      ),
                                      TextField(
                                        controller: noivoFilhoDe1Ctrl,
                                        decoration: const InputDecoration(labelText: 'Filho de (pai)', border: OutlineInputBorder()),
                                      ),
                                      TextField(
                                        controller: noivoFilhoDe2Ctrl,
                                        decoration: const InputDecoration(labelText: 'Filho de (mãe)', border: OutlineInputBorder()),
                                      ),
                                      TextField(
                                        controller: noivoMoradaCtrl,
                                        decoration: const InputDecoration(labelText: 'Morada', border: OutlineInputBorder()),
                                      ),
                                      TextField(
                                        controller: noivoCoordenadasCtrl,
                                        decoration: const InputDecoration(labelText: 'Coordenadas', border: OutlineInputBorder()),
                                      ),
                                      TextField(
                                        controller: casaNoivoChegadaCtrl,
                                        readOnly: true,
                                        onTap: () => _pickTimeInto(casaNoivoChegadaCtrl),
                                        decoration: const InputDecoration(
                                          labelText: 'Casa: chegada',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: casaNoivoSaidaCtrl,
                                        readOnly: true,
                                        onTap: () => _pickTimeInto(casaNoivoSaidaCtrl),
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
                                        decoration: const InputDecoration(labelText: 'Nome da noiva', border: OutlineInputBorder()),
                                      ),
                                      TextField(
                                        controller: noivaInstagramCtrl,
                                        decoration: const InputDecoration(labelText: 'Instagram', border: OutlineInputBorder()),
                                      ),
                                      TextField(
                                        controller: noivaContactoCtrl,
                                        decoration: const InputDecoration(labelText: 'Telemóvel', border: OutlineInputBorder()),
                                      ),
                                      TextField(
                                        controller: noivaProfissaoCtrl,
                                        decoration: const InputDecoration(labelText: 'Profissão', border: OutlineInputBorder()),
                                      ),
                                      TextField(
                                        controller: noivaFilhoDe1Ctrl,
                                        decoration: const InputDecoration(labelText: 'Filha de (pai)', border: OutlineInputBorder()),
                                      ),
                                      TextField(
                                        controller: noivaFilhoDe2Ctrl,
                                        decoration: const InputDecoration(labelText: 'Filha de (mãe)', border: OutlineInputBorder()),
                                      ),
                                      TextField(
                                        controller: noivaMoradaCtrl,
                                        decoration: const InputDecoration(labelText: 'Morada', border: OutlineInputBorder()),
                                      ),
                                      TextField(
                                        controller: noivaCoordenadasCtrl,
                                        decoration: const InputDecoration(labelText: 'Coordenadas', border: OutlineInputBorder()),
                                      ),
                                      TextField(
                                        controller: casaNoivaChegadaCtrl,
                                        readOnly: true,
                                        onTap: () => _pickTimeInto(casaNoivaChegadaCtrl),
                                        decoration: const InputDecoration(
                                          labelText: 'Casa: chegada',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      TextField(
                                        controller: casaNoivaSaidaCtrl,
                                        readOnly: true,
                                        onTap: () => _pickTimeInto(casaNoivaSaidaCtrl),
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
                    if (eventType == 'batizado') ...[
                      sectionCard(
                        'Dados do batizado',
                        wrapFields([
                          TextField(
                            controller: bebeNomeCtrl,
                            decoration: const InputDecoration(labelText: 'Nome do bebé', border: OutlineInputBorder()),
                          ),
                          TextField(
                            controller: paiNomeCtrl,
                            decoration: const InputDecoration(labelText: 'Nome do pai', border: OutlineInputBorder()),
                          ),
                          TextField(
                            controller: maeNomeCtrl,
                            decoration: const InputDecoration(labelText: 'Nome da mãe', border: OutlineInputBorder()),
                          ),
                          TextField(
                            controller: padrinhoNomeCtrl,
                            decoration: const InputDecoration(labelText: 'Nome do padrinho', border: OutlineInputBorder()),
                          ),
                          TextField(
                            controller: madrinhaNomeCtrl,
                            decoration: const InputDecoration(labelText: 'Nome da madrinha', border: OutlineInputBorder()),
                          ),
                          TextField(
                            controller: contactoPaisCtrl,
                            decoration: const InputDecoration(labelText: 'Contacto dos pais', border: OutlineInputBorder()),
                          ),
                          TextField(
                            controller: batizadoMoradaCtrl,
                            decoration: const InputDecoration(labelText: 'Morada', border: OutlineInputBorder()),
                          ),
                          TextField(
                            controller: instagramPaisCtrl,
                            decoration: const InputDecoration(labelText: 'Instagram dos pais', border: OutlineInputBorder()),
                          ),
                        ], columns: 2),
                      ),
                    ],
                    sectionCard(
                      'Serviços',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          wrapFields([
                            serviceCheck('Save the Date', servicoSaveTheDate, (v) => servicoSaveTheDate = v),
                            serviceCheck('Fotos Love Story', servicoFotosLoveStory, (v) => servicoFotosLoveStory = v),
                            serviceCheck('Vídeo Love Story', servicoVideoLoveStory, (v) => servicoVideoLoveStory = v),
                            serviceCheck('Projectar Love Story', servicoProjectarLoveStory, (v) => servicoProjectarLoveStory = v),
                            serviceCheck('Combo beleza Love Story', servicoComboBelezaLoveStory, (v) => servicoComboBelezaLoveStory = v),
                            serviceCheck('Álbum digital 30x5', servicoAlbumDigital305, (v) => servicoAlbumDigital305 = v),
                            serviceCheck('Combo beleza TTD', servicoComboBelezaTtd, (v) => servicoComboBelezaTtd = v),
                            serviceCheck('Álbum digital', servicoAlbumDigital, (v) => servicoAlbumDigital = v),
                            serviceCheck('Álbum convidados', servicoAlbumConvidados, (v) => servicoAlbumConvidados = v),
                            serviceCheck('Álbuns 40x20', servicoAlbuns4020, (v) => servicoAlbuns4020 = v),
                            serviceCheck('Same Day Edit', servicoSameDayEdit, (v) => servicoSameDayEdit = v),
                            serviceCheck('Projectar Same Day Edit', servicoProjectarSameDayEdit, (v) => servicoProjectarSameDayEdit = v),
                            serviceCheck('Galeria digital convidados', servicoGaleriaDigitalConvidados, (v) => servicoGaleriaDigitalConvidados = v),
                            serviceCheck('Foto lembrança QR', servicoFotoLembrancaQr, (v) => servicoFotoLembrancaQr = v),
                            serviceCheck('Impressão 100 11x22,7', servicoImpressao100, (v) => servicoImpressao100 = v),
                            serviceCheck('Vídeo depois do sim', servicoVideoDepoisDoSim, (v) => servicoVideoDepoisDoSim = v),
                            serviceCheck('Drone', servicoDrone, (v) => servicoDrone = v),
                          ], columns: 3),
                          const SizedBox(height: 8),
                          wrapFields([
                            TextField(
                              controller: servicoTelaCtrl,
                              decoration: const InputDecoration(labelText: 'Tela', border: OutlineInputBorder()),
                            ),
                            TextField(
                              controller: servicoUsbCtrl,
                              decoration: const InputDecoration(labelText: 'USB', border: OutlineInputBorder()),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          wrapFields([
                            TextField(
                              controller: servicoCondicoesCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(labelText: 'Condições mínimas', border: OutlineInputBorder()),
                            ),
                            TextField(
                              controller: servicoMusicasCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(labelText: 'Músicas', border: OutlineInputBorder()),
                            ),
                            TextField(
                              controller: servicoExtrasCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(labelText: 'Extras', border: OutlineInputBorder()),
                            ),
                          ], columns: 1),
                        ],
                      ),
                    ),
                    if (widget.event != null && _isTodayOrPast(dateCtrl.text)) ...[
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
                              final price = num.tryParse(priceCtrl.text.trim()) ?? 0;
                              final basePrice = num.tryParse(basePriceCtrl.text.trim()) ?? 0;
                              final meta = Map<String, dynamic>.from(widget.event?.eventMeta ?? {});
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

                              setMetaValue('missa_hora', missaHoraCtrl.text);
                              setMetaValue('igreja_local', igrejaTipo);
                              setMetaValue('igreja_localidade', igrejaLocalidadeCtrl.text);
                              setMetaValue('quinta_local', refeicaoTipo);
                              setMetaValue('almoco_localidade', almocoLocalidadeCtrl.text);
                              setMetaValue('numero_convidados', numeroConvidadosCtrl.text);
                              setMetaValue('data_entrega', dataEntregaCtrl.text);
                              setMetaValue('equipa_de_trabalho', equipaTrabalhoCtrl.text);
                              setMetaValue('servico_num_profissionais', _teamCount == 0 ? '' : _teamCount.toString());
                              setMetaBool('servico_save_the_date', servicoSaveTheDate);
                              setMetaBool('servico_fotos_love_story', servicoFotosLoveStory);
                              setMetaBool('servico_video_love_story', servicoVideoLoveStory);
                              setMetaBool('servico_projectar_love_story', servicoProjectarLoveStory);
                              setMetaBool('servico_combo_beleza_love_story', servicoComboBelezaLoveStory);
                              setMetaBool('servico_album_digital_30_5', servicoAlbumDigital305);
                              setMetaBool('servico_combo_beleza_ttd', servicoComboBelezaTtd);
                              setMetaBool('servico_album_digital', servicoAlbumDigital);
                              setMetaBool('servico_album_convidados', servicoAlbumConvidados);
                              setMetaBool('servico_albuns_40_20', servicoAlbuns4020);
                              setMetaBool('servico_same_day_edit', servicoSameDayEdit);
                              setMetaBool('servico_projectar_same_day_edit', servicoProjectarSameDayEdit);
                              setMetaBool('servico_galeria_digital_convidados', servicoGaleriaDigitalConvidados);
                              setMetaBool('servico_foto_lembranca_qr', servicoFotoLembrancaQr);
                              setMetaBool('servico_impressao_100_11x22_7', servicoImpressao100);
                              setMetaBool('servico_video_depois_do_sim', servicoVideoDepoisDoSim);
                              setMetaBool('servico_drone', servicoDrone);
                              setMetaValue('servico_tela', servicoTelaCtrl.text);
                              setMetaValue('servico_usb', servicoUsbCtrl.text);
                              setMetaValue('servico_condicoes_minimas', servicoCondicoesCtrl.text);
                              setMetaValue('servico_musicas', servicoMusicasCtrl.text);
                              setMetaValue('servico_extras', servicoExtrasCtrl.text);
                              if (eventType == 'casamento') {
                                for (final key in baptKeys) {
                                  meta.remove(key);
                                }
                                setMetaValue('noivo_nome', noivoNomeCtrl.text);
                                setMetaValue('noiva_nome', noivaNomeCtrl.text);
                                setMetaValue('noivo_instagram', noivoInstagramCtrl.text);
                                setMetaValue('noiva_instagram', noivaInstagramCtrl.text);
                                setMetaValue('noivo_contacto', noivoContactoCtrl.text);
                                setMetaValue('noiva_contacto', noivaContactoCtrl.text);
                                setMetaValue('noivo_profissao', noivoProfissaoCtrl.text);
                                setMetaValue('noiva_profissao', noivaProfissaoCtrl.text);
                                setMetaValue('noivo_filho_de_1', noivoFilhoDe1Ctrl.text);
                                setMetaValue('noivo_filho_de_2', noivoFilhoDe2Ctrl.text);
                                setMetaValue('noiva_filho_de_1', noivaFilhoDe1Ctrl.text);
                                setMetaValue('noiva_filho_de_2', noivaFilhoDe2Ctrl.text);
                                setMetaValue('noivo_morada', noivoMoradaCtrl.text);
                                setMetaValue('noiva_morada', noivaMoradaCtrl.text);
                                setMetaValue('noivo_coordenadas', noivoCoordenadasCtrl.text);
                                setMetaValue('noiva_coordenadas', noivaCoordenadasCtrl.text);
                                setMetaValue('casa_noivo_chegada', casaNoivoChegadaCtrl.text);
                                setMetaValue('casa_noivo_saida', casaNoivoSaidaCtrl.text);
                                setMetaValue('casa_noiva_chegada', casaNoivaChegadaCtrl.text);
                                setMetaValue('casa_noiva_saida', casaNoivaSaidaCtrl.text);
                              }
                              if (eventType == 'batizado') {
                                for (final key in weddingKeys) {
                                  meta.remove(key);
                                }
                                setMetaValue('bebe_nome', bebeNomeCtrl.text);
                                setMetaValue('pai_nome', paiNomeCtrl.text);
                                setMetaValue('mae_nome', maeNomeCtrl.text);
                                setMetaValue('padrinho_nome', padrinhoNomeCtrl.text);
                                setMetaValue('madrinha_nome', madrinhaNomeCtrl.text);
                                setMetaValue('contacto_pais', contactoPaisCtrl.text);
                                setMetaValue('morada', batizadoMoradaCtrl.text);
                                setMetaValue('instagram_pais', instagramPaisCtrl.text);
                              }
                              final payload = StaffEventPayload(
                                name: null,
                                legacyReportNumber: reportNumberCtrl.text.trim(),
                                eventDate: dateCtrl.text.trim(),
                                eventTime: timeCtrl.text.trim(),
                                pricePerPhoto: price,
                                basePrice: basePrice,
                                eventType: eventType,
                                eventMeta: meta,
                                notes: notesCtrl.text.trim(),
                                isLocked: isLocked,
                              );
                              if (payload.eventDate.isEmpty) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(content: Text('Data é obrigatória.')));
                                return;
                              }
                              try {
                                setState(() => saving = true);
                                if (widget.event == null) {
                                  await ref.read(apiProvider).createEvent(token, payload);
                                } else {
                                  await ref.read(apiProvider).updateEvent(token, widget.event!.id, payload);
                                }
                                if (!context.mounted) return;
                                Navigator.pop(context);
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
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
      ),
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
  ConsumerState<StaffEventStaffPage> createState() => _StaffEventStaffPageState();
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
    if (token == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));
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
            const Text('Associar staff', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: selectedUserId,
              items: users.map((u) => DropdownMenuItem(value: u.id, child: Text('${u.name} (${u.role})'))).toList(),
              onChanged: (v) => setState(() => selectedUserId = v),
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Utilizador'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: role,
              items: const [
                DropdownMenuItem(value: 'photographer', child: Text('Fotógrafo')),
                DropdownMenuItem(value: 'assistant', child: Text('Assistente')),
                DropdownMenuItem(value: 'sales', child: Text('Vendas')),
              ],
              onChanged: (v) => setState(() => role = v ?? 'photographer'),
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Função'),
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
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Canal'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: messageCtrl,
                maxLines: 2,
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Mensagem (opcional)'),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: selectedUserId == null
                  ? null
                  : () async {
                      await ref.read(apiProvider).staffAssignEventStaff(
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
            const Text('Staff associado', style: TextStyle(fontWeight: FontWeight.w600)),
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
                      await ref.read(apiProvider).staffRemoveEventStaff(token, widget.event.id, s.user.id);
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

  Future<List<StaffEvent>> _loadEvents(String token, {required bool assignedOnly}) =>
      ref.read(apiProvider).staffEvents(token, assignedOnly: assignedOnly);

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
      final photos = await ref.read(apiProvider).staffEventPhotos(token, eventId, '');
      photos.sort((a, b) => b.id.compareTo(a.id));
      if (mounted) {
        setState(() => latestPhotos = photos.take(24).toList());
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uploads'),
        leading: navLeading(context),
        actions: navActions(context, extra: [
          IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh)),
        ]),
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
                children: [Padding(padding: const EdgeInsets.all(16), child: Text('Erro: ${snap.error}'))],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))],
            );
          }
          final events = _filterEventsForUser(snap.data!, user);
          if (events.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [Padding(padding: EdgeInsets.all(16), child: Text('Sem eventos'))],
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
                items: events.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                onChanged: uploading
                    ? null
                    : (v) async {
                        if (v == null) return;
                        setState(() => eventId = v);
                        await _refreshLatestPhotos(token, v);
                      },
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Evento'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: uploading
                    ? null
                    : () async {
                        final picker = ImagePicker();
                        final files = await picker.pickMultiImage(imageQuality: 90);
                        if (files.isEmpty) return;
                        setState(() {
                          uploading = true;
                          status = 'A enviar ${files.length} ficheiros...';
                          uploadResults = [];
                        });
                        try {
                          final results = <_UploadOutcome>[];
                          for (final file in files) {
                            final outcome = await _uploadFile(token, eventId!, File(file.path));
                            results.add(outcome);
                            if (mounted) setState(() => uploadResults = List.from(results));
                          }
                          if (!context.mounted) return;
                          final failed = results.where((r) => !r.success).toList();
                          if (mounted) {
                            setState(() {
                              status = failed.isEmpty
                                  ? 'Uploads concluídos.'
                                  : 'Uploads concluídos com falhas (${failed.length}).';
                            });
                          }
                          if (failed.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploads concluídos.')));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Uploads concluídos com falhas (${failed.length}).')),
                            );
                          }
                          await _refreshLatestPhotos(token, eventId!);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro upload: $e')));
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
                const Text('Resultado dos uploads', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...uploadResults.map((r) {
                  final icon = r.success ? Icons.check_circle_outline : Icons.error_outline;
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
                const Text('Últimas fotos', style: TextStyle(fontWeight: FontWeight.w600)),
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
                            ? DecorationImage(image: NetworkImage(preview), fit: BoxFit.cover)
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
      ),
    );
  }

  Future<_UploadOutcome> _uploadFile(String token, int eventId, File file) async {
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
        await ref.read(apiProvider).staffUploadChunk(
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

class StaffPhotosPage extends ConsumerStatefulWidget {
  const StaffPhotosPage({super.key});

  @override
  ConsumerState<StaffPhotosPage> createState() => _StaffPhotosPageState();
}

class _StaffPhotosPageState extends ConsumerState<StaffPhotosPage> {
  int? eventId;
  final searchCtrl = TextEditingController();
  final selected = <int>{};

  Future<List<StaffEvent>> _loadEvents(String token, {required bool assignedOnly}) =>
      ref.read(apiProvider).staffEvents(token, assignedOnly: assignedOnly);

  @override
  void initState() {
    super.initState();
    saveStaffLastRoute('photos', userId: ref.read(staffUserProvider)?.id);
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotos'),
        leading: navLeading(context),
        actions: navActions(context, extra: [
          IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh)),
        ]),
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
                children: [Padding(padding: const EdgeInsets.all(16), child: Text('Erro: ${snap.error}'))],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))],
            );
          }
          final events = _filterEventsForUser(snap.data!, user);
          if (events.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [Padding(padding: EdgeInsets.all(16), child: Text('Sem eventos'))],
            );
          }
          if (eventId == null || !events.any((e) => e.id == eventId)) {
            eventId = events.first.id;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      value: eventId,
                      items: events.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                      onChanged: (v) => setState(() => eventId = v),
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Evento'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Pesquisar número'),
                      onSubmitted: (_) => setState(() {}),
                    ),
                    if (selected.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FilledButton(
                          onPressed: () async {
                            final ok = await _confirm(context, 'Apagar selecionadas?', 'Isto remove fotos permanentemente.');
                            if (!ok) return;
                            final deleted = await ref.read(apiProvider).staffBulkDeletePhotos(token, eventId!, selected.toList());
                            if (!context.mounted) return;
                            selected.clear();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Apagadas $deleted fotos.')));
                            setState(() {});
                          },
                          child: Text('Apagar selecionadas (${selected.length})'),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<StaffPhoto>>(
                  future: ref.read(apiProvider).staffEventPhotos(token, eventId!, searchCtrl.text.trim()),
                  builder: (_, photoSnap) {
                    if (!photoSnap.hasData) {
                      if (photoSnap.hasError) return Center(child: Text('Erro: ${photoSnap.error}'));
                      return const Center(child: CircularProgressIndicator());
                    }
                    final photos = photoSnap.data!;
                    if (photos.isEmpty) return const Center(child: Text('Sem fotos'));
                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: photos.length,
                      itemBuilder: (_, i) {
                        final p = photos[i];
                        final isSelected = selected.contains(p.id);
                        return Card(
                          child: ListTile(
                            leading: p.previewUrl == null
                                ? const Icon(Icons.image_not_supported)
                                : Image.network(p.previewUrl!, width: 56, height: 56, fit: BoxFit.cover),
                            title: Text('#${p.number}'),
                            subtitle: Text(p.previewStatus ?? ''),
                            trailing: Wrap(
                              spacing: 6,
                              children: [
                                IconButton(
                                  icon: Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank),
                                  onPressed: () => setState(() {
                                    if (isSelected) {
                                      selected.remove(p.id);
                                    } else {
                                      selected.add(p.id);
                                    }
                                  }),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () async {
                                    await ref.read(apiProvider).staffRetryPreview(token, eventId!, p.id);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retry enviado.')));
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final ok = await _confirm(context, 'Apagar foto?', 'Número ${p.number}');
                                    if (!ok) return;
                                    await ref.read(apiProvider).staffDeletePhoto(token, eventId!, p.id);
                                    if (!context.mounted) return;
                                    setState(() {});
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
              ),
            ],
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
  String selectedEventType = '';
  String status = '';
  final queryCtrl = TextEditingController();
  final selected = <int>{};

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

  Future<List<StaffEvent>> _loadEvents(String token, {required bool assignedOnly}) =>
      ref.read(apiProvider).staffEvents(token, assignedOnly: assignedOnly);

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime _parseDateKey(String raw) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return DateTime(1970, 1, 1);
    }
  }

  String _formatDateLabel(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  Future<List<OrderListItem>> _loadOrdersFiltered(
    String token, {
    required String eventDate,
    required String eventType,
    required String status,
    required String query,
  }) async {
    return ref.read(apiProvider).staffOrdersList(
          token,
          eventDate: eventDate,
          eventType: eventType,
          status: status,
          q: query,
        );
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    final isPhotographer = _isPhotographerRole(user.role);
    final canUpdate = user.hasPermission('orders.update');
    final canBulk = user.hasPermission('orders.bulk');
    final canDownload = user.hasPermission('orders.download') && !isPhotographer;
    final canExport = user.hasPermission('orders.export') && !isPhotographer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos'),
        leading: navLeading(context),
        actions: navActions(context, extra: [
          IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh)),
        ]),
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
                children: [Padding(padding: const EdgeInsets.all(16), child: Text('Erro: ${snap.error}'))],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))],
            );
          }
          final events = _filterEventsForUser(snap.data!, user);
          if (events.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [Padding(padding: EdgeInsets.all(16), child: Text('Sem eventos'))],
            );
          }
          final availableDates = events
              .map((e) => e.eventDate)
              .where((d) => d.trim().isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final todayKey = _dateKey(DateTime.now());
          final desiredDateKey = selectedDate != null ? _dateKey(selectedDate!) : '';
          if (availableDates.isNotEmpty && (selectedDate == null || !availableDates.contains(desiredDateKey))) {
            final nextKey = availableDates.contains(todayKey) ? todayKey : availableDates.first;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                selectedDate = _parseDateKey(nextKey);
                selectedEventType = '';
                selected.clear();
              });
            });
          }
          final resolvedDate = selectedDate ?? _parseDateKey(availableDates.first);
          final resolvedDateKey = _dateKey(resolvedDate);
          final eventsForDate = events.where((e) => e.eventDate == resolvedDateKey).toList();
          final eventTypes = eventsForDate
              .map((e) => (e.eventType ?? '').trim())
              .where((t) => t.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          if (selectedEventType.isNotEmpty && !eventTypes.contains(selectedEventType)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => selectedEventType = '');
            });
          } else if (selectedEventType.isEmpty && eventTypes.length == 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => selectedEventType = eventTypes.first);
            });
          }
          final filteredEvents = selectedEventType.isEmpty
              ? eventsForDate
              : eventsForDate.where((e) => (e.eventType ?? '') == selectedEventType).toList();
          final eventIds = filteredEvents.map((e) => e.id).toList();
          final eventInfoById = {for (final e in events) e.id: e};
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () async {
                              final firstDate = availableDates.isNotEmpty ? _parseDateKey(availableDates.first) : DateTime(2000);
                              final lastDate = availableDates.isNotEmpty ? _parseDateKey(availableDates.last) : DateTime(2100);
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: resolvedDate,
                                firstDate: firstDate,
                                lastDate: lastDate,
                              );
                              if (picked == null) return;
                              setState(() {
                                selectedDate = picked;
                                selectedEventType = '';
                                selected.clear();
                              });
                            },
                            child: Text('Data: ${_formatDateLabel(resolvedDate)}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedEventType,
                            items: [
                              const DropdownMenuItem(value: '', child: Text('Todos tipos')),
                              ...eventTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                            ],
                            onChanged: (v) => setState(() {
                              selectedEventType = v ?? '';
                              selected.clear();
                            }),
                            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Tipo evento'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Todos status')),
                        DropdownMenuItem(value: 'pending', child: Text('pending')),
                        DropdownMenuItem(value: 'paid', child: Text('paid')),
                        DropdownMenuItem(value: 'delivered', child: Text('delivered')),
                      ],
                      onChanged: (v) => setState(() => status = v ?? ''),
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Status'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: queryCtrl,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Nome/codigo'),
                      onSubmitted: (_) => setState(() => selected.clear()),
                    ),
                    if (canExport && eventIds.length == 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FilledButton.tonal(
                          onPressed: () async {
                            final path = await ref.read(apiProvider).staffExportOrdersCsv(token, eventIds.first);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV guardado em: $path')));
                          },
                          child: const Text('Exportar CSV do evento'),
                        ),
                      ),
                    if (selected.isNotEmpty && canBulk)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: isPhotographer
                            ? FilledButton(
                                onPressed: () async {
                                  final updated = await ref.read(apiProvider).staffBulkOrderStatus(token, selected.toList(), 'paid');
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Atualizados $updated pedidos.')));
                                  selected.clear();
                                  setState(() {});
                                },
                                child: const Text('Marcar pagos (selecionados)'),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: 'paid',
                                      items: const [
                                        DropdownMenuItem(value: 'pending', child: Text('pending')),
                                        DropdownMenuItem(value: 'paid', child: Text('paid')),
                                        DropdownMenuItem(value: 'delivered', child: Text('delivered')),
                                      ],
                                      onChanged: (v) async {
                                        if (v == null) return;
                                        final updated = await ref.read(apiProvider).staffBulkOrderStatus(token, selected.toList(), v);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Atualizados $updated pedidos.')));
                                        selected.clear();
                                        setState(() {});
                                      },
                                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Bulk status'),
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
                  future: _loadOrdersFiltered(
                    token,
                    eventDate: resolvedDateKey,
                    eventType: selectedEventType,
                    status: status,
                    query: queryCtrl.text.trim(),
                  ),
                  builder: (_, orderSnap) {
                    if (!orderSnap.hasData) {
                      if (orderSnap.hasError) return Center(child: Text('Erro: ${orderSnap.error}'));
                      return const Center(child: CircularProgressIndicator());
                    }
                    final orders = orderSnap.data!;
                    if (eventIds.isEmpty) {
                      return const Center(child: Text('Sem eventos para esta data.'));
                    }
                    if (orders.isEmpty) return const Center(child: Text('Sem pedidos'));
                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: orders.length,
                      itemBuilder: (_, i) {
                        final o = orders[i];
                        final isSelected = selected.contains(o.id);
                        return Card(
                          child: ListTile(
                            title: Text('${o.orderCode} - ${o.customerName}'),
                            subtitle: Text(() {
                              final info = o.eventId != null ? eventInfoById[o.eventId] : null;
                              final name = info?.name ?? o.eventName ?? '';
                              final date = info?.eventDate ?? '';
                              final type = info?.eventType ?? '';
                              final parts = <String>['Status: ${o.status}'];
                              if (name.isNotEmpty) parts.add(name);
                              if (date.isNotEmpty) parts.add(date);
                              if (type.isNotEmpty) parts.add(type);
                              return parts.join(' • ');
                            }()),
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => StaffOrderDetailPage(orderId: o.id)));
                              if (!mounted) return;
                              setState(() {});
                            },
                            trailing: Wrap(
                              spacing: 6,
                              children: [
                                IconButton(
                                  icon: Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank),
                                  onPressed: () => setState(() {
                                    if (isSelected) {
                                      selected.remove(o.id);
                                    } else {
                                      selected.add(o.id);
                                    }
                                  }),
                                ),
                                if (canUpdate && o.status != 'paid' && o.status != 'delivered')
                                  FilledButton(
                                    onPressed: () async {
                                      final emailed = await ref.read(apiProvider).markOrderPaid(token, o.id, eventId: o.eventId);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(emailed ? 'Marcado pago e link enviado.' : 'Marcado pago. Sem email.')),
                                      );
                                      setState(() {});
                                    },
                                    child: const Text('Pago'),
                                  ),
                                if (canUpdate && o.status == 'paid' && !isPhotographer)
                                  OutlinedButton(
                                    onPressed: () async {
                                      await ref.read(apiProvider).markOrderDelivered(token, o.id, eventId: o.eventId);
                                      if (!context.mounted) return;
                                      setState(() {});
                                    },
                                    child: const Text('Entregue'),
                                  ),
                                if (canDownload)
                                  PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      if (v == 'send-link') {
                                        final sent = await ref.read(apiProvider).staffSendDownloadLink(token, o.id);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(sent ? 'Link enviado.' : 'Falha no envio.')));
                                      }
                                      if (v == 'download-all') {
                                        final path = await ref.read(apiProvider).staffDownloadAll(token, o.id);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ZIP guardado: $path')));
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'send-link', child: Text('Enviar link')),
                                      PopupMenuItem(value: 'download-all', child: Text('Download ZIP')),
                                    ],
                                  ),
                              ],
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
  ConsumerState<StaffOrderDetailPage> createState() => _StaffOrderDetailPageState();
}

class _StaffOrderDetailPageState extends ConsumerState<StaffOrderDetailPage> {
  Future<StaffOrderDetail>? _future;
  bool editing = false;
  bool saving = false;
  bool _initialized = false;
  late final TextEditingController nameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController paymentCtrl;
  String status = 'pending';

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController();
    emailCtrl = TextEditingController();
    phoneCtrl = TextEditingController();
    paymentCtrl = TextEditingController();
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
    super.dispose();
  }

  void _loadDetail(String token) {
    _initialized = false;
    _future = ref.read(apiProvider).staffOrderDetail(token, widget.orderId);
  }

  Future<void> _save(String token) async {
    final payload = StaffOrderUpdatePayload(
      customerName: nameCtrl.text.trim(),
      customerEmail: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
      customerPhone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      paymentMethod: paymentCtrl.text.trim().isEmpty ? null : paymentCtrl.text.trim(),
      status: status,
    );
    if (payload.customerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome do cliente é obrigatório.')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    final canWrite = user.hasPermission('orders.update');
    final isPhotographer = _isPhotographerRole(user.role);
    final canEdit = canWrite && !isPhotographer;
    final canDownload = user.hasPermission('orders.download') && !isPhotographer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedido'),
        leading: navLeading(context),
        actions: navActions(context, extra: [
          IconButton(
            onPressed: () => setState(() => _loadDetail(token)),
            icon: const Icon(Icons.refresh),
          ),
          if (canEdit)
            IconButton(
              onPressed: () => setState(() => editing = !editing),
              icon: Icon(editing ? Icons.close : Icons.edit),
            ),
        ]),
      ),
      body: FutureBuilder<StaffOrderDetail>(
        future: _future ?? ref.read(apiProvider).staffOrderDetail(token, widget.orderId),
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
            status = order.status;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Código: ${order.orderCode}', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (order.eventName != null) Text('Evento: ${order.eventName}'),
              const SizedBox(height: 8),
              if (!editing) ...[
                Text('Status: ${order.status}'),
                Text('Pagamento: ${order.paymentMethod.isEmpty ? '-' : order.paymentMethod}'),
                Text('Total: ${order.totalAmount}'),
                const SizedBox(height: 12),
                Text('Cliente: ${order.customerName}'),
                if ((order.customerEmail ?? '').isNotEmpty) Text('Email: ${order.customerEmail}'),
                if ((order.customerPhone ?? '').isNotEmpty) Text('Telefone: ${order.customerPhone}'),
                if (isPhotographer && order.status == 'pending')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FilledButton(
                      onPressed: () async {
                        await ref.read(apiProvider).markOrderPaid(token, order.id);
                        if (!context.mounted) return;
                        setState(() => _loadDetail(token));
                      },
                      child: const Text('Marcar como pago'),
                    ),
                  ),
              ] else ...[
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: paymentCtrl, decoration: const InputDecoration(labelText: 'Pagamento', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: status,
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('pending')),
                    DropdownMenuItem(value: 'paid', child: Text('paid')),
                    DropdownMenuItem(value: 'delivered', child: Text('delivered')),
                  ],
                  onChanged: (v) => setState(() => status = v ?? status),
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                ),
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
                  children: order.photos.map((p) => Chip(label: Text(p.number))).toList(),
                ),
              const SizedBox(height: 16),
              if (canDownload)
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final sent = await ref.read(apiProvider).staffSendDownloadLink(token, order.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(sent ? 'Link enviado.' : 'Falha no envio.')));
                      },
                      child: const Text('Enviar link'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final path = await ref.read(apiProvider).staffDownloadAll(token, order.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ZIP guardado: $path')));
                      },
                      child: const Text('Download ZIP'),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
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
    if (token == null || user == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));

    return Scaffold(
      appBar: buildNavAppBar(context, 'Definições'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Username (opcional)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nova password (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      if (name.isEmpty || email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome e email são obrigatórios.')));
                        return;
                      }
                      setState(() => saving = true);
                      try {
                        final updated = await ref.read(apiProvider).updateProfile(
                              token,
                              name: name,
                              email: email,
                              username: usernameCtrl.text.trim(),
                              password: passwordCtrl.text.trim(),
                            );
                        ref.read(staffUserProvider.notifier).state = updated;
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Definições atualizadas.')));
                        passwordCtrl.clear();
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                      } finally {
                        if (mounted) setState(() => saving = false);
                      }
                    },
              child: Text(saving ? 'A guardar...' : 'Guardar'),
            ),
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

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    if (token == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));

    if (_future == null || _lastToken != token) {
      _lastToken = token;
      _future = ref.read(apiProvider).staffUsers(token);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilizadores'),
        leading: navLeading(context),
        actions: navActions(context, extra: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffUserFormPage()));
          _reload();
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<StaffUser>>(
          future: _future,
          builder: (_, snap) {
            if (!snap.hasData) {
              if (snap.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [Padding(padding: const EdgeInsets.all(16), child: Text('Erro: ${snap.error}'))],
                );
              }
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))],
              );
            }
            final users = snap.data!;
            if (users.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [Padding(padding: EdgeInsets.all(16), child: Text('Sem utilizadores'))],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: users.length,
              itemBuilder: (_, i) {
                final u = users[i];
                return Card(
                  child: ListTile(
                    title: Text(u.name),
                    subtitle: Text('${u.username ?? '-'} • ${u.email} • ${u.role}'),
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => StaffUserFormPage(user: u)));
                            _reload();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await _confirm(context, 'Apagar utilizador?', u.email);
                            if (!ok) return;
                            try {
                              await ref.read(apiProvider).deleteUser(token, u.id);
                              if (!context.mounted) return;
                              _reload();
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
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
      ),
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

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    if (token == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    final permissionsLocked = role == 'admin';

    return Scaffold(
      appBar: buildNavAppBar(context, widget.user == null ? 'Novo utilizador' : 'Editar utilizador'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Username (opcional)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password (opcional)', border: OutlineInputBorder()),
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
              decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            const Text('Permissões', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...kStaffPermissions.entries.map((e) => CheckboxListTile(
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
            )),
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
                        password: passwordCtrl.text.trim().isEmpty ? null : passwordCtrl.text.trim(),
                      );
                      if (payload.name.isEmpty || payload.email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome e email são obrigatórios.')));
                        return;
                      }
                      try {
                        setState(() => saving = true);
                        if (widget.user == null) {
                          await ref.read(apiProvider).createUser(token, payload);
                        } else {
                          await ref.read(apiProvider).updateUser(token, widget.user!.id, payload);
                        }
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                      } finally {
                        if (mounted) setState(() => saving = false);
                      }
                    },
              child: Text(saving ? 'A guardar...' : 'Guardar'),
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        leading: navLeading(context),
        actions: navActions(context, extra: [
          IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh)),
        ]),
      ),
      floatingActionButton: user.hasPermission('clients.create')
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffClientFormPage()));
                setState(() {});
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: searchCtrl,
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Pesquisar'),
                onSubmitted: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<StaffClient>>(
                future: _loadClients(token),
                builder: (_, snap) {
                  if (!snap.hasData) {
                    if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
                    return const Center(child: CircularProgressIndicator());
                  }
                  final clients = snap.data!;
                  if (clients.isEmpty) return const Center(child: Text('Sem clientes'));
                  return ListView.builder(
                    itemCount: clients.length,
                    itemBuilder: (_, i) {
                      final c = clients[i];
                      return Card(
                        child: ListTile(
                          title: Text(c.name),
                          subtitle: Text([c.phone, c.email].where((v) => v != null && v!.isNotEmpty).join(' • ')),
                          onTap: user.hasPermission('clients.update')
                              ? () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => StaffClientFormPage(client: c)),
                                  );
                                  setState(() {});
                                }
                              : null,
                          trailing: user.hasPermission('clients.delete')
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final ok = await _confirm(context, 'Remover cliente?', c.name);
                                    if (!ok) return;
                                    await ref.read(apiProvider).deleteClient(token, c.id);
                                    if (!context.mounted) return;
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StaffClientFormPage extends ConsumerStatefulWidget {
  const StaffClientFormPage({super.key, this.client});
  final StaffClient? client;

  @override
  ConsumerState<StaffClientFormPage> createState() => _StaffClientFormPageState();
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

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    if (token == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));

    return Scaffold(
      appBar: buildNavAppBar(context, widget.client == null ? 'Novo cliente' : 'Editar cliente'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telemóvel', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(
            controller: notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notas', border: OutlineInputBorder()),
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome é obrigatório.')));
                      return;
                    }
                    try {
                      setState(() => saving = true);
                      if (widget.client == null) {
                        await ref.read(apiProvider).createClient(token, payload);
                      } else {
                        await ref.read(apiProvider).updateClient(token, widget.client!.id, payload);
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
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
}

Future<bool> _confirm(BuildContext context, String title, String message) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
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
  final FlutterPreventScreenCapture _preventScreenCapture = FlutterPreventScreenCapture();
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
      _screenRecordsSubscription = _preventScreenCapture.screenRecordsIOS.listen(_updateRecordStatus);
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
          final captured = call.arguments is Map ? (call.arguments['captured'] == true) : false;
          setState(() => isRecording = captured);
        }
      });
      timer = Timer.periodic(const Duration(seconds: 1), (_) async {
        try {
          final captured = await channel.invokeMethod<bool>('isCaptured') ?? false;
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
              style: TextStyle(color: kBrandRose, fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class CartItem {
  CartItem({required this.photoId, required this.number, this.previewUrl, this.quantity = 1});
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
  StripeIntentPayload({required this.orderCode, required this.clientSecret, required this.publishableKey});
  final String orderCode;
  final String clientSecret;
  final String publishableKey;

  factory StripeIntentPayload.fromJson(Map<String, dynamic> j) => StripeIntentPayload(
    orderCode: j['order_code'] as String? ?? '',
    clientSecret: j['client_secret'] as String? ?? '',
    publishableKey: j['publishable_key'] as String? ?? '',
  );
}

class StripeCheckoutPayload {
  StripeCheckoutPayload({required this.orderCode, required this.checkoutUrl});
  final String orderCode;
  final String checkoutUrl;

  factory StripeCheckoutPayload.fromJson(Map<String, dynamic> j) => StripeCheckoutPayload(
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
      next[photo.id] = CartItem(photoId: photo.id, number: photo.number, previewUrl: photo.previewUrl, quantity: 1);
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
  ApiService(this.baseUrl)
    : dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

  final String baseUrl;
  final Dio dio;

  Uri get _publicBaseUri {
    final normalized = baseUrl.endsWith('/api') ? baseUrl.substring(0, baseUrl.length - 4) : baseUrl;
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
    final isLocalHost = parsed.host == '127.0.0.1' || parsed.host == 'localhost';
    if (!isLocalHost) return url;

    final scheme = _publicBaseUri.scheme.isNotEmpty ? _publicBaseUri.scheme : parsed.scheme;
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

  Future<PhotosPage> eventPhotosPage(int eventId, String token, {String search = '', int page = 1, int perPage = 50}) async {
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

  Future<List<PhotoItem>> faceSearch(int eventId, String token, String selfiePath) async {
    final form = FormData.fromMap({
      'selfie': await MultipartFile.fromFile(selfiePath, filename: 'selfie.jpg'),
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
    final list = (r.data['suggested'] as List? ?? []).cast<Map<String, dynamic>>();
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
      'photo_items': photoItems.map((i) => {'photo_id': i.photoId, 'quantity': i.quantity}).toList(),
    };

    final r = await dio.post(
      '/public/orders/stripe-intent',
      data: payload,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 201) throw _errorFromResponse(r);
    return StripeIntentPayload.fromJson((r.data as Map).cast<String, dynamic>());
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
      'photo_items': photoItems.map((i) => {'photo_id': i.photoId, 'quantity': i.quantity}).toList(),
    };

    final r = await dio.post(
      '/public/orders/stripe-checkout',
      data: payload,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 201) throw _errorFromResponse(r);
    return StripeCheckoutPayload.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<void> logClientIssue({
    required String token,
    required String message,
    Map<String, dynamic>? context,
  }) async {
    try {
      await dio.post(
        '/public/logs',
        data: {
          'message': message,
          'context': context ?? {},
        },
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
    final itemsTotal = photoItems.fold<num>(0, (sum, item) => sum + (item.quantity * pricePerPhoto));
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
      'photo_items': photoItems.map((i) => {'photo_id': i.photoId, 'quantity': i.quantity}).toList(),
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
      if (e.type == DioExceptionType.connectionError || e.error is SocketException) {
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
          'items': photoItems.map((i) => {'photo_id': i.photoId, 'price': pricePerPhoto, 'quantity': i.quantity}).toList(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        return localCode;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> offlineExportJson(String token, int eventId) async {
    final r = await dio.get('/offline/events/$eventId/export', options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<void> offlineImportFile(String token, int eventId, String filePath, String deviceId) async {
    final form = FormData.fromMap({
      'device_id': deviceId,
      'payload': await MultipartFile.fromFile(filePath, filename: 'offline.json'),
    });
    final r = await dio.post(
      '/offline/events/$eventId/import',
      data: form,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        contentType: 'multipart/form-data',
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
    final r = await dio.post('/public/orders/$orderCode/download-link', data: {'photo_id': photoId});
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final rawUrl = r.data['download_url'] as String?;
    if (rawUrl == null || rawUrl.isEmpty) {
      throw 'Resposta sem URL de download';
    }
    return _normalizeExternalUrl(rawUrl);
  }

  Future<StaffAuthResponse> staffLogin(String login, String password) async {
    final r = await dio.post('/auth/login', data: {'login': login, 'password': password});
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
    final r = await dio.put('/auth/me', data: data, options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return StaffUser.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<List<StaffOrderItem>> staffOrders(String token, int eventId, String q, String status) async {
    final r = await dio.get(
      '/events/$eventId/orders',
      queryParameters: {'q': q, if (status.isNotEmpty) 'status': status},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final list = (r.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(StaffOrderItem.fromJson).toList();
  }

  Future<bool> markOrderPaid(String token, int orderId, {int? eventId}) async {
    try {
      final r = await dio.post('/orders/$orderId/mark-paid', options: Options(headers: {'Authorization': 'Bearer $token'}));
      if (r.statusCode != 200) throw _errorFromResponse(r);
      if (r.data is Map<String, dynamic>) {
        return r.data['download_link_emailed'] == true;
      }
      return false;
    } on DioException catch (e) {
      if (eventId != null && (e.type == DioExceptionType.connectionError || e.error is SocketException)) {
        await enqueueOrderUpdate(eventId, orderId, 'paid');
        return false;
      }
      rethrow;
    }
  }

  Future<void> markOrderDelivered(String token, int orderId, {int? eventId}) async {
    try {
      final r = await dio.post('/orders/$orderId/mark-delivered', options: Options(headers: {'Authorization': 'Bearer $token'}));
      if (r.statusCode != 200) throw _errorFromResponse(r);
    } on DioException catch (e) {
      if (eventId != null && (e.type == DioExceptionType.connectionError || e.error is SocketException)) {
        await enqueueOrderUpdate(eventId, orderId, 'delivered');
        return;
      }
      rethrow;
    }
  }

  Future<List<StaffEvent>> staffEvents(String token, {String? eventType, bool assignedOnly = false, String? fromDate}) async {
    final params = <String, dynamic>{};
    final type = eventType?.trim() ?? '';
    if (type.isNotEmpty) params['event_type'] = type;
    if (assignedOnly) params['assigned_only'] = 1;
    if (fromDate != null && fromDate.isNotEmpty) params['from_date'] = fromDate;
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

  Future<void> registerDeviceToken(String token, String deviceToken, String platform, {String? deviceId}) async {
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

  Future<List<StaffEventStaff>> staffEventStaff(String token, int eventId) async {
    final r = await dio.get('/events/$eventId/staff', options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final list = (r.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(StaffEventStaff.fromJson).toList();
  }

  Future<List<StaffUser>> staffAssignableUsers(String token, int eventId) async {
    final r = await dio.get('/events/$eventId/staff/users', options: Options(headers: {'Authorization': 'Bearer $token'}));
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

  Future<void> staffRemoveEventStaff(String token, int eventId, int userId) async {
    final r = await dio.delete(
      '/events/$eventId/staff/$userId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
  }

  Future<StaffEvent> createEvent(String token, StaffEventPayload payload) async {
    final r = await dio.post('/events', data: payload.toJson(), options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 201) throw _errorFromResponse(r);
    return StaffEvent.fromJson(r.data as Map<String, dynamic>);
  }

  Future<StaffEvent> updateEvent(String token, int eventId, StaffEventPayload payload) async {
    final r = await dio.put('/events/$eventId', data: payload.toJson(), options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return StaffEvent.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deleteEvent(String token, int eventId) async {
    final r = await dio.delete('/events/$eventId', options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
  }

  Future<List<StaffPhoto>> staffEventPhotos(String token, int eventId, String search) async {
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

  Future<void> staffDeletePhoto(String token, int eventId, int photoId) async {
    final r = await dio.delete('/events/$eventId/photos/$photoId', options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
  }

  Future<int> staffBulkDeletePhotos(String token, int eventId, List<int> photoIds) async {
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

  Future<UploadStatus> staffUploadStatus(String token, int eventId, String uploadId) async {
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
    String eventDate = '',
    String eventType = '',
    String status = '',
    String q = '',
  }) async {
    final params = <String, dynamic>{};
    if (q.isNotEmpty) params['q'] = q;
    if (status.isNotEmpty) params['status'] = status;
    if (eventId != null) params['event_id'] = eventId;
    if (eventDate.isNotEmpty) params['event_date'] = eventDate;
    if (eventType.isNotEmpty) params['event_type'] = eventType;
    final r = await dio.get('/orders', queryParameters: params, options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final list = (r.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(OrderListItem.fromJson).toList();
  }

  Future<int> staffOrdersTotal(String token, {int? eventId, String status = ''}) async {
    final params = <String, dynamic>{};
    if (status.isNotEmpty) params['status'] = status;
    if (eventId != null) params['event_id'] = eventId;
    final r = await dio.get('/orders', queryParameters: params, options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return (r.data['total'] as num?)?.toInt() ?? ((r.data['data'] as List?)?.length ?? 0);
  }

  Future<StaffOrderDetail> staffOrderDetail(String token, int orderId) async {
    final r = await dio.get('/orders/$orderId', options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return StaffOrderDetail.fromJson(r.data as Map<String, dynamic>);
  }

  Future<StaffOrderDetail> updateOrder(String token, int orderId, StaffOrderUpdatePayload payload) async {
    final r = await dio.put('/orders/$orderId', data: payload.toJson(), options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return StaffOrderDetail.fromJson(r.data as Map<String, dynamic>);
  }

  Future<int> staffBulkOrderStatus(String token, List<int> orderIds, String status) async {
    final r = await dio.post(
      '/orders/bulk-status',
      data: {'order_ids': orderIds, 'status': status},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return (r.data['updated'] as int?) ?? 0;
  }

  Future<bool> staffSendDownloadLink(String token, int orderId) async {
    final r = await dio.post('/orders/$orderId/send-download-link', options: Options(headers: {'Authorization': 'Bearer $token'}));
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

  Future<List<StaffUser>> staffUsers(String token) async {
    final r = await dio.get('/users', options: Options(headers: {'Authorization': 'Bearer $token'}));
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

  Future<StaffClient> createClient(String token, StaffClientPayload payload) async {
    final r = await dio.post('/clients', data: payload.toJson(), options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 201) throw _errorFromResponse(r);
    return StaffClient.fromJson(r.data as Map<String, dynamic>);
  }

  Future<StaffClient> updateClient(String token, int clientId, StaffClientPayload payload) async {
    final r = await dio.put('/clients/$clientId', data: payload.toJson(), options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return StaffClient.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deleteClient(String token, int clientId) async {
    final r = await dio.delete('/clients/$clientId', options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
  }

  Future<StaffUser> createUser(String token, StaffUserPayload payload) async {
    final r = await dio.post('/users', data: payload.toJson(), options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 201) throw _errorFromResponse(r);
    return StaffUser.fromJson(r.data as Map<String, dynamic>);
  }

  Future<StaffUser> updateUser(String token, int userId, StaffUserPayload payload) async {
    final r = await dio.put('/users/$userId', data: payload.toJson(), options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return StaffUser.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deleteUser(String token, int userId) async {
    final r = await dio.delete('/users/$userId', options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
  }

  String _errorFromResponse(Response<dynamic> r) {
    if (r.statusCode == 302) {
      return 'Sessão inválida ou pedido incompleto. Verifica os dados e tenta novamente.';
    }

    final data = r.data;
    if (data is Map<String, dynamic>) {
      if (data['message'] is String && (data['message'] as String).trim().isNotEmpty) {
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
  EventItem({required this.id, required this.name, required this.eventDate, this.location});
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
      pricePerPhoto: e['price_per_photo'] is num ? e['price_per_photo'] as num : num.tryParse(e['price_per_photo']?.toString() ?? '') ?? 0,
      eventType: e['event_type'] as String?,
      eventMeta: e['event_meta'] is Map<String, dynamic> ? Map<String, dynamic>.from(e['event_meta']) : <String, dynamic>{},
      eventDate: e['event_date'] as String?,
      location: e['location'] as String?,
      qrToken: e['qr_token'] as String?,
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

  factory OrderDetail.fromJson(Map<String, dynamic> j) => OrderDetail(
    orderCode: j['order_code'] as String? ?? '',
    customerName: j['customer_name'] as String? ?? '',
    paymentMethod: j['payment_method'] as String? ?? '',
    status: j['status'] as String,
    totalAmount: _toNum(j['total_amount']),
    photos: ((j['photos'] as List).cast<Map<String, dynamic>>()).map(OrderPhoto.fromJson).toList(),
    itemsTotal: _toNum(j['items_total']),
    extrasTotal: _toNum(j['extras_total']),
    shippingFee: _toNum(j['shipping_fee']),
    filmFee: _toNum(j['film_fee']),
    productType: j['product_type'] as String?,
    deliveryType: j['delivery_type'] as String?,
    deliveryAddress: j['delivery_address'] as String?,
    wantsFilm: j['wants_film'] == true || j['wants_film'] == 1,
  );

  static num _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) return parsed;
    }
    return 0;
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
    quantity: j['quantity'] is int ? j['quantity'] as int : int.tryParse(j['quantity']?.toString() ?? '1') ?? 1,
  );
}

class StaffOrderItem {
  StaffOrderItem({required this.id, required this.orderCode, required this.customerName, required this.status});
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

  factory StaffAuthResponse.fromJson(Map<String, dynamic> j) => StaffAuthResponse(
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
      permissions: ((j['permissions'] as List?) ?? []).map((e) => e.toString()).toList(),
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
    marketingConsent: j['marketing_consent'] == true || j['marketing_consent'] == 1,
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
    pricePerPhoto: j['price_per_photo'] is num ? j['price_per_photo'] as num : num.tryParse(j['price_per_photo']?.toString() ?? '') ?? 0,
    basePrice: j['base_price'] == null
        ? null
        : (j['base_price'] is num
            ? j['base_price'] as num
            : num.tryParse(j['base_price'].toString())),
    isActiveToday: j['is_active_today'] == true || j['is_active_today'] == 1,
    location: j['location'] as String?,
    eventType: j['event_type'] as String?,
    eventMeta: j['event_meta'] is Map<String, dynamic> ? Map<String, dynamic>.from(j['event_meta']) : null,
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
    'event_meta': eventMeta,
    if (notes.trim().isNotEmpty) 'notes': notes.trim(),
    if (isLocked) 'is_locked': true,
  };
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

  factory UploadChunkResult.fromJson(Map<String, dynamic> j) => UploadChunkResult(
    uploaded: j['uploaded'] == true,
    receivedChunks: j['received_chunks'] as int?,
    totalChunks: j['total_chunks'] as int?,
    photo: j['photo'] is Map<String, dynamic> ? StaffPhoto.fromJson((j['photo'] as Map).cast<String, dynamic>()) : null,
  );
}

class OrderListItem {
  OrderListItem({
    required this.id,
    required this.orderCode,
    required this.customerName,
    required this.status,
    this.eventName,
    this.eventId,
    this.totalAmount,
  });
  final int id;
  final String orderCode;
  final String customerName;
  final String status;
  final String? eventName;
  final int? eventId;
  final num? totalAmount;

  factory OrderListItem.fromJson(Map<String, dynamic> j) => OrderListItem(
    id: j['id'] as int,
    orderCode: j['order_code'] as String? ?? '',
    customerName: j['customer_name'] as String? ?? '',
    status: j['status'] as String? ?? '',
    eventName: (j['event'] is Map<String, dynamic>) ? (j['event']['name'] as String?) : null,
    eventId: (j['event'] is Map<String, dynamic>) ? (j['event']['id'] as int?) : null,
    totalAmount: j['total_amount'] is num ? j['total_amount'] as num : num.tryParse(j['total_amount']?.toString() ?? ''),
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

  factory StaffOrderDetail.fromJson(Map<String, dynamic> j) => StaffOrderDetail(
    id: j['id'] as int,
    orderCode: j['order_code'] as String? ?? '',
    customerName: j['customer_name'] as String? ?? '',
    status: j['status'] as String? ?? '',
    paymentMethod: j['payment_method'] as String? ?? '',
    totalAmount: j['total_amount'] is num ? j['total_amount'] as num : num.tryParse(j['total_amount']?.toString() ?? '') ?? 0,
    photos: ((j['photos'] as List?) ?? []).cast<Map<String, dynamic>>().map(OrderPhoto.fromJson).toList(),
    eventName: (j['event'] is Map<String, dynamic>) ? (j['event']['name'] as String?) : null,
    customerEmail: j['customer_email'] as String?,
    customerPhone: j['customer_phone'] as String?,
  );
}

class StaffOrderUpdatePayload {
  StaffOrderUpdatePayload({
    required this.customerName,
    required this.status,
    this.customerEmail,
    this.customerPhone,
    this.paymentMethod,
  });
  final String customerName;
  final String status;
  final String? customerEmail;
  final String? customerPhone;
  final String? paymentMethod;

  Map<String, dynamic> toJson() => {
    'customer_name': customerName,
    'customer_email': customerEmail,
    'customer_phone': customerPhone,
    'payment_method': paymentMethod,
    'status': status,
  };
}

class StaffSyncPage extends ConsumerStatefulWidget {
  const StaffSyncPage({super.key});

  @override
  ConsumerState<StaffSyncPage> createState() => _StaffSyncPageState();
}

class _StaffSyncPageState extends ConsumerState<StaffSyncPage> {
  List<StaffEvent> _events = [];
  int? _eventId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    saveStaffLastRoute('sync', userId: ref.read(staffUserProvider)?.id);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final token = ref.read(staffTokenProvider);
    final user = ref.read(staffUserProvider);
    if (token == null || user == null) return;
    final events = await ref.read(apiProvider).staffEvents(token, assignedOnly: !_canSeeAllEvents(user));
    final visibleEvents = _filterEventsForUser(events, user);
    setState(() {
      _events = visibleEvents;
      _eventId ??= visibleEvents.isNotEmpty ? visibleEvents.first.id : null;
    });
  }

  Future<void> _exportJson() async {
    final token = ref.read(staffTokenProvider);
    if (token == null || _eventId == null) return;
    setState(() => _loading = true);
    try {
      final json = await ref.read(apiProvider).offlineExportJson(token, _eventId!);
      final file = await writeOfflineExportFile(_eventId!, json);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exportado: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro export: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadQueue() async {
    final token = ref.read(staffTokenProvider);
    if (token == null || _eventId == null) return;
    setState(() => _loading = true);
    try {
      final payload = await buildOfflinePayload(_eventId!);
      if (payload['orders'].isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sem pedidos offline.')));
        return;
      }
      final file = await writeOfflineExportFile(_eventId!, payload);
      final deviceId = await getDeviceId();
      await ref.read(apiProvider).offlineImportFile(token, _eventId!, file.path, deviceId);
      await clearOfflineQueue(_eventId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sincronizado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro sync: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadFile() async {
    final token = ref.read(staffTokenProvider);
    if (token == null || _eventId == null) return;
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null) return;
    setState(() => _loading = true);
    try {
      final deviceId = await getDeviceId();
      await ref.read(apiProvider).offlineImportFile(token, _eventId!, path, deviceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ficheiro importado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro import: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(staffUserProvider);
    if (user != null && _isPhotographerRole(user.role)) {
      return Scaffold(
        appBar: buildNavAppBar(context, 'Sincronizar'),
        body: const Center(child: Text('Sem acesso.')),
      );
    }

    return Scaffold(
      appBar: buildNavAppBar(context, 'Sincronizar'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              value: _eventId,
              decoration: const InputDecoration(labelText: 'Evento', border: OutlineInputBorder()),
              items: _events.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
              onChanged: _loading ? null : (v) => setState(() => _eventId = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _exportJson,
              child: const Text('Exportar JSON do servidor'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _loading ? null : _uploadQueue,
              child: const Text('Enviar fila offline deste dispositivo'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loading ? null : _uploadFile,
              child: const Text('Importar ficheiro JSON'),
            ),
          ],
        ),
      ),
    );
  }
}
