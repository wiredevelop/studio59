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
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class Studio59StaffHub extends StatefulWidget {
  const Studio59StaffHub({super.key, this.width, this.height});
  final double? width;
  final double? height;

  @override
  State<Studio59StaffHub> createState() => _Studio59StaffHubState();
}

class _Studio59StaffHubState extends State<Studio59StaffHub> {
  static const _storage = FlutterSecureStorage();
  String get _base => (FFAppState().offlineApiBase.isNotEmpty
      ? FFAppState().offlineApiBase
      : 'https://studio59.wiredevelop.pt/api');
  bool get _offline => FFAppState().offlineApiBase.isNotEmpty;
  Timer? _offlineRefresh;
  static const _rose = Color(0xFFB77F84);
  static const _ink = Color(0xFF292624);
  static const _muted = Color(0xFF6D625F);
  static const _months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro'
  ];
  String _token = '';
  Map<String, dynamic> _user = {};
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _orders = [];
  bool _ordersComplete = true;
  Map<int, int> _photographersByEvent = {};
  Set<int> _ownAssignedEvents = {};
  bool _commissionComplete = false;
  int? _financeYear;
  int _ordersTotal = 0;
  int _pendingTotal = 0;
  int? _usersTotal;
  int? _clientsTotal;
  String _manageKind = 'Serviços';
  List<Map<String, dynamic>> _manageRows = [];
  bool _manageLoading = false;
  String? _manageError;
  int _managePage = 1;
  int _manageLastPage = 1;
  String _manageSearch = '';
  String _serviceSearch = '';
  String _serviceFilter = 'Próximos';
  Map<String, dynamic>? _contractTpl;
  bool _contractTplLoading = false;
  String? _contractTplError;
  final _contractName = TextEditingController();
  final _contractBody = TextEditingController();
  String? _error;
  bool _loading = true;
  bool _expired = false;
  String _tab = 'Início';
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();
  int? _orderYear;
  int? _orderMonth;
  int? _orderDay;
  int? _orderEventId;
  List<Map<String, dynamic>> _serviceOrders = [];
  bool _serviceOrdersLoading = false;
  String? _serviceOrdersError;
  String _orderSearch = '';

  @override
  void initState() {
    super.initState();
    _load();
    _offlineRefresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_offline &&
          mounted &&
          _tab == 'Pedidos' &&
          _orderEventId != null &&
          !_serviceOrdersLoading) {
        _loadServiceOrders(_orderEventId!, quiet: true);
      }
    });
  }

  @override
  void dispose() {
    _offlineRefresh?.cancel();
    _contractName.dispose();
    _contractBody.dispose();
    super.dispose();
  }

  void _selectOfflineEvent() {
    final event = _events.firstOrNull;
    final id = event == null ? null : int.tryParse('${event['id']}');
    final date = event == null ? null : _eventDate(event);
    if (id == null || date == null) return;
    _tab = 'Pedidos';
    _orderYear = date.year;
    _orderMonth = date.month;
    _orderDay = date.day;
    _orderEventId = id;
    _loadServiceOrders(id);
  }

  bool _can(String permission) {
    final role = (_user['role'] ?? '').toString().toLowerCase();
    if (role == 'admin' || role == 'administrator') return true;
    final explicit =
        (_user['permissions'] is List ? _user['permissions'] as List : const [])
            .map((value) => value.toString())
            .toSet();
    if (explicit.contains(permission)) return true;
    if (role == 'photographer') {
      return const {
        'dashboard.view',
        'events.list',
        'events.view',
        'events.pricing.view',
        'events.internal.view',
        'uploads.list',
        'uploads.create',
        'orders.list',
        'orders.view',
        'orders.update'
      }.contains(permission);
    }
    if (role == 'staff' && explicit.isEmpty) {
      return const {'dashboard.view', 'events.list', 'photos.list'}
          .contains(permission);
    }
    return false;
  }

  Map<String, dynamic> _object(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  List<Map<String, dynamic>> _rows(Map<String, dynamic> body) {
    final data = body['data'];
    final values = data is List ? data : (data is Map ? data['data'] : null);
    return values is List
        ? values
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
        : [];
  }

  int _lastPage(Map<String, dynamic> body) {
    final nested = body['data'] is Map ? body['data'] as Map : body;
    return int.tryParse('${nested['last_page'] ?? body['last_page'] ?? 1}') ??
        1;
  }

  int _total(Map<String, dynamic> body) {
    final nested = body['data'] is Map ? body['data'] as Map : body;
    return int.tryParse('${nested['total'] ?? body['total'] ?? 0}') ?? 0;
  }

  Future<Map<String, dynamic>> _get(http.Client client, String path,
      [Map<String, String>? query]) async {
    final response = await client.get(
      Uri.parse('$_base$path').replace(queryParameters: query),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token'
      },
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) {
      _expired = true;
      throw StateError('A sessão expirou. Inicie sessão novamente.');
    }
    if (response.statusCode == 403)
      throw StateError('Não tem permissão para consultar estes dados.');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'Não foi possível carregar os dados (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map)
      throw const FormatException('Resposta inválida do servidor.');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _expired = false;
      _rosters.clear();
      _rosterErrors.clear();
    });
    final client = http.Client();
    try {
      _token = (await _storage.read(key: 'studio59_staff_token') ?? '').trim();
      if (_token.isEmpty) {
        _expired = true;
        throw StateError('Inicie sessão para consultar o painel.');
      }
      final me = await _get(client, '/auth/me');
      final data = me['data'] is Map ? _object(me['data']) : me;
      _user = data['user'] is Map ? _object(data['user']) : data;
      if (!const {
        'admin',
        'staff',
        'photographer',
        'administrator',
        'backoffice',
        'receptionist',
        'rececionista'
      }.contains((_user['role'] ?? '').toString().toLowerCase())) {
        throw StateError('Perfil sem acesso à área da equipa.');
      }
      // Notificações push (Android/iOS): regista este telemóvel para os convites de serviços.
      if (!_offline) unawaited(studio59Push('register'));
      final events = <Map<String, dynamic>>[];
      var eventPage = 1;
      var eventLastPage = 0;
      if (_can('events.list') || _can('events.view')) {
        final body = await _get(client, '/events', {
          'page': '1',
          'per_page': '200',
          if (_assignedOnly) 'assigned_only': '1'
        });
        events.addAll(_rows(body));
        eventLastPage = _lastPage(body);
      }
      List<Map<String, dynamic>> orders = [];
      var ordersTotal = 0;
      var pendingTotal = 0;
      var orderPage = 1;
      var orderLastPage = 0;
      if (_can('orders.list')) {
        final body =
            await _get(client, '/orders', {'page': '1', 'per_page': '200'});
        orders = _rows(body);
        ordersTotal = _total(body);
        orderLastPage = _lastPage(body);
        _ordersComplete = orders.length >= ordersTotal;
        final pending =
            await _get(client, '/orders', {'page': '1', 'status': 'pending'});
        pendingTotal = _total(pending);
      }
      if (!mounted) return;
      setState(() {
        _events = List<Map<String, dynamic>>.from(events);
        _orders = List<Map<String, dynamic>>.from(orders);
        _ordersTotal = ordersTotal;
        _pendingTotal = pendingTotal;
        _loading = false;
      });
      while (++eventPage <= eventLastPage && eventPage <= 100) {
        events.addAll(_rows(await _get(client, '/events', {
          'page': '$eventPage',
          'per_page': '200',
          if (_assignedOnly) 'assigned_only': '1'
        })));
        if (!mounted) return;
        if (eventPage == eventLastPage || eventPage % 5 == 0) {
          setState(() => _events = List<Map<String, dynamic>>.from(events));
        }
      }
      while (++orderPage <= orderLastPage && orderPage <= 100) {
        orders.addAll(_rows(await _get(
            client, '/orders', {'page': '$orderPage', 'per_page': '200'})));
        if (!mounted) return;
        if (orderPage == orderLastPage || orderPage % 5 == 0) {
          setState(() => _orders = List<Map<String, dynamic>>.from(orders));
        }
      }
      _ordersComplete = orders.length >= ordersTotal;
      final photographerCounts = <int, int>{};
      final ownAssigned = <int>{};
      var commissionComplete = _ordersComplete;
      if ('${_user['role']}'.toLowerCase() == 'photographer' &&
          _can('events.view')) {
        final paid = orders
            .where((order) => '${order['status']}' != 'cancelled')
            .toList();
        final ids = paid
            .map((order) => int.tryParse(
                '${order['event_id'] ?? _object(order['event'])['id']}'))
            .whereType<int>()
            .toSet();
        if (paid.any((order) =>
            int.tryParse(
                '${order['event_id'] ?? _object(order['event'])['id']}') ==
            null)) commissionComplete = false;
        if (ids.length > 100) commissionComplete = false;
        final userId = int.tryParse('${_user['id']}');
        for (final eventId in ids.take(100)) {
          try {
            final roster = await _fetchRoster(client, eventId);
            final photographers = roster.where((member) {
              final person = _object(member['user']);
              final status = '${member['status'] ?? ''}'.toLowerCase();
              return '${person['role'] ?? member['role']}'.toLowerCase() ==
                      'photographer' &&
                  !const {
                    'declined',
                    'rejected',
                    'removed',
                    'cancelled',
                    'canceled',
                    'inactive'
                  }.contains(status);
            }).toList();
            if (photographers.isEmpty) {
              commissionComplete = false;
              continue;
            }
            photographerCounts[eventId] = photographers.length;
            if (userId != null &&
                photographers.any((member) =>
                    int.tryParse(
                        '${_object(member['user'])['id'] ?? member['user_id']}') ==
                    userId)) {
              ownAssigned.add(eventId);
            }
          } catch (_) {
            commissionComplete = false;
          }
        }
        if (paid.any((order) => _eurosToCents(order['total_amount']) == null))
          commissionComplete = false;
      }
      int? usersTotal;
      int? clientsTotal;
      if (_can('users.list'))
        usersTotal = _total(await _get(client, '/users', {'page': '1'}));
      if (_can('clients.list'))
        clientsTotal = _total(await _get(client, '/clients', {'page': '1'}));
      if (!mounted) return;
      final visibleOrders = _onlyAssignedOrders(orders, events);
      setState(() {
        _events = List<Map<String, dynamic>>.from(events);
        _orders = visibleOrders;
        if (_assignedOnly) {
          ordersTotal = visibleOrders.length;
          pendingTotal =
              visibleOrders.where((o) => '${o['status']}' == 'pending').length;
        }
        _photographersByEvent = photographerCounts;
        _ownAssignedEvents = ownAssigned;
        _commissionComplete = commissionComplete;
        _ordersTotal = ordersTotal;
        _pendingTotal = pendingTotal;
        _usersTotal = usersTotal;
        _clientsTotal = clientsTotal;
        _loading = false;
      });
      if (_offline && _orderEventId == null) setState(_selectOfflineEvent);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is StateError
            ? error.message.toString()
            : 'Não foi possível contactar o servidor. Verifique a ligação.';
        _loading = false;
      });
    } finally {
      client.close();
    }
  }

  Future<void> _logout() async {
    if (!_offline) {
      try {
        await studio59Push('unregister').timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
    final client = http.Client();
    try {
      await client.post(Uri.parse('$_base/auth/logout'), headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token'
      }).timeout(const Duration(seconds: 20));
    } catch (_) {
      // A sessão local termina mesmo se a rede estiver indisponível.
    } finally {
      client.close();
      await _storage.delete(key: 'studio59_staff_token');
      if (mounted) context.goNamed('WelcomeScreen');
    }
  }

  DateTime? _eventDate(Map<String, dynamic> event) {
    final cached = _dateCache[event];
    if (cached != null) return cached is DateTime ? cached : null;
    final parsed = DateTime.tryParse((event['event_date'] ?? '').toString());
    _dateCache[event] = parsed ?? false;
    return parsed;
  }

  List<Map<String, dynamic>> _eventsOn(DateTime date) {
    _ensureDayIndex();
    return List<Map<String, dynamic>>.from(
        _eventsByDay['${date.year}-${date.month}-${date.day}'] ?? const []);
  }

  void _openEvent(Map<String, dynamic> event) {
    final id = int.tryParse('${event['id']}');
    if (id == null || id <= 0 || !_can('events.view') || _offline) return;
    context.pushNamed('Studio59ServiceOnline',
        queryParameters: {'eventId': serializeParam(id, ParamType.int)});
  }

  Future<void> _loadServiceOrders(int eventId, {bool quiet = false}) async {
    setState(() {
      _serviceOrdersLoading = !quiet;
      _serviceOrdersError = null;
      if (!quiet) _serviceOrders = [];
    });
    final client = http.Client();
    try {
      final rows = <Map<String, dynamic>>[];
      var page = 1;
      var last = 1;
      do {
        final body =
            await _get(client, '/events/$eventId/orders', {'page': '$page'});
        rows.addAll(_rows(body));
        last = _lastPage(body);
        page++;
      } while (page <= last && page <= 100);
      if (!mounted || _orderEventId != eventId) return;
      setState(() {
        _serviceOrders = rows;
        _serviceOrdersLoading = false;
      });
    } catch (error) {
      if (!mounted || _orderEventId != eventId) return;
      setState(() {
        _serviceOrdersError = error is StateError
            ? error.message.toString()
            : 'Não foi possível contactar o servidor.';
        _serviceOrdersLoading = false;
      });
    } finally {
      client.close();
    }
  }

  int? _inputCents(String text) {
    final value = text
        .trim()
        .replaceAll('€', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    if (value.isEmpty) return null;
    return _eurosToCents(value);
  }

  String _apiAmount(int cents) =>
      '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

  String _statusLabel(dynamic status) =>
      const {
        'pending': 'Pendente',
        'paid': 'Pago',
        'delivered': 'Entregue',
        'cancelled': 'Cancelado',
      }['$status'] ??
      '${status ?? ''}';

  String _moneyField(dynamic amount) {
    final cents = _eurosToCents(amount);
    return cents == null ? '${amount ?? ''}' : _money(cents);
  }

  void _showOrderPhoto(BuildContext ctx, Map<String, dynamic> photo) {
    final url = '${photo['preview_url'] ?? ''}';
    if (url.isEmpty) return;
    showDialog<void>(
        context: ctx,
        builder: (dialogContext) => Dialog(
              backgroundColor: Colors.black,
              insetPadding: const EdgeInsets.all(12),
              child: Stack(children: [
                InteractiveViewer(
                    maxScale: 6,
                    child:
                        Center(child: Image.network(url, fit: BoxFit.contain))),
                Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        iconSize: 30,
                        icon: const Icon(Icons.close, color: Colors.white))),
                Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Text('Fotografia ${photo['number'] ?? photo['id']}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600))),
              ]),
            ));
  }

  Future<void> _openOrder(Map<String, dynamic> order) async {
    final id = int.tryParse('${order['id']}');
    if (id == null || id <= 0) return;
    var data = Map<String, dynamic>.from(order);
    String? notice;
    final client = http.Client();
    try {
      final detail = await _get(client, '/orders/$id');
      final full = detail['data'] is Map ? _object(detail['data']) : detail;
      data = {...data, ...full};
    } catch (error) {
      if (_expired) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('A sessão expirou. Inicie sessão novamente.')));
        client.close();
        return;
      }
      notice =
          'O servidor não devolveu o detalhe completo deste pedido. São mostrados os dados da lista.';
    } finally {
      client.close();
    }
    if (!mounted) return;
    final noticeText = notice;
    final received = TextEditingController();
    final notes = TextEditingController(text: '${data['notes'] ?? ''}');
    var changeGiven = true;
    var saving = false;
    var locked = false;
    String? formError;
    final paidNow = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF9F7),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) =>
          StatefulBuilder(builder: (sheetContext, update) {
        final pending = '${data['status']}' == 'pending';
        final totalCents = _eurosToCents(data['total_amount']);
        final previousCents =
            pending ? (_eurosToCents(data['cash_received_amount']) ?? 0) : 0;
        final inputCents = _inputCents(received.text);
        final receivedCents =
            inputCents == null ? null : previousCents + inputCents;
        final outstandingCents = totalCents == null
            ? null
            : (totalCents - previousCents > 0 ? totalCents - previousCents : 0);
        final changeCents = totalCents == null ||
                receivedCents == null ||
                receivedCents <= totalCents
            ? 0
            : receivedCents - totalCents;
        final dueCents = totalCents == null ||
                receivedCents == null ||
                totalCents <= receivedCents
            ? 0
            : totalCents - receivedCents;
        final fields = <String, dynamic>{
          'Cliente': data['customer_name'],
          'Mesa': data['table_label'],
          'Telefone': data['customer_phone'],
          'Email': data['customer_email'],
          'Formato': const {
                'paper': 'Papel',
                'digital': 'Digital',
                'both': 'Papel e digital'
              }['${data['product_type']}'] ??
              data['product_type'],
          'Entrega': const {
                'couple': 'Noivos entregam',
                'pickup': 'Levantamento',
                'store_pickup': 'Levantamento em loja',
                'shipping': 'Envio'
              }['${data['delivery_type']}'] ??
              data['delivery_type'],
          'Morada': data['delivery_address'],
          'Fotografias': data['items_total'] == null
              ? null
              : _moneyField(data['items_total']),
          'Extras': data['extras_total'] == null
              ? null
              : _moneyField(data['extras_total']),
          'Envio': data['shipping_fee'] == null
              ? null
              : _moneyField(data['shipping_fee']),
          if (!pending)
            'Recebido': data['cash_received_amount'] == null
                ? null
                : _moneyField(data['cash_received_amount']),
          if (!pending)
            'Troco': data['cash_change_amount'] == null
                ? null
                : _moneyField(data['cash_change_amount']),
          if (!pending)
            'Em dívida': data['cash_due_amount'] == null
                ? null
                : _moneyField(data['cash_due_amount']),
          if (!pending) 'Notas': data['notes'],
        };
        Future<void> pay() async {
          if (receivedCents == null) {
            update(() =>
                formError = 'Introduza o valor recebido (ex.: 20 ou 12,50).');
            return;
          }
          update(() {
            saving = true;
            formError = null;
          });
          final payClient = http.Client();
          try {
            final response = await payClient
                .post(Uri.parse('$_base/orders/$id/mark-paid'),
                    headers: {
                      'Accept': 'application/json',
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $_token'
                    },
                    body: jsonEncode({
                      'cash_received_amount': _apiAmount(receivedCents),
                      'cash_change_amount': _apiAmount(changeCents),
                      'cash_due_amount': _apiAmount(dueCents),
                      'cash_change_given':
                          changeCents > 0 ? changeGiven : false,
                      'notes': notes.text.trim(),
                    }))
                .timeout(const Duration(seconds: 25));
            if (response.statusCode >= 200 && response.statusCode < 300) {
              if (sheetContext.mounted) Navigator.pop(sheetContext, 'paid');
              return;
            }
            String message = '';
            try {
              final body = jsonDecode(response.body);
              if (body is Map) message = '${body['message'] ?? ''}';
            } catch (_) {}
            update(() {
              saving = false;
              formError = response.statusCode == 401
                  ? 'A sessão expirou. Inicie sessão novamente.'
                  : response.statusCode == 403
                      ? 'O servidor recusou o registo (403). Confirme que está atribuído a este serviço.'
                      : response.statusCode == 422
                          ? (message.isEmpty ? 'Valores inválidos.' : message)
                          : 'Não foi possível registar o pagamento (${response.statusCode}).';
            });
          } catch (_) {
            update(() {
              saving = false;
              locked = true;
              formError =
                  'A resposta é incerta. Atualize a lista e confirme o estado antes de tentar de novo.';
            });
          } finally {
            payClient.close();
          }
        }

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                            child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFDDD5D1),
                                    borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                              child: Text(
                                  '${data['order_code'] ?? 'Pedido $id'}',
                                  style: const TextStyle(
                                      color: _ink,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700))),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: pending
                                      ? const Color(0xFFFFF3E0)
                                      : const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(_statusLabel(data['status']),
                                  style: TextStyle(
                                      color: pending
                                          ? const Color(0xFFB26A00)
                                          : const Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w600))),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                            'Total: ${totalCents == null ? '—' : _money(totalCents)}',
                            style: const TextStyle(
                                color: _ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w600)),
                        if (noticeText != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(noticeText,
                                  style: const TextStyle(
                                      color: _muted, fontSize: 12))),
                        const SizedBox(height: 12),
                        _card(Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final e in fields.entries.where((e) =>
                                  e.value != null &&
                                  '${e.value}'.trim().isNotEmpty))
                                Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                              width: 100,
                                              child: Text(e.key,
                                                  style: const TextStyle(
                                                      color: _muted))),
                                          Expanded(
                                              child: Text('${e.value}',
                                                  style: const TextStyle(
                                                      color: _ink))),
                                        ])),
                            ])),
                        if (data['photos'] is List &&
                            (data['photos'] as List).isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                              'Fotografias escolhidas (${(data['photos'] as List).length})',
                              style: const TextStyle(
                                  color: _ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          const Text(
                              'Toque numa fotografia para a mostrar em grande ao cliente.',
                              style: TextStyle(color: _muted, fontSize: 12)),
                          const SizedBox(height: 8),
                          GridView.count(
                            crossAxisCount:
                                MediaQuery.sizeOf(sheetContext).width >= 700
                                    ? 5
                                    : 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: .8,
                            children: [
                              for (final photo
                                  in (data['photos'] as List).whereType<Map>())
                                InkWell(
                                  onTap: () => _showOrderPhoto(sheetContext,
                                      Map<String, dynamic>.from(photo)),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFFECE7E3))),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                              child: '${photo['preview_url'] ?? ''}'
                                                      .isEmpty
                                                  ? const Icon(
                                                      Icons.image_outlined,
                                                      color: _muted)
                                                  : Image.network(
                                                      '${photo['preview_url']}',
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __,
                                                              ___) =>
                                                          const Icon(
                                                              Icons
                                                                  .broken_image_outlined,
                                                              color: _muted))),
                                          Padding(
                                              padding: const EdgeInsets.all(6),
                                              child: Text(
                                                  '${photo['number'] ?? photo['id']}${(int.tryParse('${photo['quantity'] ?? 1}') ?? 1) > 1 ? ' × ${photo['quantity']}' : ''}',
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      color: _ink,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12))),
                                        ]),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (pending) ...[
                          const SizedBox(height: 16),
                          const Text('Registar pagamento',
                              style: TextStyle(
                                  color: _ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                          if (previousCents > 0)
                            Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                    'Já recebido: ${_money(previousCents)} · em falta: ${_money(outstandingCents ?? 0)}',
                                    style: const TextStyle(
                                        color: Color(0xFF9B3D3D),
                                        fontWeight: FontWeight.w600))),
                          const SizedBox(height: 10),
                          TextField(
                              controller: received,
                              enabled: !saving && !locked,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (_) => update(() => formError = null),
                              decoration: InputDecoration(
                                  labelText: previousCents > 0
                                      ? 'Valor recebido agora (€)'
                                      : 'Valor recebido (€)',
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon:
                                      const Icon(Icons.euro, color: _muted),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)))),
                          if (outstandingCents != null && outstandingCents > 0)
                            Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(spacing: 8, children: [
                                  ActionChip(
                                      label: Text(
                                          'Valor exato ${_money(outstandingCents)}'),
                                      onPressed: saving || locked
                                          ? null
                                          : () => update(() => received.text =
                                              _apiAmount(outstandingCents)
                                                  .replaceAll('.', ','))),
                                ])),
                          if (receivedCents != null && totalCents != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFF2E5E3),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Text(
                                        dueCents > 0
                                            ? 'Fica em dívida: ${_money(dueCents)}'
                                            : changeCents > 0
                                                ? 'Troco a entregar: ${_money(changeCents)}'
                                                : 'Valor exato, sem troco.',
                                        style: const TextStyle(
                                            color: _ink,
                                            fontWeight: FontWeight.w600)))),
                          if (changeCents > 0)
                            CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: changeGiven,
                                activeColor: _rose,
                                onChanged: saving || locked
                                    ? null
                                    : (v) =>
                                        update(() => changeGiven = v ?? false),
                                title: const Text('Troco entregue ao cliente')),
                          const SizedBox(height: 8),
                          TextField(
                              controller: notes,
                              enabled: !saving && !locked,
                              maxLines: 2,
                              decoration: InputDecoration(
                                  labelText: 'Notas (opcional)',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)))),
                          if (formError != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(formError!,
                                    style: const TextStyle(
                                        color: Color(0xFF9B3D3D)))),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: saving || locked ? null : pay,
                            style: FilledButton.styleFrom(
                                backgroundColor: _rose,
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))),
                            child: saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Confirmar pagamento'),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          if (_can('events.view') &&
                              !_offline &&
                              int.tryParse(
                                      '${data['event_id'] ?? _object(data['event'])['id']}') !=
                                  null)
                            OutlinedButton.icon(
                                onPressed: saving
                                    ? null
                                    : () =>
                                        Navigator.pop(sheetContext, 'event'),
                                icon: const Icon(Icons.description_outlined,
                                    size: 18),
                                label: const Text('Ficha do serviço')),
                          if (_canZip)
                            OutlinedButton.icon(
                                onPressed: saving
                                    ? null
                                    : () => Navigator.pop(sheetContext, 'zip'),
                                icon: const Icon(Icons.folder_zip_outlined,
                                    size: 18),
                                label: const Text('Descarregar ZIP')),
                          if (_canEditOrder)
                            OutlinedButton.icon(
                                onPressed: saving
                                    ? null
                                    : () => Navigator.pop(sheetContext, 'edit'),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Editar dados')),
                          if (_canAdjustCash && !pending ||
                              _canAdjustCash && previousCents > 0)
                            OutlinedButton.icon(
                                onPressed: saving
                                    ? null
                                    : () => Navigator.pop(sheetContext, 'cash'),
                                icon: const Icon(Icons.price_change_outlined,
                                    size: 18),
                                label: const Text('Ajustar trocos e dívidas')),
                          if (_canAdjustCash &&
                              _c(data['cash_change_amount']) > 0 &&
                              data['cash_change_given'] != true)
                            FilledButton.icon(
                                onPressed: saving
                                    ? null
                                    : () =>
                                        Navigator.pop(sheetContext, 'change'),
                                style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFB26A00)),
                                icon: const Icon(Icons.check, size: 18),
                                label: Text(
                                    'Troco de ${_money(_c(data['cash_change_amount']))} entregue')),
                        ]),
                        const SizedBox(height: 8),
                        TextButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(sheetContext),
                            child: const Text('Fechar',
                                style: TextStyle(color: _muted))),
                      ]))),
        );
      }),
    );
    received.dispose();
    notes.dispose();
    if (!mounted) return;
    if (paidNow == 'paid') {
      _afterOrderChange('Pagamento registado.');
    } else if (paidNow == 'event') {
      _openEvent(_eventOf(data));
    } else if (paidNow == 'zip') {
      await _downloadZip(id, data);
    } else if (paidNow == 'edit') {
      await _editOrder(id, data);
    } else if (paidNow == 'cash') {
      await _adjustCash(id, data);
    } else if (paidNow == 'change') {
      await _adjustCash(id, data, markChangeGiven: true);
    } else if (locked && _orderEventId != null) {
      _loadServiceOrders(_orderEventId!);
    }
  }

  Future<void> _loadManaged(String kind, [int page = 1]) async {
    if (kind == 'Serviços') {
      setState(() => _manageKind = kind);
      return;
    }
    setState(() {
      _manageKind = kind;
      _manageLoading = true;
      _manageError = null;
      _manageRows = [];
    });
    final client = http.Client();
    try {
      final path = kind == 'Clientes' ? '/clients' : '/users';
      final body = await _get(client, path, {'page': '$page'});
      if (!mounted || _manageKind != kind) return;
      setState(() {
        _manageRows = _rows(body);
        _managePage = page;
        _manageLastPage = _lastPage(body);
        _manageLoading = false;
      });
    } catch (error) {
      if (!mounted || _manageKind != kind) return;
      setState(() {
        _manageError = error is StateError
            ? error.message.toString()
            : 'Não foi possível contactar o servidor.';
        _manageLoading = false;
      });
    } finally {
      client.close();
    }
  }

  Future<void> _saveManaged(String kind, Map<String, dynamic>? existing) async {
    final isClient = kind == 'Clientes';
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final email = TextEditingController(text: '${existing?['email'] ?? ''}');
    final phone = TextEditingController(text: '${existing?['phone'] ?? ''}');
    final username =
        TextEditingController(text: '${existing?['username'] ?? ''}');
    final password = TextEditingController();
    final notes = TextEditingController(text: '${existing?['notes'] ?? ''}');
    var role = '${existing?['role'] ?? 'photographer'}';
    var active = existing?['is_active'] != false;
    var saving = false;
    String? formError;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, update) => AlertDialog(
                  title: Text(existing == null
                      ? 'Adicionar ${isClient ? 'cliente' : 'utilizador'}'
                      : 'Editar ${isClient ? 'cliente' : 'utilizador'}'),
                  content: SizedBox(
                      width: 500,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        TextField(
                            controller: name,
                            decoration:
                                const InputDecoration(labelText: 'Nome *')),
                        TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                                labelText: isClient ? 'Email' : 'Email *')),
                        if (isClient) ...[
                          TextField(
                              controller: phone,
                              decoration:
                                  const InputDecoration(labelText: 'Telefone')),
                          TextField(
                              controller: notes,
                              maxLines: 3,
                              decoration:
                                  const InputDecoration(labelText: 'Notas')),
                        ] else ...[
                          TextField(
                              controller: username,
                              decoration: const InputDecoration(
                                  labelText: 'Nome de utilizador')),
                          DropdownButtonFormField<String>(
                              value: role,
                              decoration:
                                  const InputDecoration(labelText: 'Perfil'),
                              items: _roleLabels.entries
                                  .map((e) => DropdownMenuItem(
                                      value: e.key, child: Text(e.value)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) update(() => role = v);
                              }),
                          TextField(
                              controller: password,
                              obscureText: true,
                              decoration: InputDecoration(
                                  labelText: existing == null
                                      ? 'Palavra-passe *'
                                      : 'Nova palavra-passe (opcional)')),
                          if (existing != null)
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: active,
                                activeColor: _rose,
                                title: const Text('Ativo'),
                                subtitle: const Text(
                                    'Inativo: não consegue entrar na app nem ser atribuído a serviços.'),
                                onChanged: (v) => update(() => active = v)),
                        ],
                        if (formError != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(formError!,
                                  style: const TextStyle(color: Colors.red))),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed:
                            saving ? null : () => Navigator.pop(dialogContext),
                        child: const Text('Cancelar')),
                    ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (name.text.trim().isEmpty ||
                                    (!isClient &&
                                        (email.text.trim().isEmpty ||
                                            (existing == null &&
                                                password.text.isEmpty)))) {
                                  update(() => formError =
                                      'Preencha os campos obrigatórios.');
                                  return;
                                }
                                update(() {
                                  saving = true;
                                  formError = null;
                                });
                                final client = http.Client();
                                try {
                                  final path = isClient ? '/clients' : '/users';
                                  final payload = isClient
                                      ? <String, dynamic>{
                                          'name': name.text.trim(),
                                          'email': email.text.trim(),
                                          'phone': phone.text.trim(),
                                          'notes': notes.text.trim(),
                                          'marketing_consent':
                                              existing?['marketing_consent'] ==
                                                  true
                                        }
                                      : <String, dynamic>{
                                          'name': name.text.trim(),
                                          'email': email.text.trim(),
                                          'username': username.text.trim(),
                                          'role': role,
                                          'permissions':
                                              existing?['permissions'] is List
                                                  ? existing!['permissions']
                                                  : <String>[],
                                          if (password.text.isNotEmpty)
                                            'password': password.text,
                                          if (existing != null)
                                            'is_active': active
                                        };
                                  final response = existing == null
                                      ? await client
                                          .post(Uri.parse('$_base$path'),
                                              headers: {
                                                'Accept': 'application/json',
                                                'Content-Type':
                                                    'application/json',
                                                'Authorization':
                                                    'Bearer $_token'
                                              },
                                              body: jsonEncode(payload))
                                          .timeout(const Duration(seconds: 20))
                                      : await client
                                          .put(
                                              Uri.parse(
                                                  '$_base$path/${existing['id']}'),
                                              headers: {
                                                'Accept': 'application/json',
                                                'Content-Type':
                                                    'application/json',
                                                'Authorization':
                                                    'Bearer $_token'
                                              },
                                              body: jsonEncode(payload))
                                          .timeout(const Duration(seconds: 20));
                                  if (response.statusCode < 200 ||
                                      response.statusCode >= 300) {
                                    final body =
                                        _object(jsonDecode(response.body));
                                    throw StateError(response.statusCode == 422
                                        ? '${body['message'] ?? 'Verifique os campos.'} ${body['errors'] ?? ''}'
                                        : response.statusCode == 403
                                            ? 'Sem permissão para guardar.'
                                            : 'Não foi possível guardar (${response.statusCode}).');
                                  }
                                  if (!dialogContext.mounted) return;
                                  Navigator.pop(dialogContext);
                                  _loadManaged(kind, _managePage);
                                } catch (error) {
                                  if (dialogContext.mounted)
                                    update(() {
                                      saving = false;
                                      formError = error is StateError
                                          ? error.message.toString()
                                          : 'Não foi possível contactar o servidor.';
                                    });
                                } finally {
                                  client.close();
                                }
                              },
                        child: Text(saving ? 'A guardar…' : 'Guardar'))
                  ],
                )));
    name.dispose();
    email.dispose();
    phone.dispose();
    username.dispose();
    password.dispose();
    notes.dispose();
  }

  static const _roleLabels = {
    'photographer': 'Fotógrafo',
    'staff': 'Staff',
    'backoffice': 'Backoffice',
    'receptionist': 'Receção',
    'admin': 'Administrador',
  };
  String _roleLabel(String role) => _roleLabels[role] ?? role;

  Future<void> _setUserActive(Map<String, dynamic> row, bool active) async {
    if (!active) {
      final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                  title: Text('Inativar ${row['name'] ?? ''}?'),
                  content: const Text(
                      'Deixa de conseguir entrar na app (as sessões abertas terminam) e de ser atribuído a serviços. Os dados e o histórico ficam guardados; pode voltar a ativar quando quiser.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: _rose),
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Inativar'))
                  ]));
      if (ok != true) return;
    }
    final client = http.Client();
    try {
      final payload = {
        'name': row['name'],
        'email': row['email'],
        'username': row['username'],
        'role': row['role'],
        'permissions':
            row['permissions'] is List ? row['permissions'] : <String>[],
        'is_active': active
      };
      final response = await client
          .put(Uri.parse('$_base/users/${row['id']}'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_token'
              },
              body: jsonEncode(payload))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Não foi possível alterar (${response.statusCode}).';
        try {
          final b = jsonDecode(response.body);
          if (b is Map && b['message'] != null) message = '${b['message']}';
        } catch (_) {}
        throw StateError(message);
      }
      setState(() => row['is_active'] = active);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(active
                ? '${row['name']} está ativo.'
                : '${row['name']} foi inativado.')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is StateError
                ? error.message.toString()
                : 'Não foi possível contactar o servidor.')));
    } finally {
      client.close();
    }
  }

  void _openDossier(Map<String, dynamic> event) {
    final id = int.tryParse('${event['id']}');
    if (id == null || id <= 0) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
            backgroundColor: const Color(0xFFFAF9F7),
            body: SafeArea(child: Studio59EventDossier(eventId: id)))));
  }

  Widget _servicesTab() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final query = _serviceSearch.trim().toLowerCase();
    final list = _events.where((e) {
      final date = _eventDate(e);
      if (_serviceFilter == 'Próximos' && date != null && date.isBefore(start))
        return false;
      if (_serviceFilter == 'Passados' &&
          (date == null || !date.isBefore(start))) return false;
      return query.isEmpty || jsonEncode(e).toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) {
        final da = _eventDate(a) ?? DateTime(2100),
            db = _eventDate(b) ?? DateTime(2100);
        return _serviceFilter == 'Passados'
            ? db.compareTo(da)
            : da.compareTo(db);
      });
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(
            child: Text('Serviços',
                style: TextStyle(
                    color: _ink, fontSize: 20, fontWeight: FontWeight.w600))),
        if (_can('events.create'))
          FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _rose),
              onPressed: () => context.pushNamed('Studio59ServiceOnline',
                      queryParameters: {
                        'eventId': serializeParam(0, ParamType.int)
                      }),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Novo serviço')),
      ]),
      const SizedBox(height: 4),
      Text(
          _isAdminRole
              ? 'Abra a ficha para ver ou editar os dados, ou o dossier para fotografias, upload de provas, contrato e exportações.'
              : 'Os serviços em que está atribuído.',
          style: const TextStyle(color: _muted)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final f in const ['Próximos', 'Passados', 'Todos'])
          ChoiceChip(
              label: Text(f),
              selected: _serviceFilter == f,
              selectedColor: const Color(0xFFF2E5E3),
              onSelected: (_) => setState(() => _serviceFilter = f)),
      ]),
      const SizedBox(height: 10),
      TextField(
          decoration: const InputDecoration(
              labelText: 'Pesquisar (nome, local, noivos, n.º)',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder()),
          onChanged: (v) => setState(() => _serviceSearch = v)),
      const SizedBox(height: 12),
      if (list.isEmpty)
        _card(const Text('Sem serviços neste filtro.',
            style: TextStyle(color: _muted))),
      for (final event in list.take(150))
        Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _card(Row(children: [
              Expanded(
                  child: InkWell(
                      onTap: () => _openEvent(event),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${event['name'] ?? 'Serviço'}',
                                style: const TextStyle(
                                    color: _ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Builder(builder: (_) {
                              final date = _eventDate(event);
                              return Text(
                                  [
                                    date == null
                                        ? 'Data por definir'
                                        : '${date.day} ${_months[date.month - 1]} ${date.year}',
                                    if ('${event['event_time'] ?? ''}'
                                        .isNotEmpty)
                                      '${event['event_time']}'.substring(
                                          0,
                                          '${event['event_time']}'.length >= 5
                                              ? 5
                                              : '${event['event_time']}'
                                                  .length),
                                    if ('${event['location'] ?? ''}'.isNotEmpty)
                                      '${event['location']}',
                                  ].join(' · '),
                                  style: const TextStyle(color: _muted));
                            }),
                          ]))),
              const SizedBox(width: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (_can('events.view'))
                  OutlinedButton.icon(
                      onPressed: () => _openEvent(event),
                      style: OutlinedButton.styleFrom(foregroundColor: _ink),
                      icon: const Icon(Icons.article_outlined, size: 18),
                      label: const Text('Ficha')),
                if (_isAdminRole)
                  FilledButton.icon(
                      onPressed: () => _openDossier(event),
                      style: FilledButton.styleFrom(backgroundColor: _rose),
                      icon: const Icon(Icons.folder_open_outlined, size: 18),
                      label: const Text('Dossier')),
              ]),
            ]))),
      if (list.length > 150)
        const Text(
            'Mostram-se os primeiros 150. Use a pesquisa para encontrar outro.',
            style: TextStyle(color: _muted)),
    ]);
  }

  // ---- Configurações › Modelo de contrato ----
  Future<void> _loadContractTpl() async {
    setState(() {
      _contractTplLoading = true;
      _contractTplError = null;
    });
    final client = http.Client();
    try {
      final body = await _get(client, '/contract-template');
      final data = body['data'] is Map ? _object(body['data']) : body;
      if (!mounted) return;
      setState(() {
        _contractTpl = data;
        _contractName.text = '${data['name'] ?? ''}';
        _contractBody.text = '${data['body'] ?? ''}';
        _contractTplLoading = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _contractTplLoading = false;
          _contractTplError = error is StateError
              ? error.message.toString()
              : 'Não foi possível contactar o servidor.';
        });
    } finally {
      client.close();
    }
  }

  Future<void> _saveContractTpl() async {
    if (_contractBody.text.trim().isEmpty) return;
    setState(() => _contractTplLoading = true);
    final client = http.Client();
    try {
      final response = await client
          .put(Uri.parse('$_base/contract-template'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_token'
              },
              body: jsonEncode({
                'name': _contractName.text.trim().isEmpty
                    ? 'Contrato'
                    : _contractName.text.trim(),
                'body': _contractBody.text
              }))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw StateError('Não foi possível guardar (${response.statusCode}).');
      if (mounted) {
        setState(() => _contractTplLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Modelo de contrato guardado. Os novos eventos usam este texto; nos existentes use «Atualizar com os dados atuais» no dossier.')));
      }
    } catch (error) {
      if (mounted)
        setState(() {
          _contractTplLoading = false;
          _contractTplError = error is StateError
              ? error.message.toString()
              : 'Não foi possível contactar o servidor.';
        });
    } finally {
      client.close();
    }
  }

  void _insertContractField(String key) {
    final text = _contractBody.text;
    final sel = _contractBody.selection;
    final at = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final tag = '{{$key}}';
    _contractBody.value = TextEditingValue(
        text: text.replaceRange(at, end, tag),
        selection: TextSelection.collapsed(offset: at + tag.length));
  }

  Widget _contractTemplateEditor() {
    if (_contractTpl == null &&
        !_contractTplLoading &&
        _contractTplError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _contractTpl == null && !_contractTplLoading)
          _loadContractTpl();
      });
    }
    final fields = (_contractTpl?['fields'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        IconButton(
            onPressed: () => setState(() => _settingsSection = ''),
            icon: const Icon(Icons.arrow_back, color: _ink)),
        const Expanded(
            child: Text('Modelo de contrato',
                style: TextStyle(
                    color: _ink, fontSize: 20, fontWeight: FontWeight.w600))),
        FilledButton.icon(
            onPressed: _contractTplLoading ? null : _saveContractTpl,
            style: FilledButton.styleFrom(backgroundColor: _rose),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Guardar')),
      ]),
      const Padding(
          padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Text(
              'Cada evento novo recebe um contrato com este texto, preenchido com os dados da ficha. Toque num campo para o inserir onde está o cursor.',
              style: TextStyle(color: _muted))),
      if (_contractTplError != null)
        _card(Text(_contractTplError!,
            style: const TextStyle(color: Color(0xFF9B3D3D)))),
      if (_contractTplLoading && _contractTpl == null)
        const Center(child: CircularProgressIndicator(color: _rose)),
      if (_contractTpl != null) ...[
        TextField(
            controller: _contractName,
            decoration: const InputDecoration(
                labelText: 'Nome do modelo', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final f in fields)
            ActionChip(
                label:
                    Text('${f['label']}', style: const TextStyle(fontSize: 12)),
                tooltip: '{{${f['key']}}}',
                onPressed: () => _insertContractField('${f['key']}')),
        ]),
        const SizedBox(height: 12),
        TextField(
            controller: _contractBody,
            minLines: 18,
            maxLines: 40,
            style: const TextStyle(fontSize: 14, height: 1.45),
            decoration: const InputDecoration(
                labelText: 'Texto do contrato',
                alignLabelWithHint: true,
                border: OutlineInputBorder())),
      ],
    ]);
  }

  Future<void> _deleteManaged(String kind, Map<String, dynamic> row) async {
    final id = int.tryParse('${row['id']}');
    if (id == null) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Eliminar registo?'),
                content: Text('${row['name'] ?? ''}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Eliminar'))
                ]));
    if (confirmed != true) return;
    final client = http.Client();
    try {
      final path = kind == 'Clientes' ? '/clients' : '/users';
      final response = await client.delete(Uri.parse('$_base$path/$id'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $_token'
          }).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw StateError('Não foi possível eliminar (${response.statusCode}).');
      if (mounted) _loadManaged(kind, _managePage);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is StateError
                ? error.message.toString()
                : 'Não foi possível contactar o servidor.')));
    } finally {
      client.close();
    }
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFECE7E3))),
        child: child,
      );

  Widget _eventRow(Map<String, dynamic> event) {
    final date = _eventDate(event);
    final dateLabel = date == null
        ? 'Data por definir'
        : '${date.day} ${_months[date.month - 1]} ${date.year}';
    final time = (event['event_time'] ?? '').toString();
    final location = (event['location'] ?? '').toString();
    return InkWell(
        onTap: () => _openEvent(event),
        borderRadius: BorderRadius.circular(16),
        child: _card(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((event['name'] ?? 'Serviço').toString(),
              style: const TextStyle(
                  color: _ink, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(
              [
                dateLabel,
                if (time.isNotEmpty) time,
                if (location.isNotEmpty) location
              ].join(' · '),
              style: const TextStyle(color: _muted)),
          if (_can('events.view'))
            const Padding(
                padding: EdgeInsets.only(top: 7),
                child: Text('Ver ficha do serviço',
                    style: TextStyle(color: _rose))),
        ])));
  }

  Widget _metricCard(
          String label, String value, IconData icon, VoidCallback onTap,
          {String? detail}) =>
      InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFECE7E3))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: _rose, size: 25),
                    const SizedBox(height: 14),
                    Text(value,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 25,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(label,
                        style: const TextStyle(color: _muted, fontSize: 13)),
                    if (detail != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(detail,
                              style: const TextStyle(
                                  color: _muted, fontSize: 11))),
                  ])));

  Widget _overview() {
    final role = '${_user['role']}'.toLowerCase();
    final admin = role == 'admin' || role == 'administrator';
    final photographer = role == 'photographer';
    final year = DateTime.now().year;
    final paid = _orders
        .where((order) =>
            const {'paid', 'delivered'}.contains('${order['status']}') &&
            (_eurosToCents(order['cash_due_amount']) ?? 0) == 0)
        .toList();
    final photoSalesComplete = _ordersComplete &&
        paid.every((order) => _eurosToCents(order['items_total']) != null);
    final annualServices = _events
        .where((event) =>
            _eventDate(event)?.year == year &&
            _eurosToCents(event['base_price']) != null)
        .toList();
    final annualPaid = paid
        .where((order) =>
            DateTime.tryParse('${order['created_at'] ?? ''}')?.year == year)
        .toList();
    final annualPhotoCents = annualPaid.fold<int>(
        0, (sum, order) => sum + (_eurosToCents(order['items_total']) ?? 0));
    final annualServiceCents = annualServices.fold<int>(
        0, (sum, event) => sum + (_eurosToCents(event['base_price']) ?? 0));
    final now = DateTime.now();
    final monthLabel = '${_months[now.month - 1]} ${now.year}';
    final ownSalesByEvent = <int, int>{};
    final ownEventNames = <int, String>{};
    for (final order
        in _orders.where((order) => '${order['status']}' != 'cancelled')) {
      final id =
          int.tryParse('${order['event_id'] ?? _object(order['event'])['id']}');
      final cents = _eurosToCents(order['total_amount']);
      if (id == null || cents == null || !_ownAssignedEvents.contains(id))
        continue;
      final event =
          _events.where((e) => int.tryParse('${e['id']}') == id).firstOrNull ??
              _object(order['event']);
      final date = _eventDate(event) ??
          DateTime.tryParse('${order['created_at'] ?? ''}');
      if (date == null || date.year != now.year || date.month != now.month)
        continue;
      ownSalesByEvent[id] = (ownSalesByEvent[id] ?? 0) + cents;
      ownEventNames[id] = '${event['name'] ?? 'Serviço $id'}';
    }
    final commissionByEvent = <int, int>{};
    for (final entry in ownSalesByEvent.entries) {
      final count = _photographersByEvent[entry.key];
      if (count == null || count < 1) continue;
      // 15% do total vendido do evento ÷ fotógrafos atribuídos, arredondado para baixo ao cêntimo.
      commissionByEvent[entry.key] = (entry.value * 15) ~/ (100 * count);
    }
    final commissionCents =
        commissionByEvent.values.fold<int>(0, (sum, value) => sum + value);
    final upcoming = _events.where((event) {
      final date = _eventDate(event);
      return date != null &&
          !date.isBefore(DateTime(
              DateTime.now().year, DateTime.now().month, DateTime.now().day));
    }).toList()
      ..sort((a, b) => (_eventDate(a) ?? DateTime(2100))
          .compareTo(_eventDate(b) ?? DateTime(2100)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
              color: const Color(0xFFF2E5E3),
              borderRadius: BorderRadius.circular(23)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                'Olá, ${(_user['name'] ?? _user['username'] ?? '').toString()}',
                style: const TextStyle(
                    color: _ink, fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
                admin
                    ? 'Visão do negócio · $year'
                    : photographer
                        ? 'A sua atividade e comissão'
                        : 'A sua atividade',
                style: const TextStyle(color: _muted, fontSize: 14)),
          ])),
      const SizedBox(height: 16),
      if (admin) ...[
        Row(children: [
          Expanded(
              child: _metricCard(
                  'Valor base dos serviços',
                  _money(annualServiceCents),
                  Icons.event_available_outlined,
                  () => setState(() => _tab = 'Financeiro'),
                  detail: '$year · ${annualServices.length} serviços')),
          const SizedBox(width: 10),
          Expanded(
              child: _metricCard(
                  'Vendas de fotografias',
                  photoSalesComplete ? _money(annualPhotoCents) : '—',
                  Icons.photo_library_outlined,
                  () => setState(() => _tab = 'Financeiro'),
                  detail: photoSalesComplete
                      ? '$year · pedidos pagos'
                      : 'Dados incompletos')),
        ]),
        const SizedBox(height: 10),
        _metricCard(
            'Pedidos pendentes',
            '$_pendingTotal',
            Icons.pending_actions_outlined,
            () => setState(() => _tab = 'Pedidos'),
            detail: 'Toque para consultar os pedidos'),
      ] else if (photographer) ...[
        _metricCard(
            'Comissão estimada · $monthLabel',
            _commissionComplete ? _money(commissionCents) : '—',
            Icons.payments_outlined,
            () => setState(() => _tab = 'Pedidos'),
            detail: !_commissionComplete
                ? 'Dados de vendas ou equipa incompletos'
                : commissionByEvent.isEmpty
                    ? 'Sem vendas pagas este mês nos serviços em que está atribuído'
                    : '15% do total vendido nos seus serviços deste mês, dividido pelos fotógrafos de cada serviço'),
        if (_commissionComplete && commissionByEvent.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _card(Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Serviços incluídos em $monthLabel',
                      style: const TextStyle(
                          color: _ink, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  for (final entry in commissionByEvent.entries)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Expanded(
                              child: Text(
                                  ownEventNames[entry.key] ??
                                      'Serviço ${entry.key}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: _muted))),
                          Text(_money(entry.value),
                              style: const TextStyle(
                                  color: _ink, fontWeight: FontWeight.w600)),
                        ])),
                ],
              ))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _metricCard(
                  'Serviços atribuídos',
                  '${_events.length}',
                  Icons.calendar_month_outlined,
                  () => setState(() => _tab = 'Agenda'))),
          const SizedBox(width: 10),
          Expanded(
              child: _metricCard(
                  'Pedidos pendentes',
                  '$_pendingTotal',
                  Icons.receipt_long_outlined,
                  () => setState(() => _tab = 'Pedidos'))),
        ]),
      ],
      const SizedBox(height: 24),
      const Text('Próximos serviços',
          style: TextStyle(
              color: _ink, fontSize: 19, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      if (upcoming.isEmpty)
        _card(const Text('Não existem serviços futuros acessíveis.',
            style: TextStyle(color: _muted))),
      for (final event in upcoming.take(5)) ...[
        _eventRow(event),
        const SizedBox(height: 9)
      ],
    ]);
  }

  String get _roleName => '${_user['role'] ?? ''}'.toLowerCase();
  bool get _canSchedule =>
      !_offline &&
      (const {
            'admin',
            'administrator',
            'backoffice',
            'receptionist',
            'rececionista'
          }.contains(_roleName) ||
          _can('events.create'));

  int? _minutes(dynamic value) {
    final match =
        RegExp(r'^(\d{1,2}):(\d{2})').firstMatch('${value ?? ''}'.trim());
    if (match == null) return null;
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  String _hhmm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  /// Intervalo ocupado por um evento; sem hora de fim assume 4 horas.
  (int, int)? _busyRange(Map<String, dynamic> event) {
    final start = _minutes(event['event_time']);
    if (start == null) return null;
    final end = _minutes(event['event_end_time'] ?? event['end_time']);
    return (start, end != null && end > start ? end : start + 240);
  }

  Future<void> _schedule(DateTime initialDate) async {
    final client = http.Client();
    List<Map<String, dynamic>> templates = [];
    List<Map<String, dynamic>> people = [];
    String? loadIssue;
    try {
      templates = _rows(await _get(client, '/events/service-templates'));
    } catch (_) {
      // Sem tipos de serviço: usa 'outros'.
    }
    try {
      final body = await _get(client, '/staff/users');
      people = _rows(body)
          .where((u) => !const {'admin', 'administrator'}
              .contains('${u['role']}'.toLowerCase()))
          .toList()
        ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
    } catch (_) {
      loadIssue = 'Não foi possível carregar a lista da equipa.';
    } finally {
      client.close();
    }
    if (!mounted) return;
    var date = initialDate;
    int? start;
    int? end;
    final otherType = templates
        .where(
            (t) => '${t['slug']} ${t['name']}'.toLowerCase().contains('outro'))
        .firstOrNull;
    final type = '${(otherType ?? templates.firstOrNull)?['slug'] ?? 'outros'}';
    final name = TextEditingController();
    final location = TextEditingController();
    final notes = TextEditingController();
    final team = <int>{};
    var foreign = false;
    var saving = false;
    var acceptConflict = false;
    String? formError;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF9F7),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) =>
          StatefulBuilder(builder: (sheetContext, update) {
        final sameDay = _eventsOn(date)
          ..sort((a, b) => (_minutes(a['event_time']) ?? 9999)
              .compareTo(_minutes(b['event_time']) ?? 9999));
        final newRange = start == null
            ? null
            : (start!, end != null && end! > start! ? end! : start! + 240);
        final conflicts = newRange == null
            ? <Map<String, dynamic>>[]
            : sameDay.where((e) {
                final r = _busyRange(e);
                return r != null && r.$1 < newRange.$2 && newRange.$1 < r.$2;
              }).toList();
        InputDecoration deco(String label, {IconData? icon}) => InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.white,
            prefixIcon:
                icon == null ? null : Icon(icon, color: _muted, size: 20),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)));
        Future<void> pickTime(bool isStart) async {
          final current = isStart ? start : end;
          final picked = await showTimePicker(
              context: sheetContext,
              initialTime: TimeOfDay(
                  hour: (current ?? (isStart ? 600 : (start ?? 600) + 240)) ~/
                      60 %
                      24,
                  minute: (current ?? 0) % 60),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(alwaysUse24HourFormat: true),
                  child: child!));
          if (picked != null)
            update(() {
              if (isStart) {
                start = picked.hour * 60 + picked.minute;
              } else {
                end = picked.hour * 60 + picked.minute;
              }
              acceptConflict = false;
            });
        }

        Future<void> save() async {
          if (name.text.trim().isEmpty) {
            update(() => formError = 'Indique o nome.');
            return;
          }
          if (start == null) {
            update(() => formError = 'Indique a hora de início.');
            return;
          }
          if (end != null && end! <= start!) {
            update(() => formError =
                'A hora de fim tem de ser depois da hora de início.');
            return;
          }
          if (conflicts.isNotEmpty && !acceptConflict) {
            update(() {
              acceptConflict = true;
              formError =
                  'Este horário coincide com outro serviço. Toque novamente em Agendar para confirmar mesmo assim.';
            });
            return;
          }
          final payload = <String, dynamic>{
            'event_type': type,
            'event_date':
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            'event_time': _hhmm(start!),
            if (end != null) 'event_end_time': _hhmm(end!),
            'name': name.text.trim(),
            'location': location.text.trim(),
            'notes': notes.text.trim(),
            'staff_ids': team.toList(),
            // Campos ainda exigidos pelo servidor; editáveis depois na ficha do serviço.
            'base_price': 0,
            'price_per_photo': 5,
            'event_meta': <String, dynamic>{
              'agendamento_rapido': true,
              'estrangeiro': foreign
            },
          };
          update(() {
            saving = true;
            formError = null;
          });
          final saveClient = http.Client();
          try {
            final response = await saveClient
                .post(Uri.parse('$_base/events'),
                    headers: {
                      'Accept': 'application/json',
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $_token'
                    },
                    body: jsonEncode(payload))
                .timeout(const Duration(seconds: 25));
            if (response.statusCode < 200 || response.statusCode >= 300) {
              String message = '';
              try {
                final body = jsonDecode(response.body);
                if (body is Map)
                  message =
                      '${body['message'] ?? ''} ${body['errors'] ?? ''}'.trim();
              } catch (_) {}
              throw StateError(response.statusCode == 403
                  ? 'O seu perfil não tem permissão para agendar (403).'
                  : response.statusCode == 422
                      ? (message.isEmpty ? 'Verifique os campos.' : message)
                      : 'Não foi possível agendar (${response.statusCode}).');
            }
            if (sheetContext.mounted) Navigator.pop(sheetContext, true);
          } catch (error) {
            update(() {
              saving = false;
              formError = error is StateError
                  ? error.message.toString()
                  : 'Não foi possível contactar o servidor.';
            });
          } finally {
            saveClient.close();
          }
        }

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SafeArea(
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                  child: Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFDDD5D1),
                                          borderRadius:
                                              BorderRadius.circular(2)))),
                              const SizedBox(height: 14),
                              const Text('Agendar serviço',
                                  style: TextStyle(
                                      color: _ink,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700)),
                              if (loadIssue != null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(loadIssue!,
                                        style: const TextStyle(
                                            color: Color(0xFFB3261E)))),
                              const SizedBox(height: 14),
                              Row(children: [
                                Expanded(
                                    child: InkWell(
                                        onTap: saving
                                            ? null
                                            : () async {
                                                final picked =
                                                    await showDatePicker(
                                                        context: sheetContext,
                                                        initialDate: date,
                                                        firstDate:
                                                            DateTime(2020),
                                                        lastDate:
                                                            DateTime(2100));
                                                if (picked != null)
                                                  update(() {
                                                    date = picked;
                                                    acceptConflict = false;
                                                  });
                                              },
                                        child: InputDecorator(
                                            decoration: deco('Data',
                                                icon: Icons
                                                    .calendar_today_outlined),
                                            child: Text(
                                                '${date.day} ${_months[date.month - 1]} ${date.year}')))),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: InkWell(
                                        onTap: saving
                                            ? null
                                            : () => pickTime(true),
                                        child: InputDecorator(
                                            decoration: deco('Início',
                                                icon: Icons.schedule),
                                            child: Text(start == null
                                                ? '—'
                                                : _hhmm(start!))))),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: InkWell(
                                        onTap: saving
                                            ? null
                                            : () => pickTime(false),
                                        child: InputDecorator(
                                            decoration: deco('Fim',
                                                icon: Icons.schedule_outlined),
                                            child: Text(end == null
                                                ? '—'
                                                : _hhmm(end!))))),
                              ]),
                              const SizedBox(height: 12),
                              _card(Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                        'Já marcado a ${date.day} ${_months[date.month - 1]}',
                                        style: const TextStyle(
                                            color: _ink,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    if (sameDay.isEmpty)
                                      const Text('Dia livre.',
                                          style: TextStyle(
                                              color: Color(0xFF2E7D32))),
                                    for (final e in sameDay)
                                      Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 3),
                                          child: Row(children: [
                                            Icon(
                                                conflicts.contains(e)
                                                    ? Icons
                                                        .warning_amber_rounded
                                                    : Icons.event_busy,
                                                size: 18,
                                                color: conflicts.contains(e)
                                                    ? const Color(0xFFB3261E)
                                                    : _muted),
                                            const SizedBox(width: 6),
                                            Text(
                                                _busyRange(e) == null
                                                    ? 'sem hora'
                                                    : '${_hhmm(_busyRange(e)!.$1)}–${_hhmm(_busyRange(e)!.$2)}',
                                                style: TextStyle(
                                                    color: conflicts.contains(e)
                                                        ? const Color(
                                                            0xFFB3261E)
                                                        : _ink,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                                child: Text(
                                                    '${e['name'] ?? 'Serviço'}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        color: _muted))),
                                          ])),
                                    if (sameDay.any((e) =>
                                        e['event_end_time'] == null &&
                                        e['end_time'] == null))
                                      const Padding(
                                          padding: EdgeInsets.only(top: 4),
                                          child: Text(
                                              'Serviços sem hora de fim contam como 4 horas.',
                                              style: TextStyle(
                                                  color: _muted,
                                                  fontSize: 11))),
                                  ])),
                              const SizedBox(height: 12),
                              TextField(
                                  controller: name,
                                  decoration: deco('Nome *',
                                      icon: Icons.event_outlined)),
                              const SizedBox(height: 10),
                              TextField(
                                  controller: location,
                                  decoration: deco('Local de encontro',
                                      icon: Icons.place_outlined)),
                              const SizedBox(height: 10),
                              TextField(
                                  controller: notes,
                                  maxLines: 3,
                                  decoration: deco('Notas', icon: Icons.notes)),
                              SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  activeColor: _rose,
                                  value: foreign,
                                  onChanged: (v) => update(() => foreign = v),
                                  title: const Text('Estrangeiro'),
                                  subtitle: const Text(
                                      'Marca no calendário o dia anterior, o próprio dia e o dia seguinte.')),
                              const SizedBox(height: 6),
                              const Text('Equipa',
                                  style: TextStyle(
                                      color: _ink,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              const Text(
                                  'Os administradores ficam associados automaticamente.',
                                  style:
                                      TextStyle(color: _muted, fontSize: 12)),
                              const SizedBox(height: 8),
                              if (people.isEmpty)
                                const Text('Sem utilizadores disponíveis.',
                                    style: TextStyle(color: _muted))
                              else
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  for (final person in people)
                                    FilterChip(
                                      label: Text(
                                          '${person['name'] ?? person['username']} · ${const {
                                                'photographer': 'fotógrafo',
                                                'staff': 'staff',
                                                'backoffice': 'backoffice',
                                                'receptionist': 'receção',
                                                'rececionista': 'receção'
                                              }['${person['role']}'.toLowerCase()] ?? person['role']}'),
                                      selected: team.contains(
                                          int.tryParse('${person['id']}')),
                                      selectedColor: const Color(0xFFF2E5E3),
                                      checkmarkColor: _rose,
                                      onSelected: saving
                                          ? null
                                          : (on) => update(() {
                                                final id = int.tryParse(
                                                    '${person['id']}');
                                                if (id != null) {
                                                  if (on) {
                                                    team.add(id);
                                                  } else {
                                                    team.remove(id);
                                                  }
                                                }
                                              }),
                                    ),
                                ]),
                              if (formError != null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(formError!,
                                        style: const TextStyle(
                                            color: Color(0xFFB3261E)))),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                  onPressed: saving ? null : save,
                                  style: FilledButton.styleFrom(
                                      backgroundColor: conflicts.isNotEmpty
                                          ? const Color(0xFFB3261E)
                                          : _rose,
                                      padding: const EdgeInsets.all(16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14))),
                                  icon: saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Icon(Icons.event_available),
                                  label: Text(conflicts.isNotEmpty
                                      ? 'Agendar (horário ocupado)'
                                      : 'Agendar')),
                              TextButton(
                                  onPressed: saving
                                      ? null
                                      : () =>
                                          Navigator.pop(sheetContext, false),
                                  child: const Text('Cancelar',
                                      style: TextStyle(color: _muted))),
                            ]),
                      )))),
        );
      }),
    );
    for (final c in [name, location, notes]) {
      c.dispose();
    }
    if (created == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Serviço agendado.')));
      _selected = date;
      _month = DateTime(date.year, date.month);
      _tab = 'Agenda';
      _load();
    }
  }

  bool _isForeign(Map<String, dynamic> e) {
    final meta = e['event_meta'];
    return meta is Map &&
        (meta['estrangeiro'] == true ||
            '${meta['estrangeiro']}' == 'true' ||
            '${meta['estrangeiro']}' == '1');
  }

  /// Dias marcados por serviços no estrangeiro: o próprio dia, o anterior e o seguinte.
  bool _foreignNear(DateTime date) {
    for (final offset in const [-1, 0, 1]) {
      final d = date.add(Duration(days: offset));
      if (_eventsOn(d).any(_isForeign)) return true;
    }
    return false;
  }

  Widget _agenda() {
    final firstOffset = DateTime(_month.year, _month.month, 1).weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final cellCount = ((firstOffset + days + 6) ~/ 7) * 7;
    final selectedEvents = _eventsOn(_selected);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card(Column(children: [
        Row(children: [
          IconButton(
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1)),
              icon: const Icon(Icons.chevron_left)),
          Expanded(
              child: Text('${_months[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _ink, fontSize: 18, fontWeight: FontWeight.w600))),
          IconButton(
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1)),
              icon: const Icon(Icons.chevron_right)),
        ]),
        Row(
            children: const ['S', 'T', 'Q', 'Q', 'S', 'S', 'D']
                .map((day) => Expanded(
                    child: Center(
                        child: Text(day, style: TextStyle(color: _muted)))))
                .toList()),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cellCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.15),
          itemBuilder: (context, index) {
            final day = index - firstOffset + 1;
            if (day < 1 || day > days) return const SizedBox.shrink();
            final date = DateTime(_month.year, _month.month, day);
            final selected = date.year == _selected.year &&
                date.month == _selected.month &&
                date.day == _selected.day;
            return InkWell(
                onTap: () => setState(() => _selected = date),
                child: Container(
                  decoration: BoxDecoration(
                      color: selected ? _rose : Colors.transparent,
                      borderRadius: BorderRadius.circular(10)),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$day',
                            style: TextStyle(
                                color: selected ? Colors.white : _ink,
                                fontWeight: FontWeight.w600)),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_eventsOn(date).isNotEmpty)
                                Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                        color: selected ? Colors.white : _rose,
                                        shape: BoxShape.circle)),
                              if (_eventsOn(date).isNotEmpty &&
                                  _foreignNear(date))
                                const SizedBox(width: 3),
                              if (_foreignNear(date))
                                Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFD32F2F),
                                        shape: BoxShape.circle,
                                        border: selected
                                            ? Border.all(
                                                color: Colors.white, width: 1)
                                            : null)),
                            ]),
                      ]),
                ));
          },
        ),
      ])),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
            child: Text('${_selected.day} ${_months[_selected.month - 1]}',
                style: const TextStyle(
                    color: _ink, fontSize: 18, fontWeight: FontWeight.w600))),
        if (_canSchedule)
          FilledButton.icon(
              onPressed: () => _schedule(_selected),
              style: FilledButton.styleFrom(backgroundColor: _rose),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agendar neste dia')),
      ]),
      const SizedBox(height: 10),
      if (selectedEvents.isEmpty)
        _card(const Text('Sem serviços nesta data.',
            style: TextStyle(color: _muted))),
      for (final event in selectedEvents) ...[
        _eventRow(event),
        const SizedBox(height: 9)
      ],
    ]);
  }

  /// Fotógrafos e staff só veem os serviços em cuja equipa estão (o servidor dá-lhes events.view.all implícito).
  bool get _assignedOnly => const {'photographer', 'staff'}
      .contains('${_user['role'] ?? ''}'.toLowerCase());

  List<Map<String, dynamic>> _onlyAssignedOrders(
      List<Map<String, dynamic>> orders, List<Map<String, dynamic>> events) {
    if (!_assignedOnly) return List<Map<String, dynamic>>.from(orders);
    final ids =
        events.map((e) => int.tryParse('${e['id']}')).whereType<int>().toSet();
    return orders
        .where((o) => ids.contains(
            int.tryParse('${o['event_id'] ?? _object(o['event'])['id']}')))
        .toList();
  }

  bool get _isAdminRole => const {'admin', 'administrator'}.contains(_roleName);
  bool get _canZip => !_offline && (_isAdminRole || _can('orders.download'));
  bool get _canEditOrder =>
      _roleName != 'photographer' && (_isAdminRole || _can('orders.update'));
  bool get _canAdjustCash =>
      _isAdminRole ||
      _can('orders.cash.adjust') ||
      (_offline && _can('orders.update'));

  // Datas lidas uma só vez por evento e índice de eventos por dia.
  final Expando<Object> _dateCache = Expando<Object>('eventDate');
  Object? _dayIndexKey;
  Map<String, List<Map<String, dynamic>>> _eventsByDay = {};

  void _ensureDayIndex() {
    final key = (identityHashCode(_events), _events.length);
    if (_dayIndexKey == key) return;
    _dayIndexKey = key;
    final index = <String, List<Map<String, dynamic>>>{};
    for (final event in _events) {
      final d = _eventDate(event);
      if (d != null)
        index.putIfAbsent('${d.year}-${d.month}-${d.day}', () => []).add(event);
    }
    _eventsByDay = index;
  }

  /// Atualiza a lista global de pedidos sem mostrar o ecrã de carregamento.
  Future<void> _refreshOrders() async {
    if (!_can('orders.list')) return;
    final client = http.Client();
    try {
      final rows = <Map<String, dynamic>>[];
      var page = 1;
      var last = 1;
      var total = 0;
      do {
        final body =
            await _get(client, '/orders', {'page': '$page', 'per_page': '200'});
        rows.addAll(_rows(body));
        last = _lastPage(body);
        total = _total(body);
        page++;
      } while (page <= last && page <= 100);
      if (!mounted) return;
      final visible = _onlyAssignedOrders(rows, _events);
      setState(() {
        _orders = visible;
        _ordersTotal = _assignedOnly ? visible.length : total;
        _ordersComplete = rows.length >= total;
      });
    } catch (_) {
      // Mantém os dados atuais; o botão Atualizar faz o carregamento completo.
    } finally {
      client.close();
    }
  }

  void _afterOrderChange(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    if (_orderEventId != null) _loadServiceOrders(_orderEventId!, quiet: true);
    _refreshOrders();
  }

  String _safeName(String value) => value
      .replaceAll(RegExp(r'[^A-Za-z0-9À-ÿ _-]'), '')
      .trim()
      .replaceAll(' ', '_');

  Future<void> _downloadZip(int id, Map<String, dynamic> data) async {
    final pending = '${data['status']}' == 'pending';
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('A preparar o ZIP…'), duration: Duration(seconds: 2)));
    final client = http.Client();
    try {
      final uri = Uri.parse('$_base/orders/$id/download-all')
          .replace(queryParameters: pending ? {'include_unpaid': '1'} : null);
      final response = await client.get(uri, headers: {
        'Accept': 'application/zip, application/json',
        'Authorization': 'Bearer $_token'
      }).timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        String message = '';
        try {
          final body = jsonDecode(response.body);
          if (body is Map) message = '${body['message'] ?? ''}';
        } catch (_) {}
        throw StateError(response.statusCode == 403
            ? 'Sem permissão para descarregar este pedido (403)${message.isEmpty ? '' : ': $message'}.'
            : response.statusCode == 422
                ? (message.isEmpty
                    ? 'Faltam fotografias originais neste pedido.'
                    : message)
                : 'Não foi possível gerar o ZIP (${response.statusCode}).');
      }
      final fileName =
          '${data['order_code'] ?? 'pedido_$id'}_${_safeName('${data['customer_name'] ?? ''}')}.zip';
      final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar ZIP do pedido',
          fileName: fileName,
          bytes: response.bodyBytes);
      if (path == null) return;
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        await File(path).writeAsBytes(response.bodyBytes, flush: true);
      }
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ZIP guardado: $fileName')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is StateError
                ? error.message.toString()
                : 'Não foi possível descarregar o ZIP.')));
    } finally {
      client.close();
    }
  }

  Future<void> _editOrder(int id, Map<String, dynamic> data) async {
    final name = TextEditingController(text: '${data['customer_name'] ?? ''}');
    final email =
        TextEditingController(text: '${data['customer_email'] ?? ''}');
    final phone =
        TextEditingController(text: '${data['customer_phone'] ?? ''}');
    final notes = TextEditingController(text: '${data['notes'] ?? ''}');
    var saving = false;
    String? formError;
    final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, update) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: Text('Editar ${data['order_code'] ?? 'pedido'}'),
                  content: SizedBox(
                      width: 460,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        TextField(
                            controller: name,
                            decoration: const InputDecoration(
                                labelText: 'Nome do cliente *')),
                        TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            decoration:
                                const InputDecoration(labelText: 'Email')),
                        TextField(
                            controller: phone,
                            keyboardType: TextInputType.phone,
                            decoration:
                                const InputDecoration(labelText: 'Telefone')),
                        TextField(
                            controller: notes,
                            maxLines: 3,
                            decoration:
                                const InputDecoration(labelText: 'Notas')),
                        if (formError != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(formError!,
                                  style: const TextStyle(
                                      color: Color(0xFFB3261E)))),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: saving
                            ? null
                            : () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: _rose),
                        onPressed: saving
                            ? null
                            : () async {
                                if (name.text.trim().isEmpty) {
                                  update(() =>
                                      formError = 'O nome é obrigatório.');
                                  return;
                                }
                                update(() {
                                  saving = true;
                                  formError = null;
                                });
                                final client = http.Client();
                                try {
                                  final response = await client
                                      .put(Uri.parse('$_base/orders/$id'),
                                          headers: {
                                            'Accept': 'application/json',
                                            'Content-Type': 'application/json',
                                            'Authorization': 'Bearer $_token'
                                          },
                                          body: jsonEncode({
                                            'customer_name': name.text.trim(),
                                            'customer_email': email.text.trim(),
                                            'customer_phone': phone.text.trim(),
                                            'notes': notes.text.trim(),
                                            'status':
                                                data['status'] ?? 'pending',
                                          }))
                                      .timeout(const Duration(seconds: 25));
                                  if (response.statusCode < 200 ||
                                      response.statusCode >= 300) {
                                    String message = '';
                                    try {
                                      final body = jsonDecode(response.body);
                                      if (body is Map)
                                        message = '${body['message'] ?? ''}';
                                    } catch (_) {}
                                    throw StateError(response.statusCode == 403
                                        ? 'Sem permissão para editar este pedido (403).'
                                        : message.isEmpty
                                            ? 'Não foi possível guardar (${response.statusCode}).'
                                            : message);
                                  }
                                  if (dialogContext.mounted)
                                    Navigator.pop(dialogContext, true);
                                } catch (error) {
                                  update(() {
                                    saving = false;
                                    formError = error is StateError
                                        ? error.message.toString()
                                        : 'Não foi possível contactar o servidor.';
                                  });
                                } finally {
                                  client.close();
                                }
                              },
                        child: Text(saving ? 'A guardar…' : 'Guardar')),
                  ],
                )));
    for (final c in [name, email, phone, notes]) {
      c.dispose();
    }
    if (saved == true && mounted) _afterOrderChange('Pedido atualizado.');
  }

  /// Ajuste de caixa: usa POST cash-adjustment; se o servidor ainda não o tiver, recorre a PUT do pedido.
  Future<void> _adjustCash(int id, Map<String, dynamic> data,
      {bool markChangeGiven = false}) async {
    final total = _c(data['total_amount']);
    final received = TextEditingController(
        text:
            _apiAmount(_c(data['cash_received_amount'])).replaceAll('.', ','));
    final reason = TextEditingController(
        text: markChangeGiven ? 'Troco entregue ao cliente' : '');
    var changeGiven = markChangeGiven || data['cash_change_given'] == true;
    var saving = false;
    String? formError;
    Future<String?> send(
        int receivedCents, int change, int due, bool given, String why) async {
      final client = http.Client();
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token'
      };
      final cash = {
        'cash_received_amount': _apiAmount(receivedCents),
        'cash_change_amount': _apiAmount(change),
        'cash_due_amount': _apiAmount(due),
        'cash_change_given': given,
      };
      try {
        var response = _offline
            ? null
            : await client
                .post(Uri.parse('$_base/orders/$id/cash-adjustment'),
                    headers: headers,
                    body: jsonEncode({
                      ...cash,
                      'notes': '${data['notes'] ?? ''}',
                      'reason': why
                    }))
                .timeout(const Duration(seconds: 25));
        if (response == null ||
            response.statusCode == 404 ||
            response.statusCode == 405) {
          response = await client
              .put(Uri.parse('$_base/orders/$id'),
                  headers: headers,
                  body: jsonEncode({
                    ...cash,
                    'customer_name': data['customer_name'] ?? '',
                    'status': due > 0
                        ? 'pending'
                        : (data['status'] == 'pending'
                            ? 'paid'
                            : data['status']),
                    'notes':
                        '${data['notes'] ?? ''}${why.isEmpty ? '' : '\n[Ajuste] $why'}'
                            .trim(),
                  }))
              .timeout(const Duration(seconds: 25));
        }
        if (response.statusCode >= 200 && response.statusCode < 300)
          return null;
        String message = '';
        try {
          final body = jsonDecode(response.body);
          if (body is Map) message = '${body['message'] ?? ''}';
        } catch (_) {}
        return response.statusCode == 403
            ? 'Sem permissão para ajustar a caixa deste pedido (403).'
            : message.isEmpty
                ? 'Não foi possível guardar (${response.statusCode}).'
                : message;
      } catch (_) {
        return 'Não foi possível contactar o servidor.';
      } finally {
        client.close();
      }
    }

    if (markChangeGiven) {
      final error = await send(
          _c(data['cash_received_amount']),
          _c(data['cash_change_amount']),
          _c(data['cash_due_amount']),
          true,
          'Troco entregue ao cliente');
      received.dispose();
      reason.dispose();
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      _afterOrderChange('Troco marcado como entregue.');
      return;
    }
    final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) =>
            StatefulBuilder(builder: (dialogContext, update) {
              final cents = _inputCents(received.text);
              final change =
                  cents == null || cents <= total ? 0 : cents - total;
              final due = cents == null || cents >= total ? 0 : total - cents;
              return AlertDialog(
                backgroundColor: Colors.white,
                title: Text('Trocos e dívidas · ${data['order_code'] ?? ''}'),
                content: SizedBox(
                    width: 460,
                    child: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          Text('Total do pedido: ${_money(total)}',
                              style: const TextStyle(
                                  color: _ink, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          TextField(
                              controller: received,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (_) => update(() => formError = null),
                              decoration: const InputDecoration(
                                  labelText: 'Total recebido do cliente (€)')),
                          const SizedBox(height: 10),
                          if (cents != null)
                            Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF2E5E3),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                    due > 0
                                        ? 'Cliente fica a dever ${_money(due)}'
                                        : change > 0
                                            ? 'Troco ao cliente: ${_money(change)}'
                                            : 'Pago a 100%, sem troco.',
                                    style: const TextStyle(
                                        color: _ink,
                                        fontWeight: FontWeight.w600))),
                          if (change > 0)
                            CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: changeGiven,
                                activeColor: _rose,
                                onChanged: (v) =>
                                    update(() => changeGiven = v ?? false),
                                title: const Text('Troco já entregue')),
                          TextField(
                              controller: reason,
                              decoration: const InputDecoration(
                                  labelText: 'Motivo do ajuste *')),
                          if (formError != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(formError!,
                                    style: const TextStyle(
                                        color: Color(0xFFB3261E)))),
                        ]))),
                actions: [
                  TextButton(
                      onPressed: saving
                          ? null
                          : () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _rose),
                      onPressed: saving
                          ? null
                          : () async {
                              if (cents == null) {
                                update(() => formError =
                                    'Indique o total recebido (ex.: 40 ou 12,50).');
                                return;
                              }
                              if (reason.text.trim().isEmpty) {
                                update(() =>
                                    formError = 'Indique o motivo do ajuste.');
                                return;
                              }
                              update(() {
                                saving = true;
                                formError = null;
                              });
                              final error = await send(
                                  cents,
                                  change,
                                  due,
                                  change > 0 && changeGiven,
                                  reason.text.trim());
                              if (error == null) {
                                if (dialogContext.mounted)
                                  Navigator.pop(dialogContext, true);
                              } else {
                                update(() {
                                  saving = false;
                                  formError = error;
                                });
                              }
                            },
                      child: Text(saving ? 'A guardar…' : 'Guardar ajuste')),
                ],
              );
            }));
    received.dispose();
    reason.dispose();
    if (saved == true && mounted)
      _afterOrderChange('Ajuste de caixa guardado.');
  }

  Widget _stateBadge(Map<String, dynamic> order) {
    final state = _payState(order);
    final amount = state == 'Deve'
        ? ' ${_money(_c(order['cash_due_amount']))}'
        : state == 'Troco'
            ? ' ${_money(_c(order['cash_change_amount']))}'
            : '';
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: _stateColor(state).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10)),
        child: Text('$state$amount',
            style: TextStyle(
                color: _stateColor(state),
                fontWeight: FontWeight.w700,
                fontSize: 12)));
  }

  Widget _countBadge(int count, String label, Color color, bool onDark) =>
      count <= 0
          ? const SizedBox.shrink()
          : Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: onDark ? Colors.white : color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$count $label',
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)));

  Widget _finderColumn(
          String title,
          List<(int, String, String, int, int)> items,
          int? selected,
          ValueChanged<int> onTap) =>
      Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFECE7E3))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Text(title,
                  style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700))),
          SizedBox(
              height: 230,
              child: items.isEmpty
                  ? const Center(
                      child: Text('—', style: TextStyle(color: _muted)))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final on = item.$1 == selected;
                        return Material(
                            color: on ? _rose : Colors.transparent,
                            child: InkWell(
                                onTap: () => onTap(item.$1),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 9),
                                  child: Row(children: [
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(item.$2,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color:
                                                      on ? Colors.white : _ink,
                                                  fontWeight: FontWeight.w600)),
                                          Text(item.$3,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: on
                                                      ? Colors.white70
                                                      : _muted,
                                                  fontSize: 11)),
                                        ])),
                                    _countBadge(item.$4, 'deve',
                                        const Color(0xFFB3261E), on),
                                    _countBadge(item.$5, 'troco',
                                        const Color(0xFFB26A00), on),
                                    Icon(Icons.chevron_right,
                                        size: 18,
                                        color: on ? Colors.white : _muted),
                                  ]),
                                )));
                      })),
        ]),
      );

  void _selectOrderEvent(int id) {
    setState(() {
      _orderEventId = id;
      _orderSearch = '';
      _ordersFilter = 'Todos';
      _serviceOrders =
          List<Map<String, dynamic>>.from(_finOrders[id] ?? const []);
      _serviceOrdersError = null;
    });
    _loadServiceOrders(id, quiet: true);
    if (_canSeeEventFinance) _loadRoster(id);
  }

  String _ordersFilter = 'Todos';

  Widget _tickets() {
    _buildFinIndex();
    Map<String, int> agg(String key) =>
        {..._finSums(const []), 'events': 0, ...?_finAgg[key]};
    (int, String, String, int, int) entry(
        int key, String label, String aggKey) {
      final s = agg(aggKey);
      return (
        key,
        label,
        '${s['events']} serv. · ${s['orders']} pedidos',
        s['Deve']!,
        s['Troco']!
      );
    }

    final years = [...?_finChildren['']]..sort((a, b) => b.compareTo(a));
    final year = _orderYear ??
        (years.contains(DateTime.now().year)
            ? DateTime.now().year
            : years.firstOrNull);
    final months = _finChildren['$year'] ?? const <int>[];
    final days = _finChildren['$year-$_orderMonth'] ?? const <int>[];
    final serviceIds = [...?_finChildren['$year-$_orderMonth-$_orderDay']]
      ..sort((a, b) => '${_finEventById[a]?['name']}'
          .compareTo('${_finEventById[b]?['name']}'));
    final selectedEvent =
        _orderEventId == null ? null : _finEventById[_orderEventId];
    final wide = MediaQuery.sizeOf(context).width >= 760;
    Widget dropdown(String label, int? value, List<int> choices,
            ValueChanged<int?> changed, String Function(int) text) =>
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<int>(
                key: ValueKey('$label-$year-$_orderMonth-$_orderDay'),
                value: choices.contains(value) ? value : null,
                isExpanded: true,
                decoration: InputDecoration(
                    labelText: label, border: const OutlineInputBorder()),
                items: choices
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(text(c), overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: choices.isEmpty ? null : changed));
    void pickYear(int? v) => setState(() {
          _orderYear = v;
          _orderMonth = null;
          _orderDay = null;
          _orderEventId = null;
          _serviceOrders = [];
        });
    void pickMonth(int? v) => setState(() {
          _orderMonth = v;
          _orderDay = null;
          _orderEventId = null;
          _serviceOrders = [];
        });
    void pickDay(int? v) => setState(() {
          _orderDay = v;
          _orderEventId = null;
          _serviceOrders = [];
        });
    final query = _orderSearch.trim().toLowerCase();
    final orders = _serviceOrders
        .where((o) =>
            (_ordersFilter == 'Todos' || _payState(o) == _ordersFilter) &&
            (query.isEmpty || jsonEncode(o).toLowerCase().contains(query)))
        .toList();
    final counts = <String, int>{};
    for (final o in _serviceOrders) {
      counts[_payState(o)] = (counts[_payState(o)] ?? 0) + 1;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Pedidos ($_ordersTotal)',
          style: const TextStyle(
              color: _ink, fontSize: 20, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _finderColumn(
                  'ANO',
                  [for (final y in years) entry(y, '$y', '$y')],
                  year,
                  pickYear)),
          const SizedBox(width: 8),
          Expanded(
              child: _finderColumn(
                  'MÊS',
                  [
                    for (final m in months) entry(m, _months[m - 1], '$year-$m')
                  ],
                  _orderMonth,
                  pickMonth)),
          const SizedBox(width: 8),
          Expanded(
              child: _finderColumn(
                  'DIA',
                  [
                    for (final d in days)
                      entry(d, '$d', '$year-$_orderMonth-$d')
                  ],
                  _orderDay,
                  pickDay)),
          const SizedBox(width: 8),
          Expanded(
              child: _finderColumn(
                  'EVENTO',
                  [
                    for (final id in serviceIds)
                      entry(id, '${_finEventById[id]?['name'] ?? 'Serviço'}',
                          'e:$id')
                  ],
                  _orderEventId,
                  _selectOrderEvent)),
        ])
      else ...[
        dropdown('Ano', year, years, pickYear, (y) => '$y'),
        dropdown('Mês', _orderMonth, months, pickMonth, (m) => _months[m - 1]),
        dropdown('Dia', _orderDay, days, pickDay, (d) => '$d'),
        dropdown('Serviço', _orderEventId, serviceIds, (id) {
          if (id != null) _selectOrderEvent(id);
        }, (id) => '${_finEventById[id]?['name'] ?? 'Serviço'}'),
      ],
      if (selectedEvent != null) ...[
        const SizedBox(height: 14),
        _card(Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${selectedEvent['name'] ?? 'Serviço'}',
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                Text(
                    [
                      '${_serviceOrders.length} pedidos',
                      if ((counts['Deve'] ?? 0) > 0) '${counts['Deve']} devem',
                      if ((counts['Troco'] ?? 0) > 0)
                        '${counts['Troco']} com troco por entregar',
                    ].join(' · '),
                    style: const TextStyle(color: _muted, fontSize: 12)),
              ])),
          Flexible(
              child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                if (_canZip && _serviceOrders.isNotEmpty)
                  FilledButton.icon(
                      onPressed: () =>
                          _downloadEventZip(_orderEventId!, selectedEvent),
                      style: FilledButton.styleFrom(backgroundColor: _rose),
                      icon: const Icon(Icons.folder_zip_outlined, size: 18),
                      label: const Text('Descarregar pedidos (ZIP)')),
                if (_can('events.view') && !_offline)
                  OutlinedButton.icon(
                      onPressed: () => _openEvent(selectedEvent),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: _rose,
                          side: const BorderSide(color: _rose)),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Ficha do serviço')),
              ])),
        ])),
        if (_canSeeEventFinance) ...[
          const SizedBox(height: 12),
          _eventCalcCard(_orderEventId!, selectedEvent, _serviceOrders,
              _finSums(_serviceOrders)),
        ],
        const SizedBox(height: 10),
        TextField(
            key: ValueKey('search-$_orderEventId'),
            decoration: const InputDecoration(
                labelText: 'Pesquisar em qualquer campo',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder()),
            onChanged: (value) => setState(() => _orderSearch = value)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in const [
            'Todos',
            'Deve',
            'Troco',
            'Pago',
            'Por atender'
          ])
            ChoiceChip(
                label: Text(f == 'Todos'
                    ? 'Todos (${_serviceOrders.length})'
                    : '$f (${counts[f] ?? 0})'),
                selected: _ordersFilter == f,
                selectedColor: const Color(0xFFF2E5E3),
                onSelected: (_) => setState(() => _ordersFilter = f)),
        ]),
        const SizedBox(height: 10),
        if (_serviceOrdersLoading && _serviceOrders.isEmpty)
          const Center(child: CircularProgressIndicator(color: _rose)),
        if (_serviceOrdersError != null)
          _card(
              Text(_serviceOrdersError!, style: const TextStyle(color: _ink))),
        if (!_serviceOrdersLoading && orders.isEmpty)
          _card(Text(
              query.isEmpty
                  ? 'Sem pedidos neste filtro.'
                  : 'Sem resultados para esta pesquisa.',
              style: const TextStyle(color: _muted))),
        for (final order in orders)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _openOrder(order),
                borderRadius: BorderRadius.circular(16),
                child: _card(Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            '${order['order_code'] ?? 'Pedido'} · ${order['customer_name'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _ink, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(
                            [
                              'Total ${_money(_c(order['total_amount']))}',
                              if (order['cash_received_amount'] != null)
                                'recebido ${_money(_c(order['cash_received_amount']))}',
                              if (_c(order['cash_change_amount']) > 0)
                                'troco ${_money(_c(order['cash_change_amount']))} ${order['cash_change_given'] == true ? 'entregue' : 'por entregar'}',
                              _statusLabel(order['status']),
                            ].join(' · '),
                            style:
                                const TextStyle(color: _muted, fontSize: 12)),
                      ])),
                  _stateBadge(order),
                ])),
              )),
      ],
    ]);
  }

  // ---- ZIP de todos os pedidos de um evento ----
  Future<void> _downloadEventZip(
      int eventId, Map<String, dynamic> event) async {
    const layout = 'flat';
    var scope = 'all';
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, update) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: const Text('Descarregar pedidos (ZIP)'),
                  content: SizedBox(
                      width: 440,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${event['name'] ?? 'Serviço'}',
                                style: const TextStyle(
                                    color: _ink, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            const Text(
                                'Fotografias escolhidas mais do que uma vez aparecem repetidas no ZIP, uma cópia por unidade.',
                                style: TextStyle(color: _muted, fontSize: 12)),
                            const SizedBox(height: 14),
                            const Text(
                                'Todas as fotografias ficam juntas no ZIP (ex.: «0001.jpg», «0001 (2).jpg»).',
                                style: TextStyle(color: _muted, fontSize: 12)),
                            const SizedBox(height: 6),
                            const Text('Pedidos incluídos',
                                style: TextStyle(
                                    color: _ink, fontWeight: FontWeight.w700)),
                            RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                value: 'all',
                                groupValue: scope,
                                activeColor: _rose,
                                onChanged: (v) => update(() => scope = v!),
                                title: const Text('Todos (exceto cancelados)')),
                            RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                value: 'paid',
                                groupValue: scope,
                                activeColor: _rose,
                                onChanged: (v) => update(() => scope = v!),
                                title: const Text('Só pedidos pagos a 100%')),
                          ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancelar')),
                    FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _rose),
                        onPressed: () => Navigator.pop(dialogContext, true),
                        icon: const Icon(Icons.folder_zip_outlined, size: 18),
                        label: const Text('Descarregar')),
                  ],
                )));
    if (confirmed != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('A preparar o ZIP do evento… pode demorar alguns minutos.'),
        duration: Duration(seconds: 4)));
    final client = http.Client();
    try {
      final uri = Uri.parse('$_base/events/$eventId/orders/download-zip')
          .replace(queryParameters: {'layout': layout, 'scope': scope});
      final response = await client.get(uri, headers: {
        'Accept': 'application/zip, application/json',
        'Authorization': 'Bearer $_token'
      }).timeout(const Duration(minutes: 15));
      if (response.statusCode != 200) {
        String message = '';
        try {
          final body = jsonDecode(response.body);
          if (body is Map) message = '${body['message'] ?? ''}';
        } catch (_) {}
        throw StateError(response.statusCode == 404
            ? 'O servidor ainda não tem o ZIP por evento (ver especificação do backend).'
            : response.statusCode == 403
                ? 'Sem permissão para descarregar este evento (403).'
                : message.isEmpty
                    ? 'Não foi possível gerar o ZIP (${response.statusCode}).'
                    : message);
      }
      final fileName =
          '${_safeName('${event['name'] ?? 'evento_$eventId'}')}_pedidos.zip';
      final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar ZIP dos pedidos',
          fileName: fileName,
          bytes: response.bodyBytes);
      if (path == null) return;
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        await File(path).writeAsBytes(response.bodyBytes, flush: true);
      }
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ZIP guardado: $fileName')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is StateError
                ? error.message.toString()
                : 'Não foi possível descarregar o ZIP.')));
    } finally {
      client.close();
    }
  }

  // ---- Configurações › Templates de Fichas ----
  String _settingsSection = '';
  List<Map<String, dynamic>> _templates = [];
  bool _templatesLoading = false;
  String? _templatesError;

  static const _fieldTypes = <String, String>{
    'text': 'Texto',
    'textarea': 'Texto longo',
    'number': 'Número',
    'date': 'Data',
    'time': 'Hora',
    'checkbox': 'Sim/Não',
    'select': 'Lista de opções',
    'email': 'Email',
  };

  String _slugify(String value) {
    const from = 'àáâãäçèéêëìíîïñòóôõöùúûüýÀÁÂÃÄÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ';
    const to = 'aaaaaceeeeiiiinooooouuuuyAAAAACEEEEIIIINOOOOOUUUUY';
    final buffer = StringBuffer();
    for (final char in value.trim().split('')) {
      final index = from.indexOf(char);
      buffer.write(index >= 0 ? to[index] : char);
    }
    return buffer
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _templatesLoading = true;
      _templatesError = null;
    });
    final client = http.Client();
    try {
      final body = await _get(
          client, '/events/service-templates', {'include_inactive': '1'});
      final rows = _rows(body)
        ..sort((a, b) => (int.tryParse('${a['sort_order']}') ?? 0)
            .compareTo(int.tryParse('${b['sort_order']}') ?? 0));
      if (mounted)
        setState(() {
          _templates = rows;
          _templatesLoading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _templatesError = error is StateError
              ? error.message.toString()
              : 'Não foi possível carregar os templates.';
          _templatesLoading = false;
        });
    } finally {
      client.close();
    }
  }

  Widget _settings() {
    if (_settingsSection == 'contrato') return _contractTemplateEditor();
    if (_settingsSection == '') {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Configurações',
            style: TextStyle(
                color: _ink, fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() => _settingsSection = 'templates');
              _loadTemplates();
            },
            child: _card(const Row(children: [
              Icon(Icons.dynamic_form_outlined, color: _rose, size: 28),
              SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Templates de Fichas',
                        style: TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 3),
                    Text(
                        'Campos da ficha de cada tipo de serviço (uma ficha por tipo).',
                        style: TextStyle(color: _muted)),
                  ])),
              Icon(Icons.chevron_right, color: _muted),
            ]))),
        const SizedBox(height: 10),
        InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() => _settingsSection = 'contrato');
              _loadContractTpl();
            },
            child: _card(const Row(children: [
              Icon(Icons.description_outlined, color: _rose, size: 28),
              SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Modelo de contrato',
                        style: TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 3),
                    Text(
                        'Texto base dos contratos, com os dados de cada evento preenchidos automaticamente.',
                        style: TextStyle(color: _muted)),
                  ])),
              Icon(Icons.chevron_right, color: _muted),
            ]))),
        const SizedBox(height: 10),
        InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.pushNamed('Studio59SyncOnline'),
            child: _card(const Row(children: [
              Icon(Icons.cloud_sync_outlined, color: _rose, size: 28),
              SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Sincronização offline',
                        style: TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 3),
                    Text(
                        'Enviar para o servidor os pedidos e fotografias de uma sessão offline.',
                        style: TextStyle(color: _muted)),
                  ])),
              Icon(Icons.chevron_right, color: _muted),
            ]))),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        IconButton(
            onPressed: () => setState(() => _settingsSection = ''),
            icon: const Icon(Icons.arrow_back, color: _ink)),
        const Expanded(
            child: Text('Templates de Fichas',
                style: TextStyle(
                    color: _ink, fontSize: 20, fontWeight: FontWeight.w600))),
        FilledButton.icon(
            onPressed: () => _editTemplate(null),
            style: FilledButton.styleFrom(backgroundColor: _rose),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nova ficha')),
      ]),
      const Padding(
          padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Text(
              'Cada ficha está associada a um único tipo de serviço. Os eventos desse tipo usam estes campos na ficha do serviço.',
              style: TextStyle(color: _muted))),
      if (_templatesLoading)
        const Center(child: CircularProgressIndicator(color: _rose)),
      if (_templatesError != null)
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_templatesError!, style: const TextStyle(color: _ink)),
          TextButton(
              onPressed: _loadTemplates, child: const Text('Tentar novamente')),
        ])),
      if (!_templatesLoading && _templatesError == null && _templates.isEmpty)
        _card(const Text('Ainda não existem fichas.',
            style: TextStyle(color: _muted))),
      for (final template in _templates)
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _editTemplate(template),
              child: _card(Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${template['name'] ?? template['slug']}',
                          style: const TextStyle(
                              color: _ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      Text(
                          'Tipo: ${template['slug']} · ${(template['fields'] is List ? (template['fields'] as List).length : 0)} campos',
                          style: const TextStyle(color: _muted, fontSize: 12)),
                    ])),
                if (template['is_active'] == false)
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: const Color(0xFFEEEEEE),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Text('Inativa',
                          style: TextStyle(
                              color: _muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600))),
                const Icon(Icons.chevron_right, color: _muted),
              ])),
            )),
    ]);
  }

  static const _fieldIcons = <String, IconData>{
    'text': Icons.short_text,
    'textarea': Icons.notes,
    'number': Icons.pin_outlined,
    'date': Icons.calendar_today_outlined,
    'time': Icons.schedule,
    'checkbox': Icons.check_box_outlined,
    'select': Icons.list_alt,
    'email': Icons.alternate_email,
  };

  static const _autoValues = <String, String>{
    '': 'Nenhum (preenchido à mão)',
    'sequence': 'Número sequencial (+1 em cada novo)',
    'today': 'Data de hoje',
    'now': 'Hora atual',
    'user': 'Utilizador que cria',
    'on_save': 'Gerado pelo servidor ao guardar',
  };

  bool get _desktopUi =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Grelha da ficha: larguras inteira / metade / um terço; em ecrãs estreitos tudo em linha inteira.
  Widget _fichaGrid(List<(String, Widget)> items) =>
      LayoutBuilder(builder: (context, constraints) {
        const gap = 12.0;
        final w = constraints.maxWidth;
        final narrow = w < 520;
        double size(String width) => narrow
            ? w
            : width == 'third'
                ? (w - 2 * gap) / 3 - 0.5
                : width == 'half'
                    ? (w - gap) / 2 - 0.5
                    : w;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final item in items)
            SizedBox(width: size(item.$1), child: item.$2)
        ]);
      });

  Future<void> _editTemplate(Map<String, dynamic>? existing) async {
    final id = int.tryParse('${existing?['id'] ?? ''}');
    final settings = _object(existing?['settings']);
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final description =
        TextEditingController(text: '${existing?['description'] ?? ''}');
    final newType = TextEditingController();
    final nameFields = TextEditingController(
        text:
            '${settings['name_fields'] is List ? (settings['name_fields'] as List).join(',') : settings['name_fields'] ?? ''}');
    var slug = '${existing?['slug'] ?? ''}';
    var active = existing?['is_active'] != false;
    final usedTypes = {
      for (final t in _templates)
        if (t != existing) '${t['slug']}'
    };
    final knownTypes = <String>{
      ..._templates.map((t) => '${t['slug']}'),
      ..._events
          .map((e) => '${e['event_type'] ?? ''}')
          .where((t) => t.isNotEmpty),
    }.toList()
      ..sort();
    var uidSeed = 0;
    final fields = <Map<String, dynamic>>[
      for (final raw in (existing?['fields'] is List
              ? existing!['fields'] as List
              : const [])
          .whereType<Map>())
        {...Map<String, dynamic>.from(raw), '_uid': uidSeed++},
    ]..sort((a, b) {
        final s = (int.tryParse('${a['section_order']}') ?? 0)
            .compareTo(int.tryParse('${b['section_order']}') ?? 0);
        return s != 0
            ? s
            : (int.tryParse('${a['order']}') ?? 0)
                .compareTo(int.tryParse('${b['order']}') ?? 0);
      });
    for (final f in fields) {
      if ('${f['section'] ?? ''}'.trim().isEmpty) f['section'] = 'Geral';
    }
    final sections =
        <String>[for (final f in fields) '${f['section']}'].toSet().toList();
    if (sections.isEmpty) sections.add('Geral');
    final ctrl = <int, Map<String, TextEditingController>>{};
    final keyEdited = <int>{for (final f in fields) f['_uid'] as int};
    int? selected;
    var saving = false;
    String? formError;
    Map<String, TextEditingController> controllersFor(Map<String, dynamic> f) =>
        ctrl.putIfAbsent(
            f['_uid'] as int,
            () => {
                  'label': TextEditingController(text: '${f['label'] ?? ''}'),
                  'key': TextEditingController(text: '${f['key'] ?? ''}'),
                  'placeholder':
                      TextEditingController(text: '${f['placeholder'] ?? ''}'),
                  'options': TextEditingController(
                      text: f['options'] is List
                          ? (f['options'] as List)
                              .map((o) => o is Map
                                  ? '${o['label'] ?? o['value']}'
                                  : '$o')
                              .join('\n')
                          : ''),
                });
    String labelOf(Map<String, dynamic> f) =>
        controllersFor(f)['label']!.text.trim();

    final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) =>
            StatefulBuilder(builder: (dialogContext, update) {
              Map<String, dynamic>? fieldBy(int? uid) => uid == null
                  ? null
                  : fields.where((f) => f['_uid'] == uid).firstOrNull;
              List<Map<String, dynamic>> inSection(String section) =>
                  fields.where((f) => f['section'] == section).toList();

              /// Coloca um campo (novo ou existente) numa secção, antes de [beforeUid] ou no fim da secção.
              void place(Object data, String section, int? beforeUid) {
                update(() {
                  Map<String, dynamic> f;
                  if (data is int) {
                    f = fieldBy(data)!;
                    if (data == beforeUid) return;
                    fields.remove(f);
                  } else {
                    f = {
                      '_uid': uidSeed++,
                      'type': '$data',
                      'source': 'meta',
                      'width': data == 'textarea' ? 'full' : 'half',
                      'show_in_form': true,
                      'show_in_pdf': true,
                      'required': false,
                      'label': '',
                      'key': ''
                    };
                    controllersFor(f)['label']!.text =
                        _fieldTypes['$data'] ?? 'Campo';
                    controllersFor(f)['key']!.text = '';
                  }
                  f['section'] = section;
                  final before = beforeUid == null ? null : fieldBy(beforeUid);
                  if (before != null) {
                    fields.insert(fields.indexOf(before), f);
                  } else {
                    final last = inSection(section).lastOrNull;
                    fields.insert(
                        last == null ? fields.length : fields.indexOf(last) + 1,
                        f);
                  }
                  selected = f['_uid'] as int;
                });
              }

              String? validate() {
                final keys = <String>{};
                for (final f in fields) {
                  final c = controllersFor(f);
                  if (c['label']!.text.trim().isEmpty)
                    return 'Há um campo sem nome.';
                  final k = _slugify(c['key']!.text.isEmpty
                      ? c['label']!.text
                      : c['key']!.text);
                  if (k.isEmpty)
                    return 'O campo «${c['label']!.text}» precisa de uma chave.';
                  if (!keys.add(k))
                    return 'Há dois campos com a chave «$k». Altere o nome de um deles.';
                  if (f['type'] == 'select' &&
                      c['options']!.text.trim().isEmpty)
                    return 'O campo «${c['label']!.text}» precisa de opções.';
                }
                return null;
              }

              List<Map<String, dynamic>> payloadFields() {
                final result = <Map<String, dynamic>>[];
                var order = 1;
                for (var s = 0; s < sections.length; s++) {
                  for (final f in inSection(sections[s])) {
                    final c = controllersFor(f);
                    final opts = c['options']!
                        .text
                        .split(RegExp(r'[\n,]'))
                        .map((o) => o.trim())
                        .where((o) => o.isNotEmpty)
                        .toList();
                    result.add({
                      ...Map<String, dynamic>.from(f)..remove('_uid'),
                      'label': c['label']!.text.trim(),
                      'key': _slugify(c['key']!.text.isEmpty
                          ? c['label']!.text
                          : c['key']!.text),
                      'section': sections[s],
                      'section_order': s + 1,
                      'order': order++,
                      'placeholder': c['placeholder']!.text.trim().isEmpty
                          ? null
                          : c['placeholder']!.text.trim(),
                      'options': f['type'] == 'select' ? opts : null,
                      'source': f['source'] ?? 'meta',
                    });
                  }
                }
                return result;
              }

              Future<void> save() async {
                final finalSlug =
                    slug == '__new__' ? _slugify(newType.text) : slug;
                if (name.text.trim().isEmpty) {
                  update(() => formError = 'Indique o nome da ficha.');
                  return;
                }
                if (finalSlug.isEmpty) {
                  update(() => formError = 'Escolha o tipo de serviço.');
                  return;
                }
                if (usedTypes.contains(finalSlug)) {
                  update(() => formError =
                      'O tipo «$finalSlug» já tem uma ficha. Só é possível uma ficha por tipo de serviço.');
                  return;
                }
                final problem = validate();
                if (problem != null) {
                  update(() => formError = problem);
                  return;
                }
                final sentFields = payloadFields();
                update(() {
                  saving = true;
                  formError = null;
                });
                final payload = {
                  'slug': finalSlug,
                  'name': name.text.trim(),
                  'description': description.text.trim(),
                  'is_active': active,
                  'sort_order':
                      int.tryParse('${existing?['sort_order'] ?? ''}') ??
                          _templates.length,
                  'settings': {
                    ...settings,
                    'name_fields': nameFields.text
                        .split(',')
                        .map((f) => f.trim())
                        .where((f) => f.isNotEmpty)
                        .toList(),
                    'name_joiner': settings['name_joiner'] ?? ' - '
                  },
                  'fields': sentFields,
                };
                final client = http.Client();
                try {
                  final headers = {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $_token'
                  };
                  final response = id == null
                      ? await client
                          .post(Uri.parse('$_base/service-templates'),
                              headers: headers, body: jsonEncode(payload))
                          .timeout(const Duration(seconds: 25))
                      : await client
                          .put(Uri.parse('$_base/service-templates/$id'),
                              headers: headers, body: jsonEncode(payload))
                          .timeout(const Duration(seconds: 25));
                  if (response.statusCode < 200 || response.statusCode >= 300) {
                    String message = '';
                    try {
                      final body = jsonDecode(response.body);
                      if (body is Map)
                        message =
                            '${body['message'] ?? ''} ${body['errors'] ?? ''}'
                                .trim();
                    } catch (_) {}
                    throw StateError(response.statusCode == 404 ||
                            response.statusCode == 405
                        ? 'O servidor ainda não permite gerir templates pela app (ver especificação do backend).'
                        : response.statusCode == 403
                            ? 'Sem permissão para gerir templates (403).'
                            : message.isEmpty
                                ? 'Não foi possível guardar (${response.statusCode}).'
                                : message);
                  }
                  // Confirmação: volta a ler a ficha do servidor e verifica que todos os campos ficaram gravados.
                  final check = _rows(await _get(client,
                      '/events/service-templates', {'include_inactive': '1'}));
                  final stored = check
                      .where((t) => '${t['slug']}' == finalSlug)
                      .firstOrNull;
                  final storedKeys = (stored?['fields'] is List
                          ? stored!['fields'] as List
                          : const [])
                      .whereType<Map>()
                      .map((f) => '${f['key']}')
                      .toSet();
                  final missing = sentFields
                      .map((f) => '${f['key']}')
                      .where((k) => !storedKeys.contains(k))
                      .toList();
                  if (stored == null || missing.isNotEmpty) {
                    throw StateError(stored == null
                        ? 'O servidor respondeu OK mas a ficha não aparece na lista. Verifique no servidor.'
                        : 'O servidor não gravou ${missing.length} campo(s): ${missing.join(', ')}.');
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (error) {
                  update(() {
                    saving = false;
                    formError = error is StateError
                        ? error.message.toString()
                        : 'Não foi possível contactar o servidor.';
                  });
                } finally {
                  client.close();
                }
              }

              Future<void> remove() async {
                final sure = await showDialog<bool>(
                    context: dialogContext,
                    builder: (c) => AlertDialog(
                            title: const Text('Apagar esta ficha?'),
                            content: const Text(
                                'Os eventos já criados mantêm os dados, mas o tipo de serviço deixa de ter campos próprios.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancelar')),
                              TextButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Apagar',
                                      style:
                                          TextStyle(color: Color(0xFFB3261E))))
                            ]));
                if (sure != true) return;
                update(() {
                  saving = true;
                  formError = null;
                });
                final client = http.Client();
                try {
                  final response = await client.delete(
                      Uri.parse('$_base/service-templates/$id'),
                      headers: {
                        'Accept': 'application/json',
                        'Authorization': 'Bearer $_token'
                      }).timeout(const Duration(seconds: 25));
                  if (response.statusCode < 200 || response.statusCode >= 300) {
                    throw StateError(response.statusCode == 409
                        ? 'Esta ficha está em uso por eventos e não pode ser apagada. Desative-a.'
                        : 'Não foi possível apagar (${response.statusCode}).');
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (error) {
                  update(() {
                    saving = false;
                    formError = error is StateError
                        ? error.message.toString()
                        : 'Não foi possível contactar o servidor.';
                  });
                } finally {
                  client.close();
                }
              }

              InputDecoration dense(String label, {String? helper}) =>
                  InputDecoration(
                      labelText: label,
                      helperText: helper,
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)));

              Widget draggable(
                      Object data, Widget child, Widget feedback) =>
                  _desktopUi
                      ? Draggable<Object>(
                          data: data,
                          feedback: Material(
                              color: Colors.transparent, child: feedback),
                          childWhenDragging:
                              Opacity(opacity: 0.35, child: child),
                          child: child)
                      : LongPressDraggable<Object>(
                          data: data,
                          feedback: Material(
                              color: Colors.transparent, child: feedback),
                          childWhenDragging:
                              Opacity(opacity: 0.35, child: child),
                          child: child);

              Widget chip(String type) => Chip(
                  avatar: Icon(_fieldIcons[type], size: 18, color: _rose),
                  label: Text(_fieldTypes[type] ?? type),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFECE7E3)));

              // Campo na ficha (pré-visualização igual à ficha real).
              Widget tile(Map<String, dynamic> f) {
                final uid = f['_uid'] as int;
                final type = '${f['type'] ?? 'text'}';
                final isSel = selected == uid;
                final label = labelOf(f).isEmpty ? 'Sem nome' : labelOf(f);
                final mock = Container(
                    height: type == 'textarea' ? 64 : 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: type == 'textarea'
                        ? Alignment.topLeft
                        : Alignment.centerLeft,
                    decoration: BoxDecoration(
                        color: const Color(0xFFFAF9F7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDDD5D1))),
                    child: Row(children: [
                      Icon(_fieldIcons[type], size: 16, color: _muted),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(
                              type == 'select'
                                  ? (controllersFor(f)['options']!
                                      .text
                                      .split('\n')
                                      .first)
                                  : (controllersFor(f)['placeholder']!
                                          .text
                                          .isEmpty
                                      ? _fieldTypes[type] ?? ''
                                      : controllersFor(f)['placeholder']!.text),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFFB9AEAA), fontSize: 12))),
                      if (type == 'select')
                        const Icon(Icons.arrow_drop_down, color: _muted),
                      if ('${f['auto'] ?? ''}'.isNotEmpty)
                        const Tooltip(
                            message: 'Valor automático',
                            child: Icon(Icons.auto_fix_high,
                                size: 16, color: _rose)),
                    ]));
                final body = Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: isSel ? const Color(0xFFF7EEEC) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isSel ? _rose : Colors.transparent,
                            width: 1.6)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.drag_indicator,
                                size: 16, color: Color(0xFFB9AEAA)),
                            const SizedBox(width: 2),
                            Expanded(
                                child: Text(
                                    '$label${f['required'] == true ? ' *' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: f['show_in_form'] == false
                                            ? _muted
                                            : _ink,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        decoration: f['show_in_form'] == false
                                            ? TextDecoration.lineThrough
                                            : null))),
                          ]),
                          const SizedBox(height: 4),
                          mock,
                        ]));
                return DragTarget<Object>(
                  onWillAcceptWithDetails: (d) => d.data != uid,
                  onAcceptWithDetails: (d) =>
                      place(d.data, '${f['section']}', uid),
                  builder: (context, candidates, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (candidates.isNotEmpty)
                          Container(
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                  color: _rose,
                                  borderRadius: BorderRadius.circular(2))),
                        MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: GestureDetector(
                              onTap: () => update(() => selected = uid),
                              child: draggable(
                                  uid,
                                  body,
                                  SizedBox(
                                      width: 260,
                                      child:
                                          Opacity(opacity: 0.9, child: body))),
                            )),
                      ]),
                );
              }

              Widget sectionCard(int s) {
                final title = sections[s];
                final items = inSection(title);
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFECE7E3))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                          decoration: const BoxDecoration(
                              color: Color(0xFFF2E5E3),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16))),
                          child: Row(children: [
                            Expanded(
                                child: TextFormField(
                              key: ValueKey('section-$s-$title'),
                              initialValue: title,
                              style: const TextStyle(
                                  color: _ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700),
                              decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintText: 'Nome da secção'),
                              onFieldSubmitted: (v) {
                                final value = v.trim();
                                if (value.isEmpty ||
                                    value == title ||
                                    sections.contains(value)) return;
                                update(() {
                                  for (final f in items) {
                                    f['section'] = value;
                                  }
                                  sections[s] = value;
                                });
                              },
                              onTapOutside: (_) =>
                                  FocusScope.of(dialogContext).unfocus(),
                            )),
                            IconButton(
                                tooltip: 'Subir secção',
                                onPressed: s == 0
                                    ? null
                                    : () => update(() {
                                          final t = sections.removeAt(s);
                                          sections.insert(s - 1, t);
                                        }),
                                icon: const Icon(Icons.arrow_upward, size: 18)),
                            IconButton(
                                tooltip: 'Descer secção',
                                onPressed: s == sections.length - 1
                                    ? null
                                    : () => update(() {
                                          final t = sections.removeAt(s);
                                          sections.insert(s + 1, t);
                                        }),
                                icon:
                                    const Icon(Icons.arrow_downward, size: 18)),
                            IconButton(
                                tooltip: items.isEmpty
                                    ? 'Apagar secção'
                                    : 'Só é possível apagar secções vazias',
                                onPressed: items.isNotEmpty ||
                                        sections.length == 1
                                    ? null
                                    : () => update(() => sections.removeAt(s)),
                                icon:
                                    const Icon(Icons.delete_outline, size: 18)),
                          ]),
                        ),
                        Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _fichaGrid([
                                    for (final f in items)
                                      ('${f['width'] ?? 'full'}', tile(f))
                                  ]),
                                  const SizedBox(height: 10),
                                  DragTarget<Object>(
                                    onAcceptWithDetails: (d) =>
                                        place(d.data, title, null),
                                    builder: (context, candidates, _) =>
                                        InkWell(
                                      onTap: () => place('text', title, null),
                                      borderRadius: BorderRadius.circular(10),
                                      child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 120),
                                          height: candidates.isEmpty ? 40 : 56,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                              color: candidates.isEmpty
                                                  ? const Color(0xFFFAF9F7)
                                                  : const Color(0xFFF2E5E3),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: candidates.isEmpty
                                                      ? const Color(0xFFDDD5D1)
                                                      : _rose,
                                                  width: candidates.isEmpty
                                                      ? 1
                                                      : 1.5)),
                                          child: Text(
                                              candidates.isEmpty
                                                  ? '+ Arraste um campo para aqui ou toque para adicionar'
                                                  : 'Largar no fim de «$title»',
                                              style: TextStyle(
                                                  color: candidates.isEmpty
                                                      ? _muted
                                                      : _rose,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600))),
                                    ),
                                  ),
                                ])),
                      ]),
                );
              }

              Widget properties() {
                final f = fieldBy(selected);
                if (f == null) {
                  return _card(const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Propriedades',
                            style: TextStyle(
                                color: _ink, fontWeight: FontWeight.w700)),
                        SizedBox(height: 6),
                        Text(
                            'Toque num campo da ficha para o editar. Arraste os campos para mudar a ordem ou a secção.',
                            style: TextStyle(color: _muted)),
                      ]));
                }
                final uid = f['_uid'] as int;
                final c = controllersFor(f);
                final type = '${f['type'] ?? 'text'}';
                return _card(Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        const Expanded(
                            child: Text('Propriedades do campo',
                                style: TextStyle(
                                    color: _ink, fontWeight: FontWeight.w700))),
                        IconButton(
                            tooltip: 'Fechar',
                            onPressed: () => update(() => selected = null),
                            icon: const Icon(Icons.close, size: 18)),
                      ]),
                      const SizedBox(height: 8),
                      TextField(
                          key: ValueKey('label-$uid'),
                          controller: c['label'],
                          decoration: dense('Nome do campo *'),
                          onChanged: (v) => update(() {
                                if (!keyEdited.contains(uid))
                                  c['key']!.text = _slugify(v);
                              })),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                          key: ValueKey('type-$uid'),
                          value: _fieldTypes.containsKey(type) ? type : 'text',
                          isDense: true,
                          decoration: dense('Tipo'),
                          items: _fieldTypes.entries
                              .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Row(children: [
                                    Icon(_fieldIcons[e.key],
                                        size: 18, color: _rose),
                                    const SizedBox(width: 8),
                                    Text(e.value)
                                  ])))
                              .toList(),
                          onChanged: (v) =>
                              update(() => f['type'] = v ?? 'text')),
                      const SizedBox(height: 10),
                      const Text('Largura',
                          style: TextStyle(color: _muted, fontSize: 12)),
                      const SizedBox(height: 4),
                      SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                                value: 'full', label: Text('Inteira')),
                            ButtonSegment(value: 'half', label: Text('Metade')),
                            ButtonSegment(value: 'third', label: Text('1/3'))
                          ],
                          selected: {
                            const ['full', 'half', 'third'].contains(f['width'])
                                ? '${f['width']}'
                                : 'full'
                          },
                          onSelectionChanged: (v) =>
                              update(() => f['width'] = v.first),
                          style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: const Color(0xFFF2E5E3),
                              selectedForegroundColor: _rose)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                          key: ValueKey('section-of-$uid-${f['section']}'),
                          value: '${f['section']}',
                          isDense: true,
                          decoration: dense('Secção'),
                          items: sections
                              .map((s) =>
                                  DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) place(uid, v, null);
                          }),
                      const SizedBox(height: 10),
                      if (type == 'select') ...[
                        TextField(
                            key: ValueKey('options-$uid'),
                            controller: c['options'],
                            maxLines: 4,
                            decoration: dense('Opções (uma por linha)'),
                            onChanged: (_) => update(() {})),
                        const SizedBox(height: 10),
                      ],
                      DropdownButtonFormField<String>(
                          key: ValueKey('auto-$uid'),
                          value: _autoValues.containsKey('${f['auto'] ?? ''}')
                              ? '${f['auto'] ?? ''}'
                              : '',
                          isDense: true,
                          isExpanded: true,
                          decoration: dense('Valor automático',
                              helper: f['auto'] == 'sequence' ||
                                      f['auto'] == 'on_save'
                                  ? 'Só de leitura na ficha'
                                  : null),
                          items: _autoValues.entries
                              .map((e) => DropdownMenuItem(
                                  value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: (v) => update(() {
                                f['auto'] = (v ?? '').isEmpty ? null : v;
                                if (v == 'sequence') f['type'] = 'number';
                              })),
                      const SizedBox(height: 10),
                      TextField(
                          key: ValueKey('ph-$uid'),
                          controller: c['placeholder'],
                          decoration: dense('Texto de ajuda'),
                          onChanged: (_) => update(() {})),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: f['required'] == true,
                          activeColor: _rose,
                          onChanged: (v) => update(() => f['required'] = v),
                          title: const Text('Obrigatório')),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: f['show_in_form'] != false,
                          activeColor: _rose,
                          onChanged: (v) => update(() => f['show_in_form'] = v),
                          title: const Text('Mostrar no formulário')),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: f['show_in_pdf'] != false,
                          activeColor: _rose,
                          onChanged: (v) => update(() => f['show_in_pdf'] = v),
                          title: const Text('Mostrar no PDF')),
                      TextField(
                          key: ValueKey('key-$uid'),
                          controller: c['key'],
                          decoration: dense('Chave interna',
                              helper:
                                  'Nome com que o valor fica guardado na base de dados'),
                          onChanged: (_) => keyEdited.add(uid)),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                          onPressed: () => update(() {
                                fields.remove(f);
                                ctrl.remove(uid);
                                selected = null;
                              }),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFB3261E),
                              side: const BorderSide(color: Color(0xFFB3261E))),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Remover campo')),
                    ]));
              }

              Widget palette() => _card(Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Campos',
                            style: TextStyle(
                                color: _ink, fontWeight: FontWeight.w700)),
                        Text(
                            _desktopUi
                                ? 'Arraste para a ficha.'
                                : 'Mantenha premido e arraste para a ficha.',
                            style:
                                const TextStyle(color: _muted, fontSize: 12)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final t in _fieldTypes.keys)
                            draggable(t, chip(t), chip(t))
                        ]),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                            onPressed: () => update(() {
                                  var n = sections.length + 1;
                                  while (sections.contains('Secção $n')) {
                                    n++;
                                  }
                                  sections.add('Secção $n');
                                }),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Nova secção')),
                      ]));

              Widget settingsCard() => _card(Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                            controller: name,
                            decoration: dense('Nome da ficha *')),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                            value: slug.isEmpty
                                ? null
                                : (knownTypes.contains(slug) ||
                                        slug == '__new__'
                                    ? slug
                                    : null),
                            isExpanded: true,
                            isDense: true,
                            decoration: dense('Tipo de serviço associado *'),
                            items: [
                              for (final t in knownTypes)
                                DropdownMenuItem(
                                    value: t,
                                    enabled: !usedTypes.contains(t),
                                    child: Text(
                                        usedTypes.contains(t)
                                            ? '$t (já tem ficha)'
                                            : t,
                                        style: TextStyle(
                                            color: usedTypes.contains(t)
                                                ? _muted
                                                : _ink))),
                              const DropdownMenuItem(
                                  value: '__new__',
                                  child: Text('+ Novo tipo de serviço…')),
                            ],
                            onChanged: saving
                                ? null
                                : (v) => update(() => slug = v ?? '')),
                        if (slug == '__new__')
                          Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: TextField(
                                  controller: newType,
                                  onChanged: (_) => update(() {}),
                                  decoration: dense('Nome do novo tipo',
                                      helper: newType.text.isEmpty
                                          ? null
                                          : 'Identificador: ${_slugify(newType.text)}'))),
                        const SizedBox(height: 10),
                        TextField(
                            controller: description,
                            decoration: dense('Descrição')),
                        const SizedBox(height: 10),
                        TextField(
                            controller: nameFields,
                            decoration: dense('Nome automático do serviço',
                                helper:
                                    'Chaves separadas por vírgulas, ex.: noivo,noiva')),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: active,
                            activeColor: _rose,
                            onChanged: (v) => update(() => active = v),
                            title: const Text('Ficha ativa')),
                      ]));

              final canvas = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFECE7E3))),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SERVIÇO (campos fixos)',
                                  style: TextStyle(
                                      color: _muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1)),
                              const SizedBox(height: 6),
                              Text(
                                  'Tipo · Nome · Data · Hora · Local · Cidade · Morada · Preços · Notas',
                                  style: TextStyle(
                                      color: _muted.withOpacity(0.8),
                                      fontSize: 12)),
                            ])),
                    for (var s = 0; s < sections.length; s++) sectionCard(s),
                  ]);

              return Dialog.fullscreen(
                  backgroundColor: const Color(0xFFFAF9F7),
                  child: Scaffold(
                    backgroundColor: const Color(0xFFFAF9F7),
                    appBar: AppBar(
                        backgroundColor: const Color(0xFFFAF9F7),
                        foregroundColor: _ink,
                        elevation: 0,
                        title: Text(existing == null
                            ? 'Nova ficha'
                            : 'Desenhar ficha · ${name.text}'),
                        leading: IconButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(dialogContext, false),
                            icon: const Icon(Icons.close)),
                        actions: [
                          if (id != null)
                            IconButton(
                                onPressed: saving ? null : remove,
                                tooltip: 'Apagar ficha',
                                icon: const Icon(Icons.delete_outline,
                                    color: Color(0xFFB3261E))),
                          Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: FilledButton.icon(
                                  onPressed: saving ? null : save,
                                  style: FilledButton.styleFrom(
                                      backgroundColor: _rose),
                                  icon: saving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Icon(Icons.save_outlined,
                                          size: 18),
                                  label: Text(saving
                                      ? 'A guardar e verificar…'
                                      : 'Guardar'))),
                        ]),
                    body: Column(children: [
                      if (formError != null)
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            color: const Color(0xFFFBEAEA),
                            child: Text(formError!,
                                style:
                                    const TextStyle(color: Color(0xFFB3261E)))),
                      Expanded(
                          child: LayoutBuilder(
                              builder: (context, constraints) => constraints
                                          .maxWidth >=
                                      1000
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                          SizedBox(
                                              width: 300,
                                              child: ListView(
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  children: [
                                                    settingsCard(),
                                                    const SizedBox(height: 12),
                                                    palette()
                                                  ])),
                                          Expanded(
                                              child: ListView(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          4, 16, 4, 40),
                                                  children: [canvas])),
                                          SizedBox(
                                              width: 320,
                                              child: ListView(
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  children: [properties()])),
                                        ])
                                  : ListView(
                                      padding: const EdgeInsets.all(16),
                                      children: [
                                          settingsCard(),
                                          const SizedBox(height: 12),
                                          palette(),
                                          const SizedBox(height: 12),
                                          if (selected != null) ...[
                                            properties(),
                                            const SizedBox(height: 12)
                                          ],
                                          canvas,
                                        ]))),
                    ]),
                  ));
            }));
    for (final c in [name, description, newType, nameFields]) {
      c.dispose();
    }
    for (final group in ctrl.values) {
      for (final c in group.values) {
        c.dispose();
      }
    }
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ficha guardada e confirmada no servidor.')));
      _loadTemplates();
    }
  }

  Widget _management() {
    final kind = _manageKind;
    final isEvents = kind == 'Serviços';
    final rows = isEvents ? _events : _manageRows;
    final query = _manageSearch.trim().toLowerCase();
    final visible = rows
        .where((row) =>
            query.isEmpty || jsonEncode(row).toLowerCase().contains(query))
        .toList();
    final canCreate = _can(isEvents
        ? 'events.create'
        : kind == 'Clientes'
            ? 'clients.create'
            : 'users.create');
    final canEdit =
        _can(kind == 'Clientes' ? 'clients.update' : 'users.update');
    final canDelete =
        _can(kind == 'Clientes' ? 'clients.delete' : 'users.delete');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Pessoas',
          style: TextStyle(
              color: _ink, fontSize: 20, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      const Text(
          'Equipa (fotógrafos, backoffice, receção, administradores) e clientes.',
          style: TextStyle(color: _muted)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (_can('users.list'))
          ChoiceChip(
              avatar: const Icon(Icons.badge_outlined, size: 18),
              label: const Text('Equipa'),
              selected: kind == 'Utilizadores',
              onSelected: (_) {
                _manageSearch = '';
                _loadManaged('Utilizadores');
              }),
        if (_can('clients.list'))
          ChoiceChip(
              avatar: const Icon(Icons.person_outline, size: 18),
              label: const Text('Clientes'),
              selected: kind == 'Clientes',
              onSelected: (_) {
                _manageSearch = '';
                _loadManaged('Clientes');
              }),
      ]),
      const SizedBox(height: 12),
      TextField(
          key: ValueKey('manage-$kind'),
          decoration: InputDecoration(
              labelText: kind == 'Utilizadores'
                  ? 'Pesquisar na equipa'
                  : 'Pesquisar $kind',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder()),
          onChanged: (v) => setState(() => _manageSearch = v)),
      const SizedBox(height: 12),
      if (canCreate)
        Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
                onPressed: isEvents
                    ? () => context.pushNamed('Studio59ServiceOnline',
                            queryParameters: {
                              'eventId': serializeParam(0, ParamType.int)
                            })
                    : () => _saveManaged(kind, null),
                icon: const Icon(Icons.add),
                label: Text(isEvents
                    ? 'Adicionar serviço'
                    : 'Adicionar ${kind == 'Clientes' ? 'cliente' : 'pessoa à equipa'}'))),
      if (_manageLoading && !isEvents)
        const Center(child: CircularProgressIndicator(color: _rose)),
      if (_manageError != null && !isEvents)
        _card(Text(_manageError!, style: const TextStyle(color: _ink))),
      if (!_manageLoading && visible.isEmpty)
        _card(const Text('Sem resultados.', style: TextStyle(color: _muted))),
      const SizedBox(height: 10),
      for (final row in visible.take(isEvents ? 100 : 50)) ...[
        if (isEvents)
          _eventRow(row)
        else
          _card(Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Flexible(
                        child: Text('${row['name'] ?? ''}',
                            style: TextStyle(
                                color:
                                    row['is_active'] == false ? _muted : _ink,
                                fontWeight: FontWeight.w600))),
                    if (kind == 'Utilizadores' && row['is_active'] == false)
                      Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF1E4E4),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Text('Inativo',
                              style: TextStyle(
                                  color: Color(0xFF9B3D3D),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700))),
                  ]),
                  Text(
                      [
                        if (kind == 'Utilizadores')
                          _roleLabel('${row['role'] ?? ''}'),
                        '${row['email'] ?? row['phone'] ?? ''}'
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: const TextStyle(color: _muted)),
                ])),
            if (kind == 'Utilizadores' &&
                canEdit &&
                '${row['id']}' != '${_user['id']}')
              Tooltip(
                  message: row['is_active'] == false ? 'Ativar' : 'Inativar',
                  child: Switch(
                      value: row['is_active'] != false,
                      activeColor: _rose,
                      onChanged: (v) => _setUserActive(row, v))),
            if (canEdit)
              IconButton(
                  onPressed: () => _saveManaged(kind, row),
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit, color: _ink)),
            if (canDelete)
              IconButton(
                  onPressed: () => _deleteManaged(kind, row),
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline, color: _ink)),
          ])),
        const SizedBox(height: 9),
      ],
      if (isEvents && visible.length > 100)
        const Text(
            'Mostram-se os primeiros 100 serviços. Use a pesquisa para encontrar outro.',
            style: TextStyle(color: _muted)),
      if (!isEvents)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              onPressed: _managePage > 1
                  ? () => _loadManaged(kind, _managePage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left)),
          Text('$_managePage / $_manageLastPage',
              style: const TextStyle(color: _ink)),
          IconButton(
              onPressed: _managePage < _manageLastPage
                  ? () => _loadManaged(kind, _managePage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right)),
        ]),
    ]);
  }

  int? _eurosToCents(dynamic amount) {
    final match =
        RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch('${amount ?? ''}'.trim());
    if (match == null) return null;
    final euros = int.tryParse(match.group(1)!);
    final cents = int.tryParse((match.group(2) ?? '0').padRight(2, '0'));
    return euros == null || cents == null ? null : euros * 100 + cents;
  }

  String _money(int cents) =>
      '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')} €';

  int? _finYear;
  int? _finMonth;
  int? _finDay;
  int? _finEventId;
  String _finFilter = 'Todos';
  final Map<int, List<Map<String, dynamic>>> _rosters = {};
  final Set<int> _rosterLoading = {};
  final Map<int, String> _rosterErrors = {};

  int? _orderEventKey(Map<String, dynamic> order) =>
      int.tryParse('${order['event_id'] ?? _object(order['event'])['id']}');

  Map<String, dynamic> _eventOf(Map<String, dynamic> order) {
    final id = _orderEventKey(order);
    return _events.where((e) => int.tryParse('${e['id']}') == id).firstOrNull ??
        _object(order['event']);
  }

  int _c(dynamic value) => _eurosToCents(value) ?? 0;

  String _payState(Map<String, dynamic> order) {
    final status = '${order['status']}';
    if (status == 'cancelled') return 'Cancelado';
    if (_c(order['cash_due_amount']) > 0) return 'Deve';
    if (_c(order['cash_change_amount']) > 0 &&
        order['cash_change_given'] != true) return 'Troco';
    if (status == 'paid' || status == 'delivered') return 'Pago';
    return 'Por atender';
  }

  Color _stateColor(String state) =>
      const {
        'Deve': Color(0xFFB3261E),
        'Troco': Color(0xFFB26A00),
        'Pago': Color(0xFF2E7D32),
        'Cancelado': Color(0xFF6D625F),
      }[state] ??
      const Color(0xFF5C6BC0);

  Map<String, int> _finSums(Iterable<Map<String, dynamic>> orders) {
    final sums = <String, int>{
      'orders': 0,
      'items': 0,
      'extras': 0,
      'shipping': 0,
      'total': 0,
      'received': 0,
      'changeGiven': 0,
      'changeOwed': 0,
      'due': 0,
      'Pago': 0,
      'Deve': 0,
      'Troco': 0,
      'Por atender': 0,
      'commissionBase': 0
    };
    for (final order in orders) {
      final state = _payState(order);
      if (state == 'Cancelado') continue;
      sums['orders'] = sums['orders']! + 1;
      sums[state] = (sums[state] ?? 0) + 1;
      // Extras = total − fotografias − envio, para as parcelas somarem sempre o total
      // (o servidor inclui o envio dentro de extras_total).
      final orderItems = _c(order['items_total']);
      final orderShipping = _c(order['shipping_fee']);
      final orderTotal = _c(order['total_amount']);
      final derivedExtras = orderTotal - orderItems - orderShipping;
      sums['items'] = sums['items']! + orderItems;
      sums['extras'] = sums['extras']! +
          (derivedExtras >= 0
              ? derivedExtras
              : _c(order['extras_total'] ?? order['film_fee']));
      sums['shipping'] = sums['shipping']! + orderShipping;
      sums['total'] = sums['total']! + orderTotal;
      sums['received'] = sums['received']! + _c(order['cash_received_amount']);
      final change = _c(order['cash_change_amount']);
      if (order['cash_change_given'] == true) {
        sums['changeGiven'] = sums['changeGiven']! + change;
      } else {
        sums['changeOwed'] = sums['changeOwed']! + change;
      }
      sums['due'] = sums['due']! + _c(order['cash_due_amount']);
      sums['commissionBase'] =
          sums['commissionBase']! + _c(order['total_amount']);
    }
    return sums;
  }

  /// Equipa do evento; aceita {data:[...]}, {data:{data:[...]}} ou uma lista simples.
  Future<List<Map<String, dynamic>>> _fetchRoster(
      http.Client client, int eventId) async {
    final response = await client.get(Uri.parse('$_base/events/$eventId/staff'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token'
        }).timeout(const Duration(seconds: 20));
    if (response.statusCode == 401)
      throw StateError('A sessão expirou. Inicie sessão novamente.');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'Não foi possível carregar a equipa (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    final list = decoded is List
        ? decoded
        : decoded is Map
            ? (decoded['data'] is List
                ? decoded['data']
                : decoded['data'] is Map
                    ? decoded['data']['data']
                    : null)
            : null;
    if (list is! List)
      throw StateError('Resposta inesperada da equipa do evento.');
    return list
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _loadRoster(int eventId) async {
    if (_rosters.containsKey(eventId) || _rosterLoading.contains(eventId))
      return;
    setState(() {
      _rosterLoading.add(eventId);
      _rosterErrors.remove(eventId);
    });
    final client = http.Client();
    try {
      final rows = await _fetchRoster(client, eventId);
      final photographers = rows.where((member) {
        final person = _object(member['user']);
        final status = '${member['status'] ?? ''}'.toLowerCase();
        return '${person['role'] ?? member['role']}'.toLowerCase() ==
                'photographer' &&
            !const {
              'declined',
              'rejected',
              'removed',
              'cancelled',
              'canceled',
              'inactive'
            }.contains(status);
      }).toList();
      if (mounted) setState(() => _rosters[eventId] = photographers);
    } catch (error) {
      if (mounted)
        setState(() => _rosterErrors[eventId] = error is StateError
            ? error.message.toString()
            : 'Não foi possível carregar a equipa ($error).');
    } finally {
      client.close();
      if (mounted) setState(() => _rosterLoading.remove(eventId));
    }
  }

  Widget _finColumn(String title, List<(int, String, String, int)> items,
          int? selected, ValueChanged<int> onTap) =>
      Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFECE7E3))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Text(title,
                  style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700))),
          SizedBox(
              height: 230,
              child: items.isEmpty
                  ? const Center(
                      child: Text('—', style: TextStyle(color: _muted)))
                  : ListView(children: [
                      for (final item in items)
                        Material(
                            color: item.$1 == selected
                                ? _rose
                                : Colors.transparent,
                            child: InkWell(
                                onTap: () => onTap(item.$1),
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 9),
                                    child: Row(children: [
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(item.$2,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color: item.$1 == selected
                                                        ? Colors.white
                                                        : _ink,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            Text(item.$3,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color: item.$1 == selected
                                                        ? Colors.white70
                                                        : _muted,
                                                    fontSize: 11)),
                                          ])),
                                      if (item.$4 > 0)
                                        Container(
                                            margin:
                                                const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: item.$1 == selected
                                                    ? Colors.white
                                                    : const Color(0xFFFBEAEA),
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            child: Text('${item.$4} deve',
                                                style: const TextStyle(
                                                    color: Color(0xFFB3261E),
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w700))),
                                      Icon(Icons.chevron_right,
                                          size: 18,
                                          color: item.$1 == selected
                                              ? Colors.white
                                              : _muted),
                                    ]))))
                    ])),
        ]),
      );

  Widget _finStat(String label, String value, {Color? color, String? detail}) =>
      Container(
        width: 158,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: color ?? Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFECE7E3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: const TextStyle(
                  color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
          if (detail != null)
            Text(detail, style: const TextStyle(color: _muted, fontSize: 10)),
        ]),
      );

  // Índice financeiro: calculado uma vez por carregamento de dados, não a cada toque.
  Object? _finIndexKey;
  Map<int, Map<String, dynamic>> _finEventById = {};
  Map<int, List<Map<String, dynamic>>> _finOrders = {};
  Map<String, Map<String, int>> _finAgg = {};
  Map<String, List<int>> _finChildren = {};

  void _buildFinIndex() {
    final key = (
      identityHashCode(_events),
      identityHashCode(_orders),
      _events.length,
      _orders.length
    );
    if (_finIndexKey == key) return;
    _finIndexKey = key;
    final byId = <int, Map<String, dynamic>>{};
    for (final e in _events) {
      final id = int.tryParse('${e['id']}');
      if (id != null) byId[id] = e;
    }
    final orders = <int, List<Map<String, dynamic>>>{};
    for (final o in _orders) {
      final id = _orderEventKey(o);
      if (id == null) continue;
      orders.putIfAbsent(id, () => []).add(o);
      if (!byId.containsKey(id)) {
        final ev = _object(o['event']);
        if (ev.isNotEmpty) byId[id] = {...ev, 'id': id};
      }
    }
    final agg = <String, Map<String, int>>{};
    final children = <String, Set<int>>{};
    final eventById = <int, Map<String, dynamic>>{};
    byId.forEach((id, e) {
      final d = _eventDate(e);
      if (d == null) return;
      eventById[id] = e;
      final sums = _finSums(orders[id] ?? const []);
      final services = _c(e['base_price']);
      for (final k in [
        '${d.year}',
        '${d.year}-${d.month}',
        '${d.year}-${d.month}-${d.day}',
        'e:$id'
      ]) {
        final t = agg.putIfAbsent(k, () => {'events': 0, 'servicesValue': 0});
        sums.forEach((name, v) => t[name] = (t[name] ?? 0) + v);
        t['events'] = t['events']! + 1;
        t['servicesValue'] = t['servicesValue']! + services;
      }
      children.putIfAbsent('', () => {}).add(d.year);
      children.putIfAbsent('${d.year}', () => {}).add(d.month);
      children.putIfAbsent('${d.year}-${d.month}', () => {}).add(d.day);
      children.putIfAbsent('${d.year}-${d.month}-${d.day}', () => {}).add(id);
    });
    _finEventById = eventById;
    _finOrders = orders;
    _finAgg = agg;
    _finChildren = {
      for (final e in children.entries) e.key: e.value.toList()..sort()
    };
  }

  Widget _financial() {
    if (!_ordersComplete)
      return _card(const Text(
          'Não foi possível carregar todos os pedidos. Atualize para consultar valores completos.',
          style: TextStyle(color: _ink)));
    _buildFinIndex();
    Map<String, int> agg(String key) => {
          ..._finSums(const []),
          'events': 0,
          'servicesValue': 0,
          ...?_finAgg[key]
        };
    (int, String, String, int) entry(int key, String label, String aggKey) {
      final s = agg(aggKey);
      final services = s['servicesValue']!;
      return (
        key,
        label,
        '${s['events']} serv. · fotos ${_money(s['total']!)}${services > 0 ? ' · serv. ${_money(services)}' : ''}',
        s['Deve']!
      );
    }

    final years = [...?_finChildren['']]..sort((a, b) => b.compareTo(a));
    final year = _finYear ??
        (years.contains(DateTime.now().year)
            ? DateTime.now().year
            : years.firstOrNull);
    final months = _finChildren['$year'] ?? const <int>[];
    final days = _finChildren['$year-$_finMonth'] ?? const <int>[];
    final serviceIds = [...?_finChildren['$year-$_finMonth-$_finDay']]..sort(
        (a, b) => '${_finEventById[a]?['name']}'
            .compareTo('${_finEventById[b]?['name']}'));
    final columns = [
      _finColumn(
          'ANO',
          [for (final y in years) entry(y, '$y', '$y')],
          year,
          (v) => setState(() {
                _finYear = v;
                _finMonth = null;
                _finDay = null;
                _finEventId = null;
              })),
      _finColumn(
          'MÊS',
          [for (final m in months) entry(m, _months[m - 1], '$year-$m')],
          _finMonth,
          (v) => setState(() {
                _finMonth = v;
                _finDay = null;
                _finEventId = null;
              })),
      _finColumn(
          'DIA',
          [for (final d in days) entry(d, '$d', '$year-$_finMonth-$d')],
          _finDay,
          (v) => setState(() {
                _finDay = v;
                _finEventId = null;
              })),
      _finColumn(
          'EVENTO',
          [
            for (final id in serviceIds)
              entry(id, '${_finEventById[id]?['name'] ?? 'Serviço'}', 'e:$id')
          ],
          _finEventId, (v) {
        setState(() {
          _finEventId = v;
          _finFilter = 'Todos';
        });
        _loadRoster(v);
      }),
    ];
    final scopeKey = _finEventId != null
        ? 'e:$_finEventId'
        : _finDay != null
            ? '$year-$_finMonth-$_finDay'
            : _finMonth != null
                ? '$year-$_finMonth'
                : '$year';
    final scopeLabel = _finEventId != null
        ? '${_finEventById[_finEventId]?['name'] ?? 'Serviço'}'
        : _finDay != null
            ? '$_finDay ${_months[_finMonth! - 1]} $year'
            : _finMonth != null
                ? '${_months[_finMonth! - 1]} $year'
                : '${year ?? ''}';
    final sums = agg(scopeKey);
    final servicesValue = sums['servicesValue']!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Financeiro',
          style: TextStyle(
              color: _ink, fontSize: 20, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      const Text(
          'Navegue por Ano › Mês › Dia › Evento. Datas pelo dia do serviço.',
          style: TextStyle(color: _muted)),
      const SizedBox(height: 14),
      if (years.isEmpty)
        _card(const Text('Sem serviços com data.',
            style: TextStyle(color: _muted)))
      else
        LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth >= 760
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (var i = 0; i < columns.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: columns[i])
                    ],
                  ])
                : Column(children: [
                    for (final c in columns)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 8), child: c)
                  ])),
      const SizedBox(height: 18),
      Text('Resumo · $scopeLabel',
          style: const TextStyle(
              color: _ink, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (servicesValue > 0)
          _finStat('Valor dos serviços', _money(servicesValue),
              detail: '${sums['events']} serviços'),
        _finStat('Fotografias', _money(sums['items']!)),
        _finStat('Extras (filme)', _money(sums['extras']!)),
        _finStat('Envios', _money(sums['shipping']!)),
        _finStat('Total vendido', _money(sums['total']!),
            color: const Color(0xFFF2E5E3),
            detail: '${sums['orders']} pedidos'),
        _finStat('Recebido', _money(sums['received']! - sums['changeGiven']!),
            detail: 'líquido de trocos entregues'),
        _finStat('Pagos', '${sums['Pago']}', color: const Color(0xFFE8F5E9)),
        _finStat('Devem', '${sums['Deve']} · ${_money(sums['due']!)}',
            color: const Color(0xFFFBEAEA)),
        _finStat('Troco a devolver',
            '${sums['Troco']} · ${_money(sums['changeOwed']!)}',
            color: const Color(0xFFFFF3E0)),
        _finStat('Por atender', '${sums['Por atender']}'),
      ]),
      if (_finEventId != null)
        ..._finEventDetail(_finEventId!, _finEventById[_finEventId] ?? {},
            _finOrders[_finEventId] ?? const [], sums),
    ]);
  }

  bool get _canSeeEventFinance => _isAdminRole || _roleName == 'backoffice';

  List<(String, String)> _calcLines(Map<String, int> sums) => [
        ('Fotografias vendidas', _money(sums['items']!)),
        ('+ Extras (filme)', _money(sums['extras']!)),
        ('+ Envios', _money(sums['shipping']!)),
        ('= Total vendido', _money(sums['total']!)),
        ('Recebido em caixa', _money(sums['received']!)),
        ('− Troco entregue', _money(sums['changeGiven']!)),
        ('− Troco ainda a devolver ao cliente', _money(sums['changeOwed']!)),
        ('Em dívida pelos clientes', _money(sums['due']!)),
        (
          'Saldo de caixa (recebido − trocos)',
          _money(sums['received']! - sums['changeGiven']! - sums['changeOwed']!)
        ),
      ];

  /// Resumo de vendas, cálculo detalhado e comissões de um evento (Financeiro e Pedidos).
  Widget _eventCalcCard(int eventId, Map<String, dynamic> event,
      List<Map<String, dynamic>> orders, Map<String, int> sums) {
    final roster = _rosters[eventId];
    final base = sums['commissionBase']!;
    final pool = (base * 15) ~/ 100;
    final count = roster?.length ?? 0;
    final each = count == 0 ? 0 : (base * 15) ~/ (100 * count);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (_c(event['base_price']) > 0)
          _finStat('Valor do serviço', _money(_c(event['base_price']))),
        _finStat('Total vendido', _money(sums['total']!),
            color: const Color(0xFFF2E5E3),
            detail: '${sums['orders']} pedidos'),
        _finStat('Recebido', _money(sums['received']! - sums['changeGiven']!),
            detail: 'líquido de trocos entregues'),
        _finStat('Pagos', '${sums['Pago']}', color: const Color(0xFFE8F5E9)),
        _finStat('Devem', '${sums['Deve']} · ${_money(sums['due']!)}',
            color: const Color(0xFFFBEAEA)),
        _finStat('Troco a devolver',
            '${sums['Troco']} · ${_money(sums['changeOwed']!)}',
            color: const Color(0xFFFFF3E0)),
        _finStat('Comissões (15%)', _money(pool),
            detail: count == 0
                ? 'sem fotógrafos'
                : '$count fotógrafo${count == 1 ? '' : 's'}'),
      ]),
      const SizedBox(height: 12),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
              child: Text('Cálculo detalhado',
                  style: TextStyle(
                      color: _ink, fontSize: 17, fontWeight: FontWeight.w700))),
          FilledButton.icon(
              onPressed: () => _exportEventPdf(eventId, event, orders, sums),
              style: FilledButton.styleFrom(backgroundColor: _rose),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Exportar PDF')),
        ]),
        const SizedBox(height: 10),
        for (final line in _calcLines(sums))
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(
                    child: Text(line.$1,
                        style: TextStyle(
                            color: line.$1.startsWith('=') ||
                                    line.$1.startsWith('Saldo')
                                ? _ink
                                : _muted,
                            fontWeight: line.$1.startsWith('=') ||
                                    line.$1.startsWith('Saldo')
                                ? FontWeight.w700
                                : FontWeight.w400))),
                Text(line.$2,
                    style: const TextStyle(
                        color: _ink, fontWeight: FontWeight.w600)),
              ])),
        const Divider(height: 24),
        const Text('Comissões',
            style: TextStyle(
                color: _ink, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
            'Base: total vendido (fotografias + extras + envios) = ${_money(base)}',
            style: const TextStyle(color: _muted)),
        Text('15% de ${_money(base)} = ${_money(pool)}',
            style: const TextStyle(color: _muted)),
        if (_rosterLoading.contains(eventId))
          const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(color: _rose))
        else if (_rosterErrors[eventId] != null)
          Text(_rosterErrors[eventId]!,
              style: const TextStyle(color: Color(0xFFB3261E)))
        else if (roster == null)
          TextButton(
              onPressed: () => _loadRoster(eventId),
              child: const Text('Carregar equipa'))
        else if (count == 0)
          const Text(
              'Sem fotógrafos atribuídos a este serviço: a comissão não é distribuída.',
              style: TextStyle(color: Color(0xFFB3261E)))
        else ...[
          Text(
              '${_money(pool)} ÷ $count fotógrafo${count == 1 ? '' : 's'} = ${_money(each)} cada',
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (final member in roster)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  const Icon(Icons.person_outline, size: 18, color: _muted),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(
                          '${_object(member['user'])['name'] ?? member['name'] ?? 'Fotógrafo'}',
                          style: const TextStyle(color: _ink))),
                  Text(_money(each),
                      style: const TextStyle(
                          color: _ink, fontWeight: FontWeight.w700)),
                ])),
        ],
      ])),
    ]);
  }

  /// Tema do PDF com fonte que suporta acentos e €: Roboto (Google Fonts, em cache) ou Arial do sistema.
  Future<(pw.ThemeData, bool)> _pdfTheme() async {
    try {
      return (
        pw.ThemeData.withFont(
            base: await PdfGoogleFonts.robotoRegular(),
            bold: await PdfGoogleFonts.robotoBold()),
        true
      );
    } catch (_) {}
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
      final pairs = Platform.isWindows
          ? [
              [r'C:\Windows\Fonts\arial.ttf', r'C:\Windows\Fonts\arialbd.ttf'],
              [
                r'C:\Windows\Fonts\segoeui.ttf',
                r'C:\Windows\Fonts\segoeuib.ttf'
              ]
            ]
          : [
              [
                '/System/Library/Fonts/Supplemental/Arial.ttf',
                '/System/Library/Fonts/Supplemental/Arial Bold.ttf'
              ],
              ['/Library/Fonts/Arial.ttf', '/Library/Fonts/Arial Bold.ttf']
            ];
      for (final pair in pairs) {
        try {
          final regular = File(pair[0]);
          final bold = File(pair[1]);
          if (!await regular.exists()) continue;
          final r = await regular.readAsBytes();
          final b = await bold.exists() ? await bold.readAsBytes() : r;
          return (
            pw.ThemeData.withFont(
                base: pw.Font.ttf(ByteData.sublistView(r)),
                bold: pw.Font.ttf(ByteData.sublistView(b))),
            true
          );
        } catch (_) {}
      }
    }
    return (pw.ThemeData(), false);
  }

  Future<void> _exportEventPdf(int eventId, Map<String, dynamic> event,
      List<Map<String, dynamic>> orders, Map<String, int> sums) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('A gerar o PDF…'), duration: Duration(seconds: 2)));
    try {
      if (!_rosters.containsKey(eventId)) await _loadRoster(eventId);
      final (theme, unicode) = await _pdfTheme();
      String t(String value) => unicode
          ? value
          : value
              .replaceAll('€', 'EUR')
              .replaceAll('−', '-')
              .replaceAll('÷', '/')
              .replaceAll('·', '-');
      final roster = _rosters[eventId] ?? const <Map<String, dynamic>>[];
      final base = sums['commissionBase']!;
      final pool = (base * 15) ~/ 100;
      final each = roster.isEmpty ? 0 : (base * 15) ~/ (100 * roster.length);
      final now = DateTime.now();
      final sorted = [...orders]
        ..sort((a, b) => '${a['order_code']}'.compareTo('${b['order_code']}'));
      const rose = PdfColor.fromInt(0xFFB77F84);
      const roseSoft = PdfColor.fromInt(0xFFF2E5E3);
      const ink = PdfColor.fromInt(0xFF292624);
      const muted = PdfColor.fromInt(0xFF6D625F);
      final date = _eventDate(event);
      final doc = pw.Document(
          theme: theme,
          title: t('Relatório · ${event['name'] ?? 'Serviço'}'),
          author: 'Studio 59');
      pw.Widget line(String label, String value, {bool strong = false}) =>
          pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(children: [
                pw.Expanded(
                    child: pw.Text(t(label),
                        style: pw.TextStyle(
                            color: strong ? ink : muted,
                            fontWeight: strong
                                ? pw.FontWeight.bold
                                : pw.FontWeight.normal,
                            fontSize: 10))),
                pw.Text(t(value),
                    style: pw.TextStyle(
                        color: ink,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10)),
              ]));
      pw.Widget box(String title, List<pw.Widget> children) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: roseSoft),
              borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                    color: roseSoft,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    child: pw.Text(t(title.toUpperCase()),
                        style: pw.TextStyle(
                            color: rose,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                            letterSpacing: 1))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: children)),
              ]));
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Row(children: [
              pw.Text('Studio 59',
                  style: pw.TextStyle(
                      color: rose,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14)),
              pw.Spacer(),
              pw.Text(t('Relatório de vendas'),
                  style: const pw.TextStyle(color: muted, fontSize: 9)),
            ])),
        footer: (context) => pw.Row(children: [
          pw.Text(
              t('Gerado a ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} às ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} por ${_user['name'] ?? _user['username'] ?? ''}'),
              style: const pw.TextStyle(color: muted, fontSize: 8)),
          pw.Spacer(),
          pw.Text(t('Página ${context.pageNumber} de ${context.pagesCount}'),
              style: const pw.TextStyle(color: muted, fontSize: 8)),
        ]),
        build: (context) => [
          pw.Text(t('${event['name'] ?? 'Serviço'}'),
              style: pw.TextStyle(
                  color: ink, fontWeight: pw.FontWeight.bold, fontSize: 18)),
          pw.SizedBox(height: 4),
          pw.Text(
              t([
                if (date != null)
                  '${date.day} ${_months[date.month - 1]} ${date.year}',
                if ('${event['event_time'] ?? ''}'.isNotEmpty)
                  '${event['event_time']}',
                if ('${event['location'] ?? ''}'.isNotEmpty)
                  '${event['location']}',
                if (_c(event['base_price']) > 0)
                  'valor do serviço ${_money(_c(event['base_price']))}',
              ].join(' · ')),
              style: const pw.TextStyle(color: muted, fontSize: 10)),
          pw.SizedBox(height: 14),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
                child: box('Cálculo detalhado', [
              for (final l in _calcLines(sums))
                line(l.$1, l.$2,
                    strong: l.$1.startsWith('=') || l.$1.startsWith('Saldo')),
              pw.SizedBox(height: 6),
              line('Pedidos', '${sums['orders']}'),
              line('Pagos · Devem · Troco · Por atender',
                  '${sums['Pago']} · ${sums['Deve']} · ${sums['Troco']} · ${sums['Por atender']}'),
            ])),
            pw.SizedBox(width: 12),
            pw.Expanded(
                child: box('Comissões', [
              line('Base (total vendido)', _money(base)),
              line('15% da base', _money(pool), strong: true),
              line('Fotógrafos atribuídos', '${roster.length}'),
              if (roster.isNotEmpty)
                line('Por fotógrafo', _money(each), strong: true),
              pw.SizedBox(height: 6),
              for (final m in roster)
                line(
                    '${_object(m['user'])['name'] ?? m['name'] ?? 'Fotógrafo'}',
                    _money(each)),
              if (roster.isEmpty)
                pw.Text(t('Sem fotógrafos atribuídos.'),
                    style: const pw.TextStyle(color: muted, fontSize: 9)),
            ])),
          ]),
          box('Pedidos (${sorted.length})', [
            pw.TableHelper.fromTextArray(
              headers: [
                t('Código'),
                'Cliente',
                'Estado',
                'Total',
                'Recebido',
                'Troco',
                t('Em dívida')
              ],
              data: [
                for (final o in sorted)
                  [
                    '${o['order_code'] ?? ''}',
                    t('${o['customer_name'] ?? ''}'),
                    t(_payState(o)),
                    t(_money(_c(o['total_amount']))),
                    t(_money(_c(o['cash_received_amount']))),
                    t(_c(o['cash_change_amount']) == 0
                        ? '-'
                        : '${_money(_c(o['cash_change_amount']))}${o['cash_change_given'] == true ? '' : ' *'}'),
                    t(_c(o['cash_due_amount']) == 0
                        ? '-'
                        : _money(_c(o['cash_due_amount']))),
                  ]
              ],
              headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: rose),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              border: pw.TableBorder.symmetric(
                  inside: const pw.BorderSide(color: roseSoft, width: 0.5),
                  outside: const pw.BorderSide(color: roseSoft, width: 0.8)),
              oddRowDecoration:
                  const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFAF9F7)),
              cellAlignments: {
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight
              },
            ),
            pw.SizedBox(height: 4),
            pw.Text(t('* troco ainda por entregar ao cliente'),
                style: const pw.TextStyle(color: muted, fontSize: 8)),
          ]),
        ],
      ));
      final bytes = await doc.save();
      final fileName =
          '${_safeName('${event['name'] ?? 'evento_$eventId'}')}_relatorio.pdf';
      final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar relatório PDF',
          fileName: fileName,
          bytes: bytes);
      if (path == null) return;
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux))
        await File(path).writeAsBytes(bytes, flush: true);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF guardado: $fileName')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível gerar o PDF ($error).')));
    }
  }

  List<Widget> _finEventDetail(int eventId, Map<String, dynamic> event,
      List<Map<String, dynamic>> orders, Map<String, int> sums) {
    final filtered = orders
        .where((o) => _finFilter == 'Todos' || _payState(o) == _finFilter)
        .toList()
      ..sort((a, b) =>
          '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}'));
    return [
      const SizedBox(height: 18),
      _eventCalcCard(eventId, event, orders, sums),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final f in const ['Todos', 'Pago', 'Deve', 'Troco', 'Por atender'])
          ChoiceChip(
              label: Text(f == 'Todos'
                  ? 'Todos (${orders.length})'
                  : '$f (${sums[f] ?? 0})'),
              selected: _finFilter == f,
              selectedColor: const Color(0xFFF2E5E3),
              onSelected: (_) => setState(() => _finFilter = f)),
      ]),
      const SizedBox(height: 10),
      if (filtered.isEmpty)
        _card(const Text('Sem pedidos neste filtro.',
            style: TextStyle(color: _muted))),
      for (final order in filtered)
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _openOrder(order),
              borderRadius: BorderRadius.circular(16),
              child: _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              '${order['order_code'] ?? 'Pedido'} · ${order['customer_name'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _ink, fontWeight: FontWeight.w600))),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: _stateColor(_payState(order))
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(_payState(order),
                              style: TextStyle(
                                  color: _stateColor(_payState(order)),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12))),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                        [
                          'Total ${_money(_c(order['total_amount']))}',
                          if (order['cash_received_amount'] != null)
                            'recebido ${_money(_c(order['cash_received_amount']))}',
                          if (_c(order['cash_change_amount']) > 0)
                            'troco ${_money(_c(order['cash_change_amount']))}${order['cash_change_given'] == true ? ' entregue' : ' por entregar'}',
                          if (_c(order['cash_due_amount']) > 0)
                            'deve ${_money(_c(order['cash_due_amount']))}',
                        ].join(' · '),
                        style: const TextStyle(color: _muted, fontSize: 12)),
                  ])),
            )),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(child: CircularProgressIndicator(color: _rose));
    if (_error != null)
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _ink)),
                const SizedBox(height: 12),
                if (_expired)
                  ElevatedButton(
                      onPressed: () => context.goNamed('TeamOperationsOnline'),
                      child: const Text('Iniciar sessão'))
                else
                  ElevatedButton(
                      onPressed: _load, child: const Text('Tentar novamente')),
              ])));
    final tabs = <String>[
      'Início',
      if (_can('events.list') || _can('events.view')) 'Agenda',
      if (_can('events.list') && !_offline) 'Serviços',
      if (_can('orders.list')) 'Pedidos',
      if (_can('users.list') || _can('clients.list')) 'Pessoas',
      if ((_user['role'] ?? '').toString().toLowerCase() == 'admin')
        'Financeiro',
      if (_isAdminRole && !_offline) 'Configurações'
    ];
    final tabIcons = <String, IconData>{
      'Início': Icons.home_outlined,
      'Agenda': Icons.calendar_month_outlined,
      'Pedidos': Icons.receipt_long_outlined,
      'Serviços': Icons.event_note_outlined,
      'Pessoas': Icons.people_alt_outlined,
      'Financeiro': Icons.bar_chart_outlined,
      'Configurações': Icons.settings_outlined
    };
    return SizedBox(
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        child: ColoredBox(
            color: const Color(0xFFFAF9F7),
            child: SafeArea(
                child: Column(children: [
              Expanded(
                  child: SingleChildScrollView(
                      child: Center(
                          child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(
                                    _offline ? 'Sessão offline' : 'Studio 59',
                                    style: const TextStyle(
                                        color: _ink,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700))),
                            if (_canSchedule)
                              IconButton(
                                  onPressed: () => _schedule(_tab == 'Agenda'
                                      ? _selected
                                      : DateTime.now()),
                                  tooltip: 'Agendar serviço',
                                  icon: const Icon(Icons.add_circle,
                                      color: _rose, size: 30)),
                            if (!_offline)
                              IconButton(
                                  onPressed: () =>
                                      context.pushNamed('Studio59SyncOnline'),
                                  tooltip: 'Sincronizar sessão offline',
                                  icon: const Icon(Icons.cloud_sync_outlined,
                                      color: _ink)),
                            IconButton(
                                onPressed: _load,
                                tooltip: 'Atualizar',
                                icon: const Icon(Icons.refresh, color: _ink)),
                            if (!_offline)
                              IconButton(
                                  onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => const Scaffold(
                                              backgroundColor:
                                                  Color(0xFFFAF9F7),
                                              body: SafeArea(
                                                  child:
                                                      Studio59StaffSettings())))),
                                  tooltip: 'Definições',
                                  icon: const Icon(Icons.settings_outlined,
                                      color: _ink)),
                            IconButton(
                                onPressed: _logout,
                                tooltip: 'Terminar sessão',
                                icon: const Icon(Icons.logout, color: _ink)),
                          ]),
                          const SizedBox(height: 18),
                          if (_tab == 'Início') _overview(),
                          if (_tab == 'Agenda') _agenda(),
                          if (_tab == 'Pedidos') _tickets(),
                          if (_tab == 'Serviços') _servicesTab(),
                          if (_tab == 'Pessoas') _management(),
                          if (_tab == 'Financeiro') _financial(),
                          if (_tab == 'Configurações') _settings(),
                        ])),
              )))),
              CupertinoTabBar(
                backgroundColor: Colors.white,
                activeColor: _rose,
                inactiveColor: _muted,
                currentIndex: tabs.indexOf(_tab).clamp(0, tabs.length - 1),
                onTap: (index) {
                  setState(() => _tab = tabs[index]);
                  if (tabs[index] == 'Pessoas' && _manageKind == 'Serviços')
                    _loadManaged(
                        _can('users.list') ? 'Utilizadores' : 'Clientes');
                },
                items: tabs
                    .map((tab) => BottomNavigationBarItem(
                        icon: Icon(tabIcons[tab]), label: tab))
                    .toList(),
              ),
            ]))));
  }
}
