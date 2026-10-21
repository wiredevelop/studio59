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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

/// Dossier do evento para administradores: resumo (PIN, QR, PDF), fotografias
/// (ver, original, refazer preview, apagar, apagar em lote), upload de provas
/// por partes e exportações de pedidos (CSV, TXT, PDF, ZIP).
class Studio59EventDossier extends StatefulWidget {
  const Studio59EventDossier(
      {super.key, this.width, this.height, this.eventId});
  final double? width;
  final double? height;
  final int? eventId;

  @override
  State<Studio59EventDossier> createState() => _Studio59EventDossierState();
}

class _Studio59EventDossierState extends State<Studio59EventDossier> {
  static const _api = 'https://studio59.wiredevelop.pt/api';
  static const _rose = Color(0xFFB77F84);
  static const _ink = Color(0xFF292624);
  static const _muted = Color(0xFF6D625F);
  static const _chunkBytes = 4 * 1024 * 1024;

  String _token = '';
  String _tab = 'resumo';
  Map<String, dynamic>? _event;
  String? _error;
  bool _loading = true;

  // Fotografias
  final List<Map<String, dynamic>> _photos = [];
  final Set<int> _selected = {};
  final _search = TextEditingController();
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _photosLoading = false;
  String? _photosError;

  // Upload de provas
  final List<Map<String, dynamic>> _uploads = [];
  bool _uploading = false;

  // Exportações
  final _commission = TextEditingController(text: '15');
  String? _busyExport;

