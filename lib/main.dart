import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_prevent_screen_capture/flutter_prevent_screen_capture.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const ProviderScope(child: Studio59App()));
}

const String kApiBaseUrl = 'https://studio59.wiredevelop.pt/api';
const Map<String, String> kStaffPermissions = {
  'clients.read': 'Ver clientes',
  'clients.write': 'Criar/editar/apagar clientes',
  'dashboard.view': 'Ver dashboard',
  'events.read': 'Ver eventos',
  'events.write': 'Criar/editar/apagar eventos',
  'uploads.manage': 'Gerir uploads',
  'photos.manage': 'Gerir fotos (apagar/retry)',
  'orders.read': 'Ver pedidos',
  'orders.write': 'Atualizar pedidos (paid/delivered/bulk)',
  'orders.download': 'Enviar link / download ZIP',
  'orders.export': 'Exportar CSV',
  'users.manage': 'Gerir utilizadores',
};
final baseUrlProvider = StateProvider<String>((_) => kApiBaseUrl);
final guestSessionProvider = StateProvider<GuestSession?>((_) => null);
final staffTokenProvider = StateProvider<String?>((_) => null);
final staffUserProvider = StateProvider<StaffUser?>((_) => null);
final apiProvider = Provider<ApiService>((ref) => ApiService(ref.watch(baseUrlProvider)));
final cartProvider = StateNotifierProvider<CartNotifier, Map<int, CartItem>>((_) => CartNotifier());
final savedOrdersProvider = StateNotifierProvider<SavedOrdersNotifier, List<String>>((_) => SavedOrdersNotifier());

class Studio59App extends ConsumerWidget {
  const Studio59App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Studio 59',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.black),
      home: const HomePage(),
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool staffUnlocked = false;
  int logoTapCount = 0;
  DateTime? firstTapAt;

  @override
  void initState() {
    super.initState();
  }

