// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/ff_builtin_enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart' hide RepeatMode;
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/app_state.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class Studio59GuestGallery extends StatefulWidget {
  const Studio59GuestGallery({super.key, this.width, this.height});
  final double? width;
  final double? height;
  @override
  State<Studio59GuestGallery> createState() => _Studio59GuestGalleryState();
}

class _GalleryScrollBehavior extends MaterialScrollBehavior {
  const _GalleryScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

class _Studio59GuestGalleryState extends State<Studio59GuestGallery> {
  String get _base => (FFAppState().offlineApiBase.isNotEmpty
      ? FFAppState().offlineApiBase
      : 'https://studio59.wiredevelop.pt/api');
  static const _rose = Color(0xFFB77F84);
  final _controller = ScrollController();
  final List<Map<String, dynamic>> _photos = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _lastPage = 1;
  // Pesquisa facial: null = catálogo completo; lista = fotos encontradas pela selfie.
  List<Map<String, dynamic>>? _faceResults;
  bool _faceSearching = false;
  String? _faceMessage;
  // Sessão offline: estado da análise das fotografias no computador anfitrião.
  Map<String, dynamic>? _faceStatus;
  Timer? _faceTimer;

  @override
  void initState() {
    super.initState();
    _load(1);
    _pollFaceStatus();
  }

