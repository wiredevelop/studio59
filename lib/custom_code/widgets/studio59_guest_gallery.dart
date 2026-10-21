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

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  @override
  void dispose() {
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

  Future<void> _preview(Map<String, dynamic> photo) async {
    studio59Offline(
        'log',
        jsonEncode({
          'action': 'photo.open',
          'message':
              'Abriu a fotografia ${photo['number'] ?? photo['filename'] ?? photo['id']}'
        }));
    await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
              insetPadding: const EdgeInsets.all(24),
              backgroundColor: const Color(0xFF161412),
              child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 900, maxHeight: 760),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Expanded(
                          child: CachedNetworkImage(
                              imageUrl: '${photo['preview_url'] ?? ''}',
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_outlined,
                                      color: Colors.white, size: 48)))),
                      const SizedBox(height: 12),
                      Text(
                          '${photo['number'] ?? photo['filename'] ?? 'Fotografia'}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 17)),
                      const SizedBox(height: 12),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Fechar')),
                            const SizedBox(width: 12),
                            FilledButton(
                                onPressed: () {
                                  _add(photo);
                                  Navigator.pop(dialogContext);
                                },
                                style: FilledButton.styleFrom(
                                    backgroundColor: _rose),
                                child: Text(
                                    _inCart(int.tryParse('${photo['id']}') ?? 0)
                                        ? 'Já selecionada'
                                        : 'Adicionar ao carrinho')),
                          ]),
                    ]),
                  )),
            ));
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
    return SizedBox(
        width: widget.width,
        height: widget.height,
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
                                FilledButton.icon(
                                    onPressed:
                                        _faceSearching ? null : _faceSearch,
                                    style: FilledButton.styleFrom(
                                        backgroundColor: _rose,
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
                                        : const Icon(
                                            Icons.face_retouching_natural,
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
                              style: const TextStyle(color: Color(0xFF6D625F))),
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
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 10, 8, 10),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFF6ECEC),
                                      borderRadius: BorderRadius.circular(12)),
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
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: .78),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final photo = shown[index];
                          final id = int.tryParse('${photo['id']}') ?? 0;
                          final selected = _inCart(id);
                          return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _preview(photo),
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
                                                          const EdgeInsets.all(
                                                              5),
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
                                                        fontWeight:
                                                            FontWeight.w600))),
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
                      const SizedBox(height: 10),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                              onPressed: FFAppState().guestCart.isEmpty
                                  ? null
                                  : () => context.pushNamed('GuestCartOnline'),
                              style: FilledButton.styleFrom(
                                  backgroundColor: _rose,
                                  padding: const EdgeInsets.all(16)),
                              icon: const Icon(Icons.shopping_bag_outlined),
                              label: Text(
                                  'Ver carrinho (${FFAppState().guestCart.length})'))),
                    ]))),
              ]),
        ));
  }
}