  void onLogoTap() {
    final now = DateTime.now();
    if (firstTapAt == null || now.difference(firstTapAt!) > const Duration(seconds: 3)) {
      firstTapAt = now;
      logoTapCount = 1;
    } else {
      logoTapCount += 1;
    }

    if (logoTapCount >= 5 && !staffUnlocked) {
      setState(() => staffUnlocked = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acesso staff desbloqueado.')));
    }
  }

  Future<String?> askPassword(BuildContext context) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Senha do Evento'),
        content: TextField(controller: c, obscureText: true, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Entrar')),
        ],
      ),
    );
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

  Future<void> _scanQrAndEnter() async {
    final token = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );
    if (token == null || token.isEmpty) return;
    await _enterByQrToken(token);
  }

  Future<void> _manualTokenEntry() async {
    final c = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('PIN do Evento'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          decoration: const InputDecoration(hintText: '4 dígitos'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Entrar')),
        ],
      ),
    );
    if (token == null || token.isEmpty) return;
    await _enterByPin(token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: onLogoTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.camera_alt_outlined),
              SizedBox(width: 8),
              Text('Studio 59'),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (staffUnlocked)
              FilledButton.tonal(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffLoginPage())),
                child: const Text('Acesso Staff'),
              ),
            const SizedBox(height: 10),
            const Text('Acesso ao Evento', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _scanQrAndEnter,
              child: const Text('Ler QR Code'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _manualTokenEntry,
              child: const Text('Inserir código manualmente'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Se não tiveres a app instalada, usa um tablet do fotógrafo.',
              textAlign: TextAlign.center,
            ),
          ],
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
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: QrImageView(
                data: url,
                size: 220,
                backgroundColor: Colors.white,
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

Future<String> getDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString('device_id');
  if (existing != null && existing.isNotEmpty) return existing;
  final id = const Uuid().v4();
  await prefs.setString('device_id', id);
  return id;
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
      appBar: AppBar(title: const Text('Ler QR Code')),
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
                                  color: Colors.white,
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
        appBar: AppBar(
          title: Text(session.eventName),
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
                          if (session.eventDate != null && session.eventDate!.isNotEmpty) Text('Data: ${session.eventDate}'),
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
                    onPressed: () => setState(() => search = searchController.text.trim()),
                    icon: const Icon(Icons.search),
                  ),
                ),
                onSubmitted: (v) => setState(() => search = v.trim()),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<PhotoItem>>(
                future: ref.read(apiProvider).eventPhotos(widget.eventId, session.token, search: search),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
                    return const Center(child: CircularProgressIndicator());
                  }
                  final photos = snap.data!;
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
                                            color: Colors.white,
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
                                      color: isSelected ? Colors.greenAccent : Colors.white,
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

                  return CustomScrollView(
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

    return Scaffold(
      appBar: AppBar(title: const Text('Carrinho')),
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
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total: €${itemsTotal.toStringAsFixed(2)}',
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
  String productType = 'digital';
  String? deliveryType;
  bool wantsFilm = false;
  final addressCtrl = TextEditingController();
  bool isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final items = cart.values.toList();
    final session = ref.watch(guestSessionProvider);
    final pricePerPhoto = session?.pricePerPhoto ?? 0;
    final itemsTotal = items.fold<num>(0, (sum, item) => sum + (item.quantity * pricePerPhoto));
    final filmFee = wantsFilm ? 30.0 : 0.0;
    final shippingFee = deliveryType == 'shipping' ? 5.0 : 0.0;
    final extrasTotal = filmFee + shippingFee;
    final total = itemsTotal + extrasTotal;
    final eventType = session?.eventType ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
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
            if (eventType == 'casamento' || eventType == 'batizado') ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                value: wantsFilm,
                onChanged: (v) => setState(() => wantsFilm = v ?? false),
                title: const Text('Filme (+30€)'),
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
              value: paymentMethod == 'mbway',
              onChanged: (_) => setState(() => paymentMethod = 'mbway'),
              title: const Text('MB Way'),
            ),
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
                      try {
                        setState(() => isSubmitting = true);
                        final session = ref.read(guestSessionProvider);
                        if (session == null) return;
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

                        final code = await ref.read(apiProvider).createOrder(
                          eventId: widget.eventId,
                          token: session.token,
                          customerName: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          email: email,
                          paymentMethod: paymentMethod,
                          photoItems: items.map((i) => CartItemPayload(photoId: i.photoId, quantity: i.quantity)).toList(),
                          pricePerPhoto: pricePerPhoto,
                          productType: productType,
                          deliveryType: deliveryType,
                          deliveryAddress: addressCtrl.text.trim(),
                          wantsFilm: wantsFilm,
                        );
                        await ref.read(savedOrdersProvider.notifier).add(code);
                        ref.read(cartProvider.notifier).clear();
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
                      } catch (e) {
                        if (!context.mounted) return;
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
      appBar: AppBar(title: const Text('Os meus pedidos')),
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
      final status = await Permission.photosAddOnly.request();
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied || status.isRestricted) return false;
      final photos = await Permission.photos.request();
      return photos.isGranted;
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
        appBar: AppBar(title: const Text('Ticket do Pedido')),
        body: FutureBuilder<OrderDetail>(
          future: ref.read(apiProvider).orderDetail(widget.orderCode),
          builder: (_, snap) {
            if (!snap.hasData) {
              if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
              return const Center(child: CircularProgressIndicator());
            }

            final order = snap.data!;
            final isPaid = order.status == 'paid';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.green.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isPaid ? Colors.green.shade300 : Colors.amber.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPaid ? 'Pagamento confirmado!' : 'Mostra este ecrã ao fotografo',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isPaid
                            ? 'As tuas fotos estão prontas. Vais receber/recebeste um link único no email para download dos originais.'
                            : 'Dirige-te ao fotografo, paga e mostra este ticket para ele marcar como PAID.',
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
                        Text('Pagamento: ${order.paymentMethod.toUpperCase()}'),
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
        appBar: AppBar(title: Text(orderCode)),
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
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                try {
                  final token = await ref.read(apiProvider).staffLogin(emailCtrl.text.trim(), passCtrl.text.trim());
                  ref.read(staffTokenProvider.notifier).state = token.token;
                  ref.read(staffUserProvider.notifier).state = token.user;
                  if (!context.mounted) return;
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StaffDashboardPage()));
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

class _StaffDashboardPageState extends ConsumerState<StaffDashboardPage> {
  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff'),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(staffTokenProvider.notifier).state = null;
              ref.read(staffUserProvider.notifier).state = null;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomePage()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('Olá, ${user.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (user.hasPermission('events.read'))
            _StaffMenuTile(
              title: 'Eventos',
              subtitle: 'Criar/editar eventos',
              icon: Icons.event,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffEventsPage())),
            ),
          if (user.hasPermission('uploads.manage'))
            _StaffMenuTile(
              title: 'Uploads',
              subtitle: 'Enviar fotos para eventos',
              icon: Icons.cloud_upload,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffUploadsPage())),
            ),
          if (user.hasPermission('photos.manage'))
            _StaffMenuTile(
              title: 'Fotos',
              subtitle: 'Gerir fotos e previews',
              icon: Icons.photo_library_outlined,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffPhotosPage())),
            ),
          if (user.hasPermission('orders.read'))
            _StaffMenuTile(
              title: 'Pedidos',
              subtitle: 'Filtrar e atualizar status',
              icon: Icons.receipt_long,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffOrdersPage())),
            ),
          if (user.hasPermission('users.manage'))
            _StaffMenuTile(
              title: 'Utilizadores',
              subtitle: 'CRUD utilizadores e permissões',
              icon: Icons.manage_accounts,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffUsersPage())),
            ),
          if (user.hasPermission('clients.read'))
            _StaffMenuTile(
              title: 'Clientes',
              subtitle: 'Gerir clientes',
              icon: Icons.people_outline,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffClientsPage())),
            ),
          if (user.hasPermission('events.read'))
            _StaffMenuTile(
              title: 'Sincronizar',
              subtitle: 'Exportar/Importar dados offline',
              icon: Icons.sync,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffSyncPage())),
            ),
          const Divider(height: 24),
          if (user.hasPermission('events.read'))
            FutureBuilder<List<StaffEvent>>(
              future: ref.read(apiProvider).staffEvents(token),
              builder: (_, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final events = snap.data!;
                if (events.isEmpty) return const SizedBox.shrink();
                final recent = events.take(5).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Eventos recentes', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ...recent.map((e) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.name),
                      subtitle: Text(e.eventDate),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffEventDetailPage(event: e))),
                    )),
                  ],
                );
              },
            ),
          if (user.hasPermission('orders.read'))
            FutureBuilder<List<OrderListItem>>(
              future: ref.read(apiProvider).staffOrdersList(token),
              builder: (_, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final orders = snap.data!;
                if (orders.isEmpty) return const SizedBox.shrink();
                final recent = orders.take(5).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Text('Pedidos recentes', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ...recent.map((o) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(o.customerName ?? o.orderCode),
                      subtitle: Text('${o.status} • ${(o.totalAmount ?? 0).toStringAsFixed(2)}€'),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffOrderDetailPage(orderId: o.id))),
                    )),
                  ],
                );
              },
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