  @override
  void dispose() {
    _faceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};
  Future<void> _load(int page) async {
    final eventId = FFAppState().guestEvent.id;
    final token = FFAppState().guestSessionToken.trim();
    if (eventId <= 0 || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'A sessão do evento terminou. Volte a introduzir o PIN.';
      });
      return;
    }
    setState(() {
      if (page == 1)
        _loading = true;
      else
        _loadingMore = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('$_base/public/events/$eventId/photos')
            .replace(queryParameters: {'page': '$page', 'per_page': '50'}),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 25));
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {}
      if (response.statusCode == 401)
        throw StateError(
            'A sessão do evento terminou. Volte a introduzir o PIN.');
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded is! Map) {
        throw StateError(decoded is Map && decoded['message'] != null
            ? '${decoded['message']}'
            : 'Não foi possível carregar a galeria (${response.statusCode}).');
      }
      final body = _map(decoded);
      final data = body['data'];
      final rows = data is List
          ? data
          : data is Map && data['data'] is List
              ? data['data'] as List
              : const [];
      final meta = data is Map ? _map(data) : body;
      final incoming = rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      if (!mounted) return;
      setState(() {
        if (page == 1) _photos.clear();
        final known = _photos.map((photo) => '${photo['id']}').toSet();
        _photos.addAll(
            incoming.where((photo) => !known.contains('${photo['id']}')));
        _page = int.tryParse('${meta['current_page'] ?? page}') ?? page;
        _lastPage = int.tryParse('${meta['last_page'] ?? page}') ?? page;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error = error is StateError
              ? error.message.toString()
              : 'Não foi possível contactar o servidor.';
        });
    }
  }

  bool get _offline => FFAppState().offlineApiBase.isNotEmpty;
  bool get _faceReady =>
      !_offline || _faceStatus == null || _faceStatus!['ready'] == true;

  Future<void> _pollFaceStatus() async {
    _faceTimer?.cancel();
    if (!_offline) return;
    final eventId = FFAppState().guestEvent.id;
    final token = FFAppState().guestSessionToken.trim();
    if (eventId <= 0 || token.isEmpty) return;
    try {
      final response = await http.get(
          Uri.parse('$_base/public/events/$eventId/face-status'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token'
          }).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (response.statusCode == 404) {
        setState(() => _faceStatus =
            null); // anfitrião antigo: sem estado, o botão funciona como antes
        return;
      }
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body is Map)
        setState(() => _faceStatus = Map<String, dynamic>.from(body));
    } catch (_) {}
    if (mounted && !_faceReady)
      _faceTimer = Timer(const Duration(seconds: 8), _pollFaceStatus);
  }

  String _etaText(int seconds) {
    if (seconds <= 60) return 'menos de 1 minuto';
    final minutes = (seconds / 60).ceil();
    return minutes == 1 ? 'cerca de 1 minuto' : 'cerca de $minutes minutos';
  }

  void _faceNotReady() {
    final s = _faceStatus ?? const {};
    final problem = s['problem'];
    final text = problem != null
        ? 'A pesquisa por rosto não está disponível nesta sessão. Pode procurar as suas fotografias no catálogo.'
        : 'A pesquisa por rosto fica disponível dentro de ${_etaText((s['eta_seconds'] as num?)?.toInt() ?? 0)}. '
            'Já analisámos ${s['indexed'] ?? 0} de ${s['total'] ?? 0} fotografias.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF4A3F3C),
          duration: const Duration(seconds: 5),
          content: Row(children: [
            const Icon(Icons.hourglass_top, color: Colors.white70),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
          ])));
    _pollFaceStatus();
  }

  Future<void> _faceSearch() async {
    final eventId = FFAppState().guestEvent.id;
    final token = FFAppState().guestSessionToken.trim();
    if (eventId <= 0 || token.isEmpty || _faceSearching) return;
    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheetContext) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Encontrar as minhas fotografias',
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF292624))),
                      const SizedBox(height: 6),
                      const Text(
                          'Tire uma selfie de frente, com boa luz e sem óculos de sol. Mostramos as fotografias do evento onde aparece.',
                          style: TextStyle(color: Color(0xFF6D625F))),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                          onPressed: () =>
                              Navigator.pop(sheetContext, ImageSource.camera),
                          style: FilledButton.styleFrom(
                              backgroundColor: _rose,
                              padding: const EdgeInsets.all(16)),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Tirar selfie')),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.pop(sheetContext, ImageSource.gallery),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: _rose,
                              side: const BorderSide(color: _rose),
                              padding: const EdgeInsets.all(16)),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Escolher uma fotografia')),
                    ]))));
    if (source == null || !mounted) return;
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
          source: source,
          preferredCameraDevice: CameraDevice.front,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 85,
          requestFullMetadata: false);
    } catch (_) {
      if (source == ImageSource.camera) {
        try {
          picked = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 1280,
              maxHeight: 1280,
              imageQuality: 85,
              requestFullMetadata: false);
        } catch (_) {}
      }
    }
    if (picked == null || !mounted) return;
    setState(() {
      _faceSearching = true;
      _faceMessage = null;
    });
    studio59Offline(
        'log',
        jsonEncode({
          'action': 'face.search',
          'message': 'Pesquisa facial no catálogo'
        }));
    try {
      final bytes = await picked.readAsBytes();
      final request = http.MultipartRequest(
          'POST', Uri.parse('$_base/public/events/$eventId/face-search'))
        ..headers.addAll(
            {'Accept': 'application/json', 'Authorization': 'Bearer $token'})
        ..files.add(http.MultipartFile.fromBytes('selfie', bytes,
            filename: 'selfie.jpg'));
      final streamed =
          await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamed);
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {}
      if (response.statusCode == 401)
        throw StateError(
            'A sessão do evento terminou. Volte a introduzir o PIN.');
      if (response.statusCode == 404 || response.statusCode == 405) {
        throw StateError(
            'A pesquisa por rosto ainda não está disponível nesta ligação.');
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded is! Map) {
        throw StateError(decoded is Map && decoded['message'] != null
            ? '${decoded['message']}'
            : 'Não foi possível pesquisar (${response.statusCode}).');
      }
      final rows = decoded['suggested'] is List
          ? decoded['suggested'] as List
          : const [];
      final results = rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final pending = int.tryParse('${decoded['pending'] ?? 0}') ?? 0;
      if (!mounted) return;
      setState(() {
        _faceSearching = false;
        _faceResults = results;
        _faceMessage = results.isEmpty
            ? 'Não encontrámos fotografias suas. Tente outra selfie, de frente e com boa luz.'
            : '${results.length} ${results.length == 1 ? 'fotografia encontrada' : 'fotografias encontradas'}';
        if (pending > 0)
          _faceMessage =
              '$_faceMessage · Ainda estamos a analisar $pending fotografias; tente de novo daqui a pouco.';
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _faceSearching = false;
          _faceMessage = error is StateError
              ? error.message.toString()
              : 'Não foi possível contactar o servidor.';
        });
    }
  }

  void _clearFaceSearch() => setState(() {
        _faceResults = null;
        _faceMessage = null;
      });

  bool _inCart(int id) =>
      FFAppState().guestCart.any((item) => item.photoId == id);
  void _add(Map<String, dynamic> photo) {
    final id = int.tryParse('${photo['id']}');
    if (id == null || id <= 0) return;
    if (_inCart(id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Esta fotografia já está no carrinho.')));
      return;
    }
    FFAppState()
        .update(() => FFAppState().addToGuestCart(Studio59CartPhotoStruct(
              photoId: id,
              filename:
                  '${photo['number'] ?? photo['filename'] ?? 'Fotografia $id'}',
              previewUrl: '${photo['preview_url'] ?? ''}',
              quantity: 1,
            )));
    setState(() {});
    studio59Offline(
        'log',
        jsonEncode({
          'action': 'cart.add',
          'message':
              'Adicionou ${photo['number'] ?? photo['filename'] ?? id} ao carrinho'
        }));
  }

  /// Abre a fotografia em ecrã inteiro: zoom com dois dedos ou duplo toque, deslizar para a seguinte.
  Future<void> _preview(
      Map<String, dynamic> photo, List<Map<String, dynamic>> list) async {
    studio59Offline(
        'log',
        jsonEncode({
          'action': 'photo.open',
          'message':
              'Abriu a fotografia ${photo['number'] ?? photo['filename'] ?? photo['id']}'
        }));
    final start = list.indexWhere((p) => '${p['id']}' == '${photo['id']}');
    await Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => _PhotoViewer(
        photos: list,
        initialIndex: start < 0 ? 0 : start,
        inCart: _inCart,
        onAdd: (p) {
          _add(p);
        },
      ),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ));
    if (mounted) setState(() {});
  }

  /// Tutorial passo a passo (só aparece quando o convidado toca em «Ajuda»).
  Future<void> _showTour() async {
    const steps = [
      (
        Icons.touch_app_outlined,
        'Ver uma fotografia em grande',
        'Toque numa fotografia para a abrir em ecrã inteiro. Afaste dois dedos (ou toque duas vezes) para aproximar e deslize para o lado para ver a seguinte.'
      ),
      (
        Icons.add_circle_outline,
        'Escolher fotografias',
        'Toque no sinal + por baixo da fotografia, ou em «Adicionar ao carrinho» quando ela está aberta. As escolhidas ficam com um visto.'
      ),
      (
        Icons.face_retouching_natural,
        'Encontrar as suas fotografias',
        'Toque em «Encontrar as minhas fotos» e tire uma selfie. Mostramos as fotografias onde aparece. Pode tirar a selfie com mais pessoas.'
      ),
      (
        Icons.shopping_bag_outlined,
        'Ver o carrinho',
        'O botão «Ver carrinho», sempre visível no fundo do ecrã, mostra as fotografias escolhidas. Aí escolhe as quantidades e conclui o pedido.'
      ),
      (
        Icons.receipt_long_outlined,
        'Depois do pedido',
        'No fim recebe um código. Dirija-se ao fotógrafo para pagar e entregue o iPad à próxima pessoa da sua mesa.'
      ),
    ];
    var index = 0;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) =>
            StatefulBuilder(builder: (dialogContext, update) {
              final step = steps[index];
              final last = index == steps.length - 1;
              return AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
                content: SizedBox(
                    width: 460,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(
                              color: Color(0xFFF6ECEC), shape: BoxShape.circle),
                          child: Icon(step.$1, color: _rose, size: 52)),
                      const SizedBox(height: 18),
                      Text(step.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF292624))),
                      const SizedBox(height: 12),
                      Text(step.$3,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 19,
                              height: 1.4,
                              color: Color(0xFF292624))),
                      const SizedBox(height: 18),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                              steps.length,
                              (i) => Container(
                                  width: i == index ? 22 : 10,
                                  height: 10,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(
                                      color: i == index
                                          ? _rose
                                          : const Color(0xFFE5D8D8),
                                      borderRadius:
                                          BorderRadius.circular(5))))),
                    ])),
                actionsAlignment: MainAxisAlignment.spaceBetween,
                actions: [
                  TextButton(
                      onPressed: index == 0
                          ? () => Navigator.pop(dialogContext)
                          : () => update(() => index--),
                      child: Text(index == 0 ? 'Fechar' : 'Anterior',
                          style: const TextStyle(
                              fontSize: 18, color: Color(0xFF6D625F)))),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: _rose,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 26, vertical: 16)),
                      onPressed: last
                          ? () => Navigator.pop(dialogContext)
                          : () => update(() => index++),
                      child: Text(last ? 'Começar' : 'Seguinte',
                          style: const TextStyle(fontSize: 18))),
                ],
              );
            }));
  }

  Future<void> _exit() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Sair do catálogo?'),
              content: Text(FFAppState().guestCart.isEmpty
                  ? 'Vai voltar ao ecrã inicial.'
                  : 'As ${FFAppState().guestCart.length} fotografias selecionadas serão removidas do carrinho.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancelar',
                        style: TextStyle(color: Color(0xFF6D625F)))),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: FilledButton.styleFrom(backgroundColor: _rose),
                    child: const Text('Sair')),
              ],
            ));
    if (confirmed != true || !mounted) return;
    FFAppState().update(() {
      FFAppState().guestCart = [];
      FFAppState().guestSessionToken = '';
      FFAppState().guestEvent = Studio59EventInfoStruct();
      FFAppState().lastGuestOrder = Studio59OrderReceiptStruct();
    });
    context.goNamed('WelcomeScreen');
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100
        ? 5
        : width >= 760
            ? 4
            : width >= 520
                ? 3
                : 2;
    final price = FFAppState().guestEvent.pricePerPhoto;
    final shown = _faceResults ?? _photos;
    final cartCount = FFAppState().guestCart.length;
    return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Column(children: [
          Expanded(
              child: ScrollConfiguration(
            behavior: const _GalleryScrollBehavior(),
            child: CustomScrollView(
                controller: _controller,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      sliver: SliverToBoxAdapter(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                      onPressed: _showTour,
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor: _rose,
                                          side: const BorderSide(color: _rose),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12))),
                                      icon: const Icon(Icons.help_outline,
                                          size: 18),
                                      label: const Text('Ajuda')),
                                  FilledButton.icon(
                                      onPressed: _faceSearching
                                          ? null
                                          : (_faceReady
                                              ? _faceSearch
                                              : _faceNotReady),
                                      style: FilledButton.styleFrom(
                                          backgroundColor: _faceReady
                                              ? _rose
                                              : const Color(0xFFD9CFCD),
                                          foregroundColor: _faceReady
                                              ? Colors.white
                                              : const Color(0xFF6D625F),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12))),
                                      icon: _faceSearching
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white))
                                          : Icon(
                                              _faceReady
                                                  ? Icons
                                                      .face_retouching_natural
                                                  : Icons.hourglass_top,
                                              size: 18),
                                      label: Text(_faceSearching
                                          ? 'A procurar…'
                                          : 'Encontrar as minhas fotos')),
                                  OutlinedButton.icon(
                                      onPressed: _exit,
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor: _rose,
                                          side: const BorderSide(color: _rose),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12))),
                                      icon: const Icon(Icons.logout, size: 18),
                                      label: const Text('Sair do catálogo')),
                                ]),
                            const SizedBox(height: 8),
                            Text(FFAppState().guestEvent.name,
                                style: const TextStyle(
                                    color: Color(0xFF292624),
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 5),
                            Text(
                                '${price.toStringAsFixed(2).replaceAll('.', ',')} € por fotografia',
                                style:
                                    const TextStyle(color: Color(0xFF6D625F))),
                            if (_error != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Text(_error!,
                                      style: const TextStyle(
                                          color: Color(0xFF9B3D3D)))),
                            if (_faceMessage != null || _faceResults != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                        14, 10, 8, 10),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFF6ECEC),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Row(children: [
                                      const Icon(Icons.face_retouching_natural,
                                          color: _rose, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: Text(_faceMessage ?? '',
                                              style: const TextStyle(
                                                  color: Color(0xFF292624)))),
                                      if (_faceResults != null)
                                        TextButton(
                                            onPressed: _clearFaceSearch,
                                            child: const Text('Ver todas',
                                                style: TextStyle(
                                                    color: _rose,
                                                    fontWeight:
                                                        FontWeight.w600))),
                                    ]),
                                  )),
                          ]))),
                  if (_loading)
                    const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CupertinoActivityIndicator()))
                  else if (shown.isEmpty)
                    SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                            child: Text(_faceResults != null
                                ? 'Sem fotografias encontradas para esta selfie.'
                                : 'Não existem fotografias disponíveis neste evento.')))
                  else
                    SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: .78),
                          delegate:
                              SliverChildBuilderDelegate((context, index) {
                            final photo = shown[index];
                            final id = int.tryParse('${photo['id']}') ?? 0;
                            final selected = _inCart(id);
                            return Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => _preview(photo, shown),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                            child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                              CachedNetworkImage(
                                                  imageUrl:
                                                      '${photo['preview_url'] ?? ''}',
                                                  fit: BoxFit.cover,
                                                  placeholder: (_, __) =>
                                                      const Center(
                                                          child:
                                                              CupertinoActivityIndicator()),
                                                  errorWidget: (_, __, ___) =>
                                                      const Icon(Icons
                                                          .broken_image_outlined)),
                                              if (selected)
                                                Positioned(
                                                    right: 8,
                                                    top: 8,
                                                    child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(5),
                                                        decoration:
                                                            const BoxDecoration(
                                                                color: _rose,
                                                                shape: BoxShape
                                                                    .circle),
                                                        child: const Icon(
                                                            Icons.check,
                                                            color: Colors.white,
                                                            size: 17))),
                                            ])),
                                        Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Row(children: [
                                              Expanded(
                                                  child: Text(
                                                      '${photo['number'] ?? photo['filename'] ?? 'Fotografia'}',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight
                                                              .w600))),
                                              IconButton(
                                                  onPressed: selected
                                                      ? null
                                                      : () => _add(photo),
                                                  tooltip:
                                                      'Adicionar ao carrinho',
                                                  icon: Icon(
                                                      selected
                                                          ? Icons.check_circle
                                                          : Icons
                                                              .add_circle_outline,
                                                      color: _rose)),
                                            ])),
                                      ]),
                                ));
                          }, childCount: shown.length),
                        )),
                  SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverToBoxAdapter(
                          child: Column(children: [
                        if (_faceResults == null && _page < _lastPage)
                          OutlinedButton(
                              onPressed:
                                  _loadingMore ? null : () => _load(_page + 1),
                              child: Text(_loadingMore
                                  ? 'A carregar…'
                                  : 'Carregar mais fotografias')),
                      ]))),
                ]),
          )),
          // Barra fixa do carrinho: sempre visível, sem ser preciso descer até ao fim.
          Material(
              elevation: 8,
              color: Colors.white,
              child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                            onPressed: cartCount == 0
                                ? null
                                : () async {
                                    await context.pushNamed('GuestCartOnline');
                                    if (mounted) setState(() {});
                                  },
                            style: FilledButton.styleFrom(
                                backgroundColor: _rose,
                                padding: const EdgeInsets.all(18),
                                textStyle: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600)),
                            icon: const Icon(Icons.shopping_bag_outlined),
                            label: Text(cartCount == 0
                                ? 'Ver carrinho (vazio)'
                                : 'Ver carrinho ($cartCount)'))),
                  ))),
        ]));
  }
}