  int get _eventId => widget.eventId ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _commission.dispose();
    super.dispose();
  }

  Map<String, String> get _headers =>
      {'Accept': 'application/json', 'Authorization': 'Bearer $_token'};

  String _message(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) return '${body['message']}';
    } catch (_) {}
    if (response.statusCode == 401)
      return 'A sessão expirou. Inicie sessão novamente.';
    if (response.statusCode == 403) return 'Sem permissão para esta ação.';
    return '$fallback (${response.statusCode}).';
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _load() async {
    if (_eventId <= 0) {
      setState(() {
        _loading = false;
        _error = 'Serviço inválido.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _token = (await const FlutterSecureStorage()
                  .read(key: 'studio59_staff_token') ??
              '')
          .trim();
      if (_token.isEmpty)
        throw StateError('Inicie sessão para abrir o dossier.');
      final response = await http
          .get(Uri.parse('$_api/events/$_eventId'), headers: _headers)
          .timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(_message(response, 'Não foi possível abrir o evento'));
      }
      final body = jsonDecode(response.body);
      final data = body is Map && body['data'] is Map ? body['data'] : body;
      if (!mounted) return;
      setState(() {
        _event = Map<String, dynamic>.from(data as Map);
        _loading = false;
      });
      _loadPhotos(1);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error is StateError
              ? error.message.toString()
              : 'Não foi possível contactar o servidor.';
        });
      }
    }
  }

  // ---------------------------------------------------------------- Fotografias
  Future<void> _loadPhotos(int page) async {
    setState(() {
      _photosLoading = true;
      _photosError = null;
    });
    try {
      final query = {'page': '$page'};
      if (_search.text.trim().isNotEmpty) query['search'] = _search.text.trim();
      final response = await http
          .get(
              Uri.parse('$_api/events/$_eventId/photos')
                  .replace(queryParameters: query),
              headers: _headers)
          .timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
            _message(response, 'Não foi possível carregar as fotografias'));
      }
      final body = jsonDecode(response.body);
      final rows =
          body is Map && body['data'] is List ? body['data'] as List : const [];
      if (!mounted) return;
      setState(() {
        if (page == 1) {
          _photos.clear();
          _selected.clear();
        }
        _photos.addAll(
            rows.whereType<Map>().map((r) => Map<String, dynamic>.from(r)));
        _page = int.tryParse('${body['current_page'] ?? page}') ?? page;
        _lastPage = int.tryParse('${body['last_page'] ?? page}') ?? page;
        _total = int.tryParse('${body['total'] ?? _photos.length}') ??
            _photos.length;
        _photosLoading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _photosLoading = false;
          _photosError = error is StateError
              ? error.message.toString()
              : 'Não foi possível contactar o servidor.';
        });
      }
    }
  }

  int _id(Map<String, dynamic> photo) => int.tryParse('${photo['id']}') ?? 0;

  Future<bool> _confirm(String title, String text, String action) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              backgroundColor: Colors.white,
              title: Text(title),
              content: Text(text),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF9B3D3D)),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(action)),
              ],
            ));
    return ok == true;
  }

  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    if (!await _confirm(
        'Apagar fotografia?',
        'A fotografia ${photo['number'] ?? ''} é apagada do servidor (original e preview). Não pode ser desfeito.',
        'Apagar')) return;
    final response = await http.delete(
        Uri.parse('$_api/events/$_eventId/photos/${_id(photo)}'),
        headers: _headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      setState(() {
        _photos.removeWhere((p) => _id(p) == _id(photo));
        _selected.remove(_id(photo));
        _total = max(0, _total - 1);
      });
      _snack('Fotografia apagada.');
    } else {
      _snack(_message(response, 'Não foi possível apagar'));
    }
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final count = _selected.length;
    if (!await _confirm(
        'Apagar $count fotografias?',
        'As fotografias selecionadas são apagadas do servidor. Não pode ser desfeito.',
        'Apagar $count')) return;
    final response = await http.post(
        Uri.parse('$_api/events/$_eventId/photos/bulk-delete'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'photo_ids': _selected.toList()}));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      _snack('$count fotografias apagadas.');
      _loadPhotos(1);
    } else {
      _snack(_message(response, 'Não foi possível apagar'));
    }
  }

  Future<void> _retryPreview(Map<String, dynamic> photo) async {
    final response = await http.post(
        Uri.parse('$_api/events/$_eventId/photos/${_id(photo)}/retry-preview'),
        headers: _headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      setState(() => photo['preview_status'] = 'pending');
      _snack('Preview em preparação. Atualize daqui a pouco.');
    } else {
      _snack(_message(response, 'Não foi possível refazer a preview'));
    }
  }

  Future<void> _saveBytes(
      List<int> bytes, String fileName, String title) async {
    final data = Uint8List.fromList(bytes);
    final path = await FilePicker.platform
        .saveFile(dialogTitle: title, fileName: fileName, bytes: data);
    if (path == null) return;
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await File(path).writeAsBytes(data, flush: true);
    }
    _snack('Guardado: $fileName');
  }

  String _safeName(String value) {
    final clean = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), ' ')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return clean.isEmpty ? 'evento_$_eventId' : clean;
  }

  Future<void> _downloadOriginal(Map<String, dynamic> photo) async {
    _snack('A descarregar o original…');
    try {
      final response = await http.get(
          Uri.parse('$_api/events/$_eventId/photos/${_id(photo)}/original'),
          headers: {
            ..._headers,
            'Accept': '*/*'
          }).timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        _snack(response.statusCode == 404
            ? 'O original desta fotografia não existe no servidor.'
            : _message(response, 'Não foi possível descarregar'));
        return;
      }
      await _saveBytes(
          response.bodyBytes,
          'foto-${photo['number'] ?? _id(photo)}.jpg',
          'Guardar fotografia original');
    } catch (_) {
      _snack('Não foi possível descarregar o original.');
    }
  }

  Future<void> _openPhoto(Map<String, dynamic> photo) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
          backgroundColor: const Color(0xFF161412),
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Expanded(
                        child: photo['preview_url'] == null
                            ? const Center(
                                child: Text('Sem preview',
                                    style: TextStyle(color: Colors.white)))
                            : CachedNetworkImage(
                                imageUrl: '${photo['preview_url']}',
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image_outlined,
                                        color: Colors.white, size: 48)))),
                    const SizedBox(height: 12),
                    Text('Fotografia ${photo['number'] ?? ''}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 17)),
                    if (photo['preview_error'] != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('${photo['preview_error']}',
                              style:
                                  const TextStyle(color: Color(0xFFE7A1A1)))),
                    const SizedBox(height: 12),
                    Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white),
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _downloadOriginal(photo);
                              },
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Original')),
                          OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white),
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _retryPreview(photo);
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refazer preview')),
                          FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF9B3D3D)),
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _deletePhoto(photo);
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Apagar')),
                          TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Fechar',
                                  style: TextStyle(color: Colors.white70))),
                        ]),
                  ])))),
    );
  }

  // ----------------------------------------------------------- Upload de provas
  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
          allowMultiple: true, type: FileType.image, withData: false);
    } catch (_) {
      _snack('Não foi possível abrir a escolha de ficheiros.');
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final files = result.files.where((f) => f.path != null).toList();
    if (files.isEmpty) {
      _snack('Os ficheiros escolhidos não estão acessíveis neste dispositivo.');
      return;
    }
    setState(() {
      _uploading = true;
      _uploads
        ..clear()
        ..addAll(files.map((f) => {
              'name': f.name,
              'path': f.path,
              'size': f.size,
              'progress': 0.0,
              'state': 'à espera'
            }));
    });
    final client = http.Client();
    try {
      for (final item in _uploads) {
        if (!mounted) break;
        await _uploadOne(client, item);
      }
    } finally {
      client.close();
    }
    if (!mounted) return;
    final ok =
        _uploads.where((u) => !'${u['state']}'.startsWith('erro')).length;
    setState(() => _uploading = false);
    _snack(
        '$ok de ${_uploads.length} fotografias enviadas. As previews são geradas no servidor.');
    _loadPhotos(1);
  }

  Future<void> _uploadOne(http.Client client, Map<String, dynamic> item) async {
    final file = File('${item['path']}');
    RandomAccessFile? raf;
    try {
      final size = await file.length();
      final total = max(1, (size / _chunkBytes).ceil());
      final uploadId =
          'app-$_eventId-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';
      final name = '${item['name']}';
      raf = await file.open();
      setState(() => item['state'] = 'a enviar');
      for (var index = 0; index < total; index++) {
        final bytes =
            await raf.read(min(_chunkBytes, size - index * _chunkBytes));
        var sent = false;
        for (var attempt = 0; attempt < 3 && !sent; attempt++) {
          final request = http.MultipartRequest(
              'POST', Uri.parse('$_api/events/$_eventId/uploads/chunk'))
            ..headers.addAll(_headers)
            ..fields.addAll({
              'upload_id': uploadId,
              'chunk_index': '$index',
              'total_chunks': '$total',
              'file_name': name,
            })
            ..files.add(http.MultipartFile.fromBytes('chunk', bytes,
                filename: '$name.part$index'));
          try {
            final response = await http.Response.fromStream(
                await client.send(request).timeout(const Duration(minutes: 3)));
            if (response.statusCode >= 200 && response.statusCode < 300) {
              sent = true;
            } else if (response.statusCode == 401 ||
                response.statusCode == 403 ||
                response.statusCode == 422) {
              throw StateError(_message(response, 'Envio recusado'));
            }
          } on StateError {
            rethrow;
          } catch (_) {
            await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
          }
        }
        if (!sent)
          throw StateError('Falhou o envio da parte ${index + 1} de $total.');
        if (mounted) setState(() => item['progress'] = (index + 1) / total);
      }
      final status = await client
          .get(
              Uri.parse('$_api/events/$_eventId/uploads/status')
                  .replace(queryParameters: {'upload_id': uploadId}),
              headers: _headers)
          .timeout(const Duration(seconds: 30));
      final body = status.statusCode == 200 ? jsonDecode(status.body) : null;
      final done = body is Map && body['is_completed'] == true;
      if (mounted)
        setState(
            () => item['state'] = done ? 'concluído' : 'enviado (a processar)');
    } catch (error) {
      if (mounted) {
        setState(() => item['state'] =
            error is StateError ? 'erro: ${error.message}' : 'erro de ligação');
      }
    } finally {
      await raf?.close();
    }
  }

  // --------------------------------------------------------------- Exportações
  Future<void> _export(String key, String path, String fileName, String title,
      {Map<String, String>? query}) async {
    if (_busyExport != null) return;
    setState(() => _busyExport = key);
    try {
      final uri = Uri.parse('$_api$path').replace(queryParameters: query);
      final response = await http.get(uri, headers: {
        ..._headers,
        'Accept': '*/*'
      }).timeout(const Duration(minutes: 15));
      if (response.statusCode != 200) {
        _snack(_message(response, 'Não foi possível exportar'));
        return;
      }
      await _saveBytes(response.bodyBytes, fileName, title);
    } catch (_) {
      _snack('Não foi possível exportar (ligação interrompida).');
    } finally {
      if (mounted) setState(() => _busyExport = null);
    }
  }

  String get _baseName => _safeName('${_event?['name'] ?? 'evento_$_eventId'}');

  // ------------------------------------------------------------------- Layout
  Widget _card(
          {required String title,
          required List<Widget> children,
          Widget? trailing}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEDE6E3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700))),
            if (trailing != null) trailing,
          ]),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 130,
              child: Text(label, style: const TextStyle(color: _muted))),
          Expanded(
              child: SelectableText(value.isEmpty ? '—' : value,
                  style: const TextStyle(
                      color: _ink, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _summary() {
    final event = _event ?? {};
    final token = '${event['qr_token'] ?? ''}'.trim();
    final pin = '${event['access_pin'] ?? ''}'.trim();
    final qrUrl = token.isEmpty ? '' : '$_api/public/events/qr/$token';
    return ListView(padding: const EdgeInsets.all(16), children: [
      _card(title: 'Evento', children: [
        _info('Nome', '${event['name'] ?? ''}'),
        _info('Data', '${event['event_date'] ?? ''}'.split('T').first),
        _info('Tipo', '${event['event_type'] ?? ''}'),
        _info('Estado', '${event['status'] ?? ''}'),
        _info('Fotografias', '$_total'),
      ]),
      _card(title: 'Acesso dos convidados', children: [
        _info('PIN', pin),
        if (qrUrl.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(
              child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(
                      data: qrUrl, size: 200, backgroundColor: Colors.white))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: SelectableText(qrUrl,
                    style: const TextStyle(color: _muted, fontSize: 12))),
            IconButton(
                tooltip: 'Copiar link',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: qrUrl));
                  _snack('Link copiado.');
                },
                icon: const Icon(Icons.copy, color: _rose)),
          ]),
        ] else
          const Text(
              'Este evento ainda não tem QR (ou o seu perfil não o pode ver).',
              style: TextStyle(color: _muted)),
      ]),
      _card(title: 'Documentos', children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          _exportButton(
              'pdf',
              Icons.picture_as_pdf_outlined,
              'PDF da ficha',
              () => _export('pdf', '/events/$_eventId/pdf',
                  '${_baseName}_ficha.pdf', 'Guardar PDF da ficha')),
        ]),
      ]),
    ]);
  }

  Widget _exportButton(
          String key, IconData icon, String label, VoidCallback onPressed) =>
      OutlinedButton.icon(
        onPressed: _busyExport == null ? onPressed : null,
        style: OutlinedButton.styleFrom(
            foregroundColor: _rose,
            side: const BorderSide(color: _rose),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        icon: _busyExport == key
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _rose))
            : Icon(icon, size: 18),
        label: Text(label),
      );

  Widget _photosTab() {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100
        ? 6
        : width >= 760
            ? 5
            : width >= 520
                ? 4
                : 3;
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                    width: 220,
                    child: TextField(
                        controller: _search,
                        onSubmitted: (_) => _loadPhotos(1),
                        decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Número da fotografia',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12))))),
                Text('$_total fotografias',
                    style: const TextStyle(color: _muted)),
                if (_selected.isNotEmpty) ...[
                  FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF9B3D3D)),
                      onPressed: _deleteSelected,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text('Apagar ${_selected.length}')),
                  TextButton(
                      onPressed: () => setState(_selected.clear),
                      child: const Text('Limpar seleção')),
                ] else if (_photos.isNotEmpty)
                  TextButton(
                      onPressed: () =>
                          setState(() => _selected.addAll(_photos.map(_id))),
                      child: const Text('Selecionar visíveis',
                          style: TextStyle(color: _rose))),
                IconButton(
                    onPressed: () => _loadPhotos(1),
                    tooltip: 'Atualizar',
                    icon: const Icon(Icons.refresh, color: _ink)),
              ])),
      if (_photosError != null)
        Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_photosError!,
                style: const TextStyle(color: Color(0xFF9B3D3D)))),
      Expanded(
          child: _photosLoading && _photos.isEmpty
              ? const Center(child: CircularProgressIndicator(color: _rose))
              : _photos.isEmpty
                  ? const Center(
                      child: Text('Sem fotografias.',
                          style: TextStyle(color: _muted)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: .82),
                      itemCount: _photos.length + (_page < _lastPage ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _photos.length) {
                          return Center(
                              child: OutlinedButton(
                                  onPressed: _photosLoading
                                      ? null
                                      : () => _loadPhotos(_page + 1),
                                  child: Text(_photosLoading
                                      ? 'A carregar…'
                                      : 'Mais')));
                        }
                        final photo = _photos[index];
                        final id = _id(photo);
                        final selected = _selected.contains(id);
                        final failed = '${photo['preview_status']}' == 'failed';
                        final pending = photo['preview_url'] == null && !failed;
                        return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                                onTap: () => _selected.isNotEmpty
                                    ? setState(() => selected
                                        ? _selected.remove(id)
                                        : _selected.add(id))
                                    : _openPhoto(photo),
                                onLongPress: () => setState(() => selected
                                    ? _selected.remove(id)
                                    : _selected.add(id)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                          child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                            photo['preview_url'] == null
                                                ? Container(
                                                    color:
                                                        const Color(0xFFF3EEEC),
                                                    child: Icon(
                                                        failed
                                                            ? Icons
                                                                .error_outline
                                                            : Icons
                                                                .hourglass_empty,
                                                        color: failed
                                                            ? const Color(
                                                                0xFF9B3D3D)
                                                            : _muted))
                                                : CachedNetworkImage(
                                                    imageUrl:
                                                        '${photo['preview_url']}',
                                                    fit: BoxFit.cover,
                                                    errorWidget: (_, __, ___) =>
                                                        const Icon(Icons
                                                            .broken_image_outlined)),
                                            Positioned(
                                                left: 4,
                                                top: 4,
                                                child: Checkbox(
                                                    value: selected,
                                                    activeColor: _rose,
                                                    onChanged: (v) => setState(
                                                        () => v == true
                                                            ? _selected.add(id)
                                                            : _selected
                                                                .remove(id)))),
                                          ])),
                                      Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 6),
                                          child: Text(
                                              '${photo['number'] ?? id}${failed ? ' · erro' : pending ? ' · a preparar' : ''}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: failed
                                                      ? const Color(0xFF9B3D3D)
                                                      : _ink,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12))),
                                    ])));
                      })),
    ]);
  }

  Widget _uploadTab() => ListView(padding: const EdgeInsets.all(16), children: [
        _card(title: 'Upload de provas', children: [
          const Text(
              'Escolha as fotografias (JPEG) do evento. São enviadas por partes, como no painel web; se a ligação falhar, cada parte é repetida automaticamente. As previews ficam prontas no servidor alguns minutos depois.',
              style: TextStyle(color: _muted)),
          const SizedBox(height: 12),
          FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: _rose, padding: const EdgeInsets.all(16)),
              onPressed: _uploading ? null : _pickAndUpload,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(
                  _uploading ? 'A enviar…' : 'Escolher fotografias e enviar')),
        ]),
        if (_uploads.isNotEmpty)
          _card(
              title:
                  'Envio (${_uploads.where((u) => '${u['state']}' == 'concluído' || '${u['state']}'.startsWith('enviado')).length}/${_uploads.length})',
              children: _uploads
                  .map((u) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text('${u['name']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                              Text('${u['state']}',
                                  style: TextStyle(
                                      color: '${u['state']}'.startsWith('erro')
                                          ? const Color(0xFF9B3D3D)
                                          : _muted,
                                      fontSize: 12)),
                            ]),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                                value: (u['progress'] as num).toDouble(),
                                color: _rose,
                                backgroundColor: const Color(0xFFF3EEEC)),
                          ])))
                  .toList()),
      ]);

  Widget _exportsTab() =>
      ListView(padding: const EdgeInsets.all(16), children: [
        _card(title: 'Pedidos do evento', children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            _exportButton(
                'csv',
                Icons.table_chart_outlined,
                'Pedidos (CSV)',
                () => _export('csv', '/events/$_eventId/orders/export',
                    '${_baseName}_pedidos.csv', 'Guardar CSV')),
            _exportButton(
                'txt',
                Icons.description_outlined,
                'Lista para impressão (TXT)',
                () => _export('txt', '/events/$_eventId/orders/export-txt',
                    '${_baseName}_pedidos.txt', 'Guardar TXT')),
            _exportButton(
                'orders_pdf',
                Icons.picture_as_pdf_outlined,
                'Pedidos (PDF)',
                () => _export(
                    'orders_pdf',
                    '/events/$_eventId/orders/export-orders-pdf',
                    '${_baseName}_pedidos.pdf',
                    'Guardar PDF dos pedidos')),
          ]),
        ]),
        _card(title: 'Vendas e comissões', children: [
          Row(children: [
            SizedBox(
                width: 140,
                child: TextField(
                    controller: _commission,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Comissão %',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))))),
            const SizedBox(width: 12),
            _exportButton('sales_pdf', Icons.bar_chart_outlined, 'Vendas (PDF)',
                () {
              final rate = double.tryParse(
                      _commission.text.replaceAll(',', '.').trim()) ??
                  15;
              _export('sales_pdf', '/events/$_eventId/orders/export-sales-pdf',
                  '${_baseName}_vendas.pdf', 'Guardar PDF de vendas',
                  query: {'commission_rate': rate.clamp(0, 100).toString()});
            }),
          ]),
        ]),
        _card(title: 'Fotografias dos pedidos (ZIP)', children: [
          const Text(
              'Todas as fotografias pedidas, repetidas pela quantidade de cada pedido.',
              style: TextStyle(color: _muted)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _exportButton(
                'zip_all',
                Icons.folder_zip_outlined,
                'Todos (exceto cancelados)',
                () => _export(
                    'zip_all',
                    '/events/$_eventId/orders/download-zip',
                    '${_baseName}_pedidos.zip',
                    'Guardar ZIP',
                    query: {'layout': 'flat', 'scope': 'all'})),
            _exportButton(
                'zip_paid',
                Icons.folder_zip_outlined,
                'Só pagos a 100%',
                () => _export(
                    'zip_paid',
                    '/events/$_eventId/orders/download-zip',
                    '${_baseName}_pedidos_pagos.zip',
                    'Guardar ZIP',
                    query: {'layout': 'flat', 'scope': 'paid'})),
          ]),
        ]),
      ]);

  @override
  Widget build(BuildContext context) {
    final tabs = const {
      'resumo': ('Resumo', Icons.info_outline),
      'fotos': ('Fotografias', Icons.photo_library_outlined),
      'upload': ('Upload de provas', Icons.cloud_upload_outlined),
      'exportar': ('Pedidos e exportações', Icons.download_outlined),
    };
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator(color: _rose));
    } else if (_error != null) {
      body = Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, style: const TextStyle(color: Color(0xFF9B3D3D))),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _load, child: const Text('Tentar novamente')),
      ]));
    } else {
      body = switch (_tab) {
        'fotos' => _photosTab(),
        'upload' => _uploadTab(),
        'exportar' => _exportsTab(),
        _ => _summary(),
      };
    }
    return Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xFFFAF9F7),
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                if (Navigator.of(context).canPop())
                  IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, color: _ink)),
                Expanded(
                    child: Text('Dossier · ${_event?['name'] ?? 'Evento'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 21,
                            fontWeight: FontWeight.w700))),
                IconButton(
                    onPressed: _load,
                    tooltip: 'Atualizar',
                    icon: const Icon(Icons.refresh, color: _ink)),
              ])),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                  children: tabs.entries
                      .map((entry) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                              selected: _tab == entry.key,
                              selectedColor: const Color(0xFFF6ECEC),
                              avatar: Icon(entry.value.$2,
                                  size: 18,
                                  color: _tab == entry.key ? _rose : _muted),
                              label: Text(entry.value.$1),
                              onSelected: (_) =>
                                  setState(() => _tab = entry.key))))
                      .toList())),
          Expanded(child: body),
        ]));
  }
}