class StaffEventsPage extends ConsumerStatefulWidget {
  const StaffEventsPage({super.key});

  @override
  ConsumerState<StaffEventsPage> createState() => _StaffEventsPageState();
}

class _StaffEventsPageState extends ConsumerState<StaffEventsPage> {
  Future<List<StaffEvent>>? _future;
  String? _lastToken;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final token = ref.read(staffTokenProvider);
    if (token == null) return;
    _lastToken = token;
    _future = ref.read(apiProvider).staffEvents(token);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));

    if (_future == null || _lastToken != token) {
      _lastToken = token;
      _future = ref.read(apiProvider).staffEvents(token);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: user.hasPermission('events.write')
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffEventFormPage()));
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
            final events = snap.data!;
            if (events.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [Padding(padding: EdgeInsets.all(16), child: Text('Sem eventos'))],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: events.length,
              itemBuilder: (_, i) {
                final e = events[i];
                return Card(
                  child: ListTile(
                    title: Text(e.name),
                    subtitle: Text('${e.eventDate} ${e.location ?? ''}'.trim()),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffEventDetailPage(event: e))),
                    trailing: Wrap(
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
                        if (user.hasPermission('events.write'))
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => StaffEventFormPage(event: e)));
                              _reload();
                            },
                          ),
                        if (user.hasPermission('events.write'))
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