/// Visualizador em ecrã inteiro com zoom (dois dedos / duplo toque) e deslizar entre fotografias.
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer(
      {required this.photos,
      required this.initialIndex,
      required this.inCart,
      required this.onAdd});
  final List<Map<String, dynamic>> photos;
  final int initialIndex;
  final bool Function(int id) inCart;
  final void Function(Map<String, dynamic> photo) onAdd;
  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  static const _rose = Color(0xFFB77F84);
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  final Map<int, TransformationController> _zoom = {};
  bool _zoomed = false;

  TransformationController _controllerFor(int i) =>
      _zoom.putIfAbsent(i, () => TransformationController());

  @override
  void dispose() {
    _pages.dispose();
    for (final c in _zoom.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleZoom(int i, TapDownDetails? details) {
    final controller = _controllerFor(i);
    if (controller.value.getMaxScaleOnAxis() > 1.01) {
      controller.value = Matrix4.identity();
      setState(() => _zoomed = false);
    } else {
      final p = details?.localPosition ??
          Offset(MediaQuery.sizeOf(context).width / 2,
              MediaQuery.sizeOf(context).height / 2);
      controller.value = Matrix4.identity()
        ..translate(-p.dx * 1.5, -p.dy * 1.5)
        ..scale(2.5);
      setState(() => _zoomed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];
    final id = int.tryParse('${photo['id']}') ?? 0;
    final selected = widget.inCart(id);
    TapDownDetails? lastTap;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
          child: Stack(children: [
        PageView.builder(
          controller: _pages,
          physics: _zoomed
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() {
            _index = i;
            _zoomed = false;
            for (final c in _zoom.values) {
              c.value = Matrix4.identity();
            }
          }),
          itemBuilder: (context, i) => GestureDetector(
            onDoubleTapDown: (d) => lastTap = d,
            onDoubleTap: () => _toggleZoom(i, lastTap),
            child: InteractiveViewer(
              transformationController: _controllerFor(i),
              minScale: 1,
              maxScale: 6,
              onInteractionEnd: (_) => setState(() =>
                  _zoomed = _controllerFor(i).value.getMaxScaleOnAxis() > 1.01),
              child: Center(
                  child: CachedNetworkImage(
                      imageUrl: '${widget.photos[i]['preview_url'] ?? ''}',
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                          child:
                              CupertinoActivityIndicator(color: Colors.white)),
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white,
                          size: 56))),
            ),
          ),
        ),
        Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Row(children: [
              IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  iconSize: 32,
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Fechar'),
              Expanded(
                  child: Text(
                      '${photo['number'] ?? photo['filename'] ?? 'Fotografia'}  ·  ${_index + 1} de ${widget.photos.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600))),
              const SizedBox(width: 48),
            ])),
        if (!_zoomed)
          Positioned(
              left: 0,
              right: 0,
              bottom: 86,
              child: const Center(
                  child: Text(
                      'Afaste dois dedos para aproximar · deslize para o lado para a seguinte',
                      style: TextStyle(color: Colors.white70, fontSize: 14)))),
        Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(children: [
              if (_index > 0)
                IconButton.filledTonal(
                    onPressed: () => _pages.previousPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut),
                    iconSize: 30,
                    icon: const Icon(Icons.chevron_left)),
              const SizedBox(width: 10),
              Expanded(
                  child: FilledButton.icon(
                      onPressed: selected
                          ? null
                          : () {
                              widget.onAdd(photo);
                              setState(() {});
                            },
                      style: FilledButton.styleFrom(
                          backgroundColor: _rose,
                          disabledBackgroundColor: const Color(0xFF5E4A4C),
                          disabledForegroundColor: Colors.white,
                          padding: const EdgeInsets.all(18),
                          textStyle: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      icon: Icon(selected
                          ? Icons.check_circle
                          : Icons.add_circle_outline),
                      label: Text(selected
                          ? 'Já está no carrinho'
                          : 'Adicionar ao carrinho'))),
              const SizedBox(width: 10),
              if (_index < widget.photos.length - 1)
                IconButton.filledTonal(
                    onPressed: () => _pages.nextPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut),
                    iconSize: 30,
                    icon: const Icon(Icons.chevron_right)),
            ])),
      ])),
    );
  }
}