class StaffEventFormPage extends ConsumerStatefulWidget {
  const StaffEventFormPage({super.key, this.event});
  final StaffEvent? event;

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
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhe do Evento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(event.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Data: ${event.eventDate}'),
          if (event.eventTime != null && event.eventTime!.isNotEmpty) Text('Hora: ${event.eventTime}'),
          Text('Tipo: ${event.eventType ?? '-'}'),
          Text('Preço por foto: ${event.pricePerPhoto}'),
          if (event.accessPin != null && event.accessPin!.isNotEmpty) Text('PIN: ${event.accessPin}'),
          if (event.notes != null && event.notes!.isNotEmpty) Text('Notas: ${event.notes}'),
          const SizedBox(height: 12),
          if (user != null && user.hasPermission('events.write'))
            FilledButton.tonal(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StaffEventStaffPage(event: event)),
                );
              },
              child: const Text('Gerir staff do evento'),
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
    case 'noivo_morada':
      return 'Morada do noivo';
    case 'noiva_morada':
      return 'Morada da noiva';
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
    case 'quinta_local':
      return 'Quinta';
    case 'instagram_noivos':
      return 'Instagram dos noivos';
    case 'instagram_pais':
      return 'Instagram dos pais';
    case 'numero_convidados':
      return 'Número de convidados';
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
  late final TextEditingController nameCtrl;
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
  late final TextEditingController missaHoraCtrl;
  late final TextEditingController igrejaLocalCtrl;
  late final TextEditingController quintaLocalCtrl;
  late final TextEditingController numeroConvidadosCtrl;
  late final TextEditingController tipoPacoteCtrl;
  late final TextEditingController instagramNoivosCtrl;
  late final TextEditingController instagramPaisCtrl;
  late final TextEditingController casaNoivoChegadaCtrl;
  late final TextEditingController casaNoivoSaidaCtrl;
  late final TextEditingController casaNoivaChegadaCtrl;
  late final TextEditingController casaNoivaSaidaCtrl;
  late final TextEditingController bebeNomeCtrl;
  late final TextEditingController paiNomeCtrl;
  late final TextEditingController maeNomeCtrl;
  late final TextEditingController padrinhoNomeCtrl;
  late final TextEditingController madrinhaNomeCtrl;
  late final TextEditingController contactoPaisCtrl;
  late final TextEditingController batizadoMoradaCtrl;
  bool saving = false;
  String eventType = '';
  bool isLocked = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.event?.name ?? '');
    dateCtrl = TextEditingController(text: widget.event?.eventDate ?? '');
    timeCtrl = TextEditingController(text: widget.event?.eventTime ?? '');
    pinCtrl = TextEditingController(
      text: widget.event?.accessPin?.isNotEmpty == true
          ? widget.event!.accessPin!
          : 'Gerado automaticamente ao guardar',
    );
    priceCtrl = TextEditingController(text: widget.event?.pricePerPhoto.toString() ?? '0');
    notesCtrl = TextEditingController(text: widget.event?.notes ?? '');
    eventType = widget.event?.eventType ?? '';
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
    missaHoraCtrl = TextEditingController(text: meta['missa_hora']?.toString() ?? '');
    igrejaLocalCtrl = TextEditingController(text: meta['igreja_local']?.toString() ?? '');
    quintaLocalCtrl = TextEditingController(text: meta['quinta_local']?.toString() ?? '');
    numeroConvidadosCtrl = TextEditingController(text: meta['numero_convidados']?.toString() ?? '');
    tipoPacoteCtrl = TextEditingController(text: meta['tipo_pacote']?.toString() ?? '');
    instagramNoivosCtrl = TextEditingController(text: meta['instagram_noivos']?.toString() ?? '');
    instagramPaisCtrl = TextEditingController(text: meta['instagram_pais']?.toString() ?? '');
    casaNoivoChegadaCtrl = TextEditingController(text: meta['casa_noivo_chegada']?.toString() ?? '');
    casaNoivoSaidaCtrl = TextEditingController(text: meta['casa_noivo_saida']?.toString() ?? '');
    casaNoivaChegadaCtrl = TextEditingController(text: meta['casa_noiva_chegada']?.toString() ?? '');
    casaNoivaSaidaCtrl = TextEditingController(text: meta['casa_noiva_saida']?.toString() ?? '');
    bebeNomeCtrl = TextEditingController(text: meta['bebe_nome']?.toString() ?? '');
    paiNomeCtrl = TextEditingController(text: meta['pai_nome']?.toString() ?? '');
    maeNomeCtrl = TextEditingController(text: meta['mae_nome']?.toString() ?? '');
    padrinhoNomeCtrl = TextEditingController(text: meta['padrinho_nome']?.toString() ?? '');
    madrinhaNomeCtrl = TextEditingController(text: meta['madrinha_nome']?.toString() ?? '');
    contactoPaisCtrl = TextEditingController(text: meta['contacto_pais']?.toString() ?? '');
    batizadoMoradaCtrl = TextEditingController(text: meta['morada']?.toString() ?? '');
  }

  @override
  void dispose() {
    nameCtrl.dispose();
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
    missaHoraCtrl.dispose();
    igrejaLocalCtrl.dispose();
    quintaLocalCtrl.dispose();
    numeroConvidadosCtrl.dispose();
    tipoPacoteCtrl.dispose();
    instagramNoivosCtrl.dispose();
    instagramPaisCtrl.dispose();
    casaNoivoChegadaCtrl.dispose();
    casaNoivoSaidaCtrl.dispose();
    casaNoivaChegadaCtrl.dispose();
    casaNoivaSaidaCtrl.dispose();
    bebeNomeCtrl.dispose();
    paiNomeCtrl.dispose();
    maeNomeCtrl.dispose();
    padrinhoNomeCtrl.dispose();
    madrinhaNomeCtrl.dispose();
    contactoPaisCtrl.dispose();
    batizadoMoradaCtrl.dispose();
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
      appBar: AppBar(title: Text(widget.event == null ? 'Novo Evento' : 'Editar Evento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder())),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: eventType.isEmpty ? null : eventType,
              decoration: const InputDecoration(labelText: 'Tipo Evento', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'casamento', child: Text('CASAMENTO')),
                DropdownMenuItem(value: 'batizado', child: Text('BATIZADO')),
              ],
              onChanged: (v) => setState(() => eventType = v ?? ''),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Preço por foto', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pinCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'PIN do evento (4 dígitos)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notas internas', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Detalhes adicionais', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: missaHoraCtrl,
              decoration: const InputDecoration(labelText: 'Hora da missa (HH:mm)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(controller: igrejaLocalCtrl, decoration: const InputDecoration(labelText: 'Igreja', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: quintaLocalCtrl, decoration: const InputDecoration(labelText: 'Quinta', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
              controller: numeroConvidadosCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Número de convidados', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(controller: tipoPacoteCtrl, decoration: const InputDecoration(labelText: 'Tipo de pacote (informativo)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            if (eventType == 'casamento') ...[
              TextField(controller: noivoNomeCtrl, decoration: const InputDecoration(labelText: 'Nome do noivo', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: noivaNomeCtrl, decoration: const InputDecoration(labelText: 'Nome da noiva', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: noivoContactoCtrl, decoration: const InputDecoration(labelText: 'Contacto do noivo', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: noivaContactoCtrl, decoration: const InputDecoration(labelText: 'Contacto da noiva', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: noivoProfissaoCtrl, decoration: const InputDecoration(labelText: 'Profissão do noivo', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: noivaProfissaoCtrl, decoration: const InputDecoration(labelText: 'Profissão da noiva', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: noivoMoradaCtrl, decoration: const InputDecoration(labelText: 'Morada do noivo', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: noivaMoradaCtrl, decoration: const InputDecoration(labelText: 'Morada da noiva', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: instagramNoivosCtrl, decoration: const InputDecoration(labelText: 'Instagram dos noivos', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(
                controller: casaNoivoChegadaCtrl,
                decoration: const InputDecoration(labelText: 'Casa do noivo: hora de chegada (HH:mm)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: casaNoivoSaidaCtrl,
                decoration: const InputDecoration(labelText: 'Casa do noivo: hora de saída (HH:mm)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: casaNoivaChegadaCtrl,
                decoration: const InputDecoration(labelText: 'Casa da noiva: hora de chegada (HH:mm)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: casaNoivaSaidaCtrl,
                decoration: const InputDecoration(labelText: 'Casa da noiva: hora de saída (HH:mm)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
            ],
            if (eventType == 'batizado') ...[
              TextField(controller: bebeNomeCtrl, decoration: const InputDecoration(labelText: 'Nome do bebé', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: paiNomeCtrl, decoration: const InputDecoration(labelText: 'Nome do pai', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: maeNomeCtrl, decoration: const InputDecoration(labelText: 'Nome da mãe', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: padrinhoNomeCtrl, decoration: const InputDecoration(labelText: 'Nome do padrinho', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: madrinhaNomeCtrl, decoration: const InputDecoration(labelText: 'Nome da madrinha', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: contactoPaisCtrl, decoration: const InputDecoration(labelText: 'Contacto dos pais', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: batizadoMoradaCtrl, decoration: const InputDecoration(labelText: 'Morada', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: instagramPaisCtrl, decoration: const InputDecoration(labelText: 'Instagram dos pais', border: OutlineInputBorder())),
              const SizedBox(height: 8),
            ],
            if (widget.event != null && _isTodayOrPast(dateCtrl.text)) ...[
              SwitchListTile(
                value: isLocked,
                onChanged: (v) => setState(() => isLocked = v),
                title: const Text('Bloqueado'),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                    final price = num.tryParse(priceCtrl.text.trim()) ?? 0;
                    final meta = Map<String, dynamic>.from(widget.event?.eventMeta ?? {});
                    void setMeta(String key, TextEditingController ctrl) {
                      final value = ctrl.text.trim();
                      if (value.isEmpty) {
                        meta.remove(key);
                      } else {
                        meta[key] = value;
                      }
                    }
                    const weddingKeys = [
                      'noivo_nome',
                      'noiva_nome',
                      'noivo_contacto',
                      'noiva_contacto',
                      'noivo_profissao',
                      'noiva_profissao',
                      'noivo_morada',
                      'noiva_morada',
                      'instagram_noivos',
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

                    setMeta('missa_hora', missaHoraCtrl);
                    setMeta('igreja_local', igrejaLocalCtrl);
                    setMeta('quinta_local', quintaLocalCtrl);
                    setMeta('numero_convidados', numeroConvidadosCtrl);
                    setMeta('tipo_pacote', tipoPacoteCtrl);
                    if (eventType == 'casamento') {
                      for (final key in baptKeys) {
                        meta.remove(key);
                      }
                      setMeta('noivo_nome', noivoNomeCtrl);
                      setMeta('noiva_nome', noivaNomeCtrl);
                      setMeta('noivo_contacto', noivoContactoCtrl);
                      setMeta('noiva_contacto', noivaContactoCtrl);
                      setMeta('noivo_profissao', noivoProfissaoCtrl);
                      setMeta('noiva_profissao', noivaProfissaoCtrl);
                      setMeta('noivo_morada', noivoMoradaCtrl);
                      setMeta('noiva_morada', noivaMoradaCtrl);
                      setMeta('instagram_noivos', instagramNoivosCtrl);
                      setMeta('casa_noivo_chegada', casaNoivoChegadaCtrl);
                      setMeta('casa_noivo_saida', casaNoivoSaidaCtrl);
                      setMeta('casa_noiva_chegada', casaNoivaChegadaCtrl);
                      setMeta('casa_noiva_saida', casaNoivaSaidaCtrl);
                    }
                    if (eventType == 'batizado') {
                      for (final key in weddingKeys) {
                        meta.remove(key);
                      }
                      setMeta('bebe_nome', bebeNomeCtrl);
                      setMeta('pai_nome', paiNomeCtrl);
                      setMeta('mae_nome', maeNomeCtrl);
                      setMeta('padrinho_nome', padrinhoNomeCtrl);
                      setMeta('madrinha_nome', madrinhaNomeCtrl);
                      setMeta('contacto_pais', contactoPaisCtrl);
                      setMeta('morada', batizadoMoradaCtrl);
                      setMeta('instagram_pais', instagramPaisCtrl);
                    }
                    if (eventType == 'casamento') {
                      final required = [
                        noivoNomeCtrl.text,
                        noivaNomeCtrl.text,
                        noivoContactoCtrl.text,
                        noivaContactoCtrl.text,
                        noivoProfissaoCtrl.text,
                        noivaProfissaoCtrl.text,
                        noivoMoradaCtrl.text,
                        noivaMoradaCtrl.text,
                      ];
                      if (required.any((v) => v.trim().isEmpty)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Preenche todos os dados do casamento.')),
                        );
                        return;
                      }
                    }
                    if (eventType == 'batizado') {
                      final required = [
                        bebeNomeCtrl.text,
                        paiNomeCtrl.text,
                        maeNomeCtrl.text,
                        padrinhoNomeCtrl.text,
                        madrinhaNomeCtrl.text,
                        contactoPaisCtrl.text,
                        batizadoMoradaCtrl.text,
                      ];
                      if (required.any((v) => v.trim().isEmpty)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Preenche todos os dados do batizado.')),
                        );
                        return;
                      }
                    }
                    final payload = StaffEventPayload(
                      name: nameCtrl.text.trim(),
                      eventDate: dateCtrl.text.trim(),
                      eventTime: timeCtrl.text.trim(),
                      pricePerPhoto: price,
                      eventType: eventType,
                      eventMeta: meta,
                      notes: notesCtrl.text.trim(),
                      isLocked: isLocked,
                    );
                      if (payload.name.isEmpty || payload.eventDate.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome e data são obrigatórios.')));
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
    );
  }
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
    if (token == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));

    return Scaffold(
      appBar: AppBar(title: Text('Staff • ${widget.event.name}')),
      body: FutureBuilder<_StaffStaffData>(
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
      ),
    );
  }
}

class _StaffStaffData {
  const _StaffStaffData({required this.staff, required this.users});
  final List<StaffEventStaff> staff;
  final List<StaffUser> users;
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

  Future<List<StaffEvent>> _loadEvents(String token) => ref.read(apiProvider).staffEvents(token);

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    if (token == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uploads'),
        actions: [
          IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: FutureBuilder<List<StaffEvent>>(
        future: _loadEvents(token),
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
          final events = snap.data!;
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
                onChanged: uploading ? null : (v) => setState(() => eventId = v),
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
                        });
                        try {
                          for (final file in files) {
                            await _uploadFile(token, eventId!, File(file.path));
                          }
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploads concluídos.')));
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
            ],
          );
        },
      ),
      ),
    );
  }

  Future<void> _uploadFile(String token, int eventId, File file) async {
    final fileName = file.path.split('/').last;
    final length = await file.length();
    const chunkSize = 1024 * 512;
    final totalChunks = (length / chunkSize).ceil();
    final uploadId = _generateUploadId();
    final raf = await file.open();
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

  Future<List<StaffEvent>> _loadEvents(String token) => ref.read(apiProvider).staffEvents(token);

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    if (token == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotos'),
        actions: [
          IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: FutureBuilder<List<StaffEvent>>(
        future: _loadEvents(token),
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
          final events = snap.data!;
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
  int? eventId;
  String status = '';
  final queryCtrl = TextEditingController();
  final selected = <int>{};

  @override
  void dispose() {
    queryCtrl.dispose();
    super.dispose();
  }

  Future<List<StaffEvent>> _loadEvents(String token) => ref.read(apiProvider).staffEvents(token);

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    final user = ref.watch(staffUserProvider);
    if (token == null || user == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));
    final canWrite = user.hasPermission('orders.write');
    final canDownload = user.hasPermission('orders.download');
    final canExport = user.hasPermission('orders.export');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos'),
        actions: [
          IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: FutureBuilder<List<StaffEvent>>(
        future: _loadEvents(token),
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
          final events = snap.data!;
          if (events.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [Padding(padding: EdgeInsets.all(16), child: Text('Sem eventos'))],
            );
          }
          if (eventId != null && !events.any((e) => e.id == eventId)) {
            eventId = events.first.id;
          }
          eventId ??= events.isNotEmpty ? events.first.id : null;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    DropdownButtonFormField<int?>(
                      value: eventId,
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Todos eventos')),
                        ...events.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))),
                      ],
                      onChanged: (v) => setState(() => eventId = v),
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Evento'),
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
                      onSubmitted: (_) => setState(() {}),
                    ),
                    if (canExport && eventId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FilledButton.tonal(
                          onPressed: () async {
                            final path = await ref.read(apiProvider).staffExportOrdersCsv(token, eventId!);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV guardado em: $path')));
                          },
                          child: const Text('Exportar CSV do evento'),
                        ),
                      ),
                    if (selected.isNotEmpty && canWrite)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
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
                  future: ref.read(apiProvider).staffOrdersList(token, eventId: eventId, status: status, q: queryCtrl.text.trim()),
                  builder: (_, orderSnap) {
                    if (!orderSnap.hasData) {
                      if (orderSnap.hasError) return Center(child: Text('Erro: ${orderSnap.error}'));
                      return const Center(child: CircularProgressIndicator());
                    }
                    final orders = orderSnap.data!;
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
                            subtitle: Text('Status: ${o.status} ${o.eventName ?? ''}'.trim()),
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
                                if (canWrite && o.status != 'paid' && o.status != 'delivered')
                                  FilledButton(
                                    onPressed: () async {
                                      final emailed = await ref.read(apiProvider).markOrderPaid(token, o.id, eventId: o.eventId ?? eventId);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(emailed ? 'Marcado pago e link enviado.' : 'Marcado pago. Sem email.')),
                                      );
                                      setState(() {});
                                    },
                                    child: const Text('Pago'),
                                  ),
                                if (canWrite && o.status == 'paid')
                                  OutlinedButton(
                                    onPressed: () async {
                                      await ref.read(apiProvider).markOrderDelivered(token, o.id, eventId: o.eventId ?? eventId);
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
    final canWrite = user.hasPermission('orders.write');
    final canDownload = user.hasPermission('orders.download');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedido'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _loadDetail(token)),
            icon: const Icon(Icons.refresh),
          ),
          if (canWrite)
            IconButton(
              onPressed: () => setState(() => editing = !editing),
              icon: Icon(editing ? Icons.close : Icons.edit),
            ),
        ],
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
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
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
                    subtitle: Text('${u.email} • ${u.role}'),
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
  late final TextEditingController emailCtrl;
  late final TextEditingController passwordCtrl;
  String role = 'staff';
  final selectedPermissions = <String>{};
  bool saving = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.user?.name ?? '');
    emailCtrl = TextEditingController(text: widget.user?.email ?? '');
    passwordCtrl = TextEditingController();
    role = widget.user?.role ?? 'staff';
    if (widget.user != null) {
      selectedPermissions.addAll(widget.user!.permissions);
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(staffTokenProvider);
    if (token == null) return const Scaffold(body: Center(child: Text('Sem sessao staff')));

    return Scaffold(
      appBar: AppBar(title: Text(widget.user == null ? 'Novo utilizador' : 'Editar utilizador')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder())),
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
                DropdownMenuItem(value: 'staff', child: Text('staff')),
                DropdownMenuItem(value: 'admin', child: Text('admin')),
              ],
              onChanged: (v) => setState(() => role = v ?? 'staff'),
              decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            const Text('Permissões', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...kStaffPermissions.entries.map((e) => CheckboxListTile(
              value: selectedPermissions.contains(e.key),
              onChanged: (v) => setState(() {
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
        actions: [
          IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: user.hasPermission('clients.write')
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
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => StaffClientFormPage(client: c)));
                            setState(() {});
                          },
                          trailing: user.hasPermission('clients.write')
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
      appBar: AppBar(title: Text(widget.client == null ? 'Novo cliente' : 'Editar cliente')),
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
            color: Colors.black.withOpacity(0.9),
            alignment: Alignment.center,
            child: const Text(
              'Conteúdo protegido\nCaptura de ecrã detetada',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
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

  Future<GuestSession> enterEvent(int id, String password) async {
    final r = await dio.post('/public/events/$id/enter', data: {'password': password});
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

  Future<List<PhotoItem>> eventPhotos(int eventId, String token, {String search = ''}) async {
    final r = await dio.get('/public/events/$eventId/photos', queryParameters: {'search': search}, options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final list = (r.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map((json) {
      final map = Map<String, dynamic>.from(json);
      final preview = map['preview_url'] as String?;
      if (preview != null && preview.isNotEmpty) {
        map['preview_url'] = _normalizeExternalUrl(preview);
      }
      return PhotoItem.fromJson(map);
    }).toList();
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

  Future<StaffAuthResponse> staffLogin(String email, String password) async {
    final r = await dio.post('/auth/login', data: {'email': email, 'password': password});
    if (r.statusCode != 200) throw _errorFromResponse(r);
    return StaffAuthResponse.fromJson(r.data as Map<String, dynamic>);
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

  Future<List<StaffEvent>> staffEvents(String token) async {
    final r = await dio.get('/events', options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final list = (r.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(StaffEvent.fromJson).toList();
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

  Future<List<OrderListItem>> staffOrdersList(String token, {int? eventId, String status = '', String q = ''}) async {
    final params = <String, dynamic>{'q': q};
    if (status.isNotEmpty) params['status'] = status;
    if (eventId != null) params['event_id'] = eventId;
    final r = await dio.get('/orders', queryParameters: params, options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _errorFromResponse(r);
    final list = (r.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(OrderListItem.fromJson).toList();
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
  StaffUser({required this.id, required this.name, required this.email, required this.role, required this.permissions});
  final int id;
  final String name;
  final String email;
  final String role;
  final List<String> permissions;

  factory StaffUser.fromJson(Map<String, dynamic> j) => StaffUser(
    id: j['id'] as int,
    name: j['name'] as String? ?? '',
    email: j['email'] as String? ?? '',
    role: j['role'] as String? ?? 'staff',
    permissions: ((j['permissions'] as List?) ?? []).map((e) => e.toString()).toList(),
  );

  bool hasPermission(String permission) => permissions.contains(permission);
}

class StaffUserPayload {
  StaffUserPayload({
    required this.name,
    required this.email,
    required this.role,
    required this.permissions,
    this.password,
  });
  final String name;
  final String email;
  final String role;
  final List<String> permissions;
  final String? password;

  Map<String, dynamic> toJson() => {
    'name': name,
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
    required this.eventDate,
    this.eventTime,
    required this.pricePerPhoto,
    required this.isActiveToday,
    this.location,
    this.accessPassword,
    this.eventType,
    this.eventMeta,
    this.qrToken,
    this.accessPin,
    this.notes,
    this.isLocked = false,
  });
  final int id;
  final String name;
  final String eventDate;
  final String? eventTime;
  final num pricePerPhoto;
  final bool isActiveToday;
  final String? location;
  final String? accessPassword;
  final String? eventType;
  final Map<String, dynamic>? eventMeta;
  final String? qrToken;
  final String? accessPin;
  final String? notes;
  final bool isLocked;

  factory StaffEvent.fromJson(Map<String, dynamic> j) => StaffEvent(
    id: j['id'] as int,
    name: j['name'] as String? ?? '',
    eventDate: j['event_date'] as String? ?? '',
    eventTime: j['event_time'] as String?,
    pricePerPhoto: j['price_per_photo'] is num ? j['price_per_photo'] as num : num.tryParse(j['price_per_photo']?.toString() ?? '') ?? 0,
    isActiveToday: j['is_active_today'] == true || j['is_active_today'] == 1,
    location: j['location'] as String?,
    accessPassword: j['access_password'] as String?,
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
    required this.name,
    required this.eventDate,
    required this.eventTime,
    required this.pricePerPhoto,
    required this.eventType,
    required this.eventMeta,
    required this.notes,
    required this.isLocked,
  });
  final String name;
  final String eventDate;
  final String eventTime;
  final num pricePerPhoto;
  final String eventType;
  final Map<String, dynamic> eventMeta;
  final String notes;
  final bool isLocked;

  Map<String, dynamic> toJson() => {
    'name': name,
    'event_date': eventDate,
    if (eventTime.trim().isNotEmpty) 'event_time': eventTime.trim(),
    'price_per_photo': pricePerPhoto,
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
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final token = ref.read(staffTokenProvider);
    if (token == null) return;
    final events = await ref.read(apiProvider).staffEvents(token);
    setState(() {
      _events = events;
      _eventId ??= events.isNotEmpty ? events.first.id : null;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Sincronizar')),
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
