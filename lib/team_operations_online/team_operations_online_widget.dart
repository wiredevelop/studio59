import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/ff_builtin_enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'team_operations_online_model.dart';
export 'team_operations_online_model.dart';

/// Sessão autenticada da equipa, eventos atribuídos e tickets do fotógrafo.
class TeamOperationsOnlineWidget extends StatefulWidget {
  const TeamOperationsOnlineWidget({super.key});

  static String routeName = 'TeamOperationsOnline';
  static String routePath = '/team-operations-online';

  @override
  State<TeamOperationsOnlineWidget> createState() =>
      _TeamOperationsOnlineWidgetState();
}

class _TeamOperationsOnlineWidgetState
    extends State<TeamOperationsOnlineWidget> {
  late TeamOperationsOnlineModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TeamOperationsOnlineModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.restoredStaffTokenOnline = await actions.readStudio59StaffToken();
      if (!(_model.restoredStaffTokenOnline == '')) {
        _model.restoredTeamAuth =
            await actions.authenticateStudio59StaffWithNullableToken(
          '',
          '',
          functions.studio59StringAsJson(_model.restoredStaffTokenOnline),
        );
        if (_model.restoredTeamAuth?.success == true) {
          _model.staffToken = _model.restoredTeamAuth?.token;
          safeSetState(() {});
          _model.staffName = _model.restoredTeamAuth?.userName;
          safeSetState(() {});
          _model.events = _model.restoredTeamAuth!.events
              .toList()
              .cast<Studio59StaffEventStruct>();
          safeSetState(() {});
          _model.authenticated = true;
          safeSetState(() {});
        } else {
          _model.deleteStudio59StaffTokenResult =
              await actions.deleteStudio59StaffToken();
          _model.staffToken = '';
          safeSetState(() {});
        }
      }
    });

    _model.staffEmailTextController ??= TextEditingController();
    _model.staffEmailFocusNode ??= FocusNode();

    _model.staffPasswordTextController ??= TextEditingController();
    _model.staffPasswordFocusNode ??= FocusNode();

    _model.cashReceivedAmountTextController1 ??= TextEditingController();
    _model.cashReceivedAmountFocusNode1 ??= FocusNode();

    _model.cashReceivedAmountTextController2 ??= TextEditingController();
    _model.cashReceivedAmountFocusNode2 ??= FocusNode();
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          automaticallyImplyLeading: true,
          title: Text(
            'Área da equipa',
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  font: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleLarge.fontStyle,
                  ),
                  fontSize: 22.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).titleLarge.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: true,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: (FFMainAxisAlignment.start).flutterValue,
                crossAxisAlignment: (FFCrossAxisAlignment.center).flutterValue,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (!_model.authenticated!)
                    TextFormField(
                      controller: _model.staffEmailTextController,
                      focusNode: _model.staffEmailFocusNode,
                      onChanged: (_) => EasyDebounce.debounce(
                        '_model.staffEmailTextController',
                        Duration(milliseconds: 2000),
                        () async {
                          _model.email = _model.staffEmailTextController.text;
                          safeSetState(() {});
                        },
                      ),
                      obscureText: false,
                      decoration: InputDecoration(
                        labelText: 'Nome de utilizador',
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0x00000000),
                            width: 1.0,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4.0),
                            topRight: Radius.circular(4.0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0x00000000),
                            width: 1.0,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4.0),
                            topRight: Radius.circular(4.0),
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0x00000000),
                            width: 1.0,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4.0),
                            topRight: Radius.circular(4.0),
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0x00000000),
                            width: 1.0,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4.0),
                            topRight: Radius.circular(4.0),
                          ),
                        ),
                        filled: true,
                      ),
                      style: TextStyle(),
                      maxLines: null,
                      keyboardType: (FFKeyboardType.text).flutterValue,
                      validator: _model.staffEmailTextControllerValidator
                          .asValidator(context),
                    ),
                  if (!_model.authenticated!)
                    TextFormField(
                      controller: _model.staffPasswordTextController,
                      focusNode: _model.staffPasswordFocusNode,
                      onChanged: (_) => EasyDebounce.debounce(
                        '_model.staffPasswordTextController',
                        Duration(milliseconds: 2000),
                        () async {
                          _model.password =
                              _model.staffPasswordTextController.text;
                          safeSetState(() {});
                        },
                      ),
                      obscureText: false,
                      decoration: InputDecoration(
                        labelText: 'Palavra-passe',
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0x00000000),
                            width: 1.0,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4.0),
                            topRight: Radius.circular(4.0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0x00000000),
                            width: 1.0,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4.0),
                            topRight: Radius.circular(4.0),
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0x00000000),
                            width: 1.0,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4.0),
                            topRight: Radius.circular(4.0),
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0x00000000),
                            width: 1.0,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4.0),
                            topRight: Radius.circular(4.0),
                          ),
                        ),
                        filled: true,
                      ),
                      style: TextStyle(),
                      maxLines: null,
                      validator: _model.staffPasswordTextControllerValidator
                          .asValidator(context),
                    ),
                  if (!_model.authenticated!)
                    FFButtonWidget(
                      onPressed: () async {
                        _model.busy = true;
                        safeSetState(() {});
                        if (_model.staffEmailTextController.text != null &&
                            _model.staffEmailTextController.text != '') {
                          if (_model.staffPasswordTextController.text != null &&
                              _model.staffPasswordTextController.text != '') {
                            _model.teamUsernameAuth = await actions
                                .authenticateStudio59StaffWithNullableToken(
                              _model.staffEmailTextController.text,
                              _model.staffPasswordTextController.text,
                              functions.studio59StringAsJson(''),
                            );
                            if (_model.teamUsernameAuth?.success == true) {
                              _model.storedUsernameAuthToken =
                                  await actions.storeStudio59StaffToken(
                                (String? token) {
                                  return token ?? "";
                                }(_model.teamUsernameAuth?.token),
                              );
                              if (_model.storedUsernameAuthToken == true) {
                                _model.staffToken =
                                    _model.teamUsernameAuth?.token;
                                safeSetState(() {});
                                _model.staffName =
                                    _model.teamUsernameAuth?.userName;
                                safeSetState(() {});
                                _model.events = _model.teamUsernameAuth!.events
                                    .toList()
                                    .cast<Studio59StaffEventStruct>();
                                safeSetState(() {});
                                _model.authenticated = true;
                                safeSetState(() {});
                                _model.busy = false;
                                safeSetState(() {});
                                if (Navigator.of(context).canPop()) {
                                  context.pop();
                                }
                                context.pushNamed(
                                    Studio59DashboardOnlineWidget.routeName);
                              } else {
                                _model.busy = false;
                                safeSetState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'N?o foi poss?vel guardar a sess?o da equipa.',
                                      style: TextStyle(),
                                    ),
                                    duration: Duration(milliseconds: 4000),
                                  ),
                                );
                              }
                            } else {
                              _model.busy = false;
                              safeSetState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _model.teamUsernameAuth!.message,
                                    style: TextStyle(),
                                  ),
                                  duration: Duration(milliseconds: 4000),
                                ),
                              );
                            }
                          } else {
                            _model.busy = false;
                            safeSetState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Introduza a palavra-passe.',
                                  style: TextStyle(),
                                ),
                                duration: Duration(milliseconds: 4000),
                              ),
                            );
                          }
                        } else {
                          _model.busy = false;
                          safeSetState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Introduza o nome de utilizador.',
                                style: TextStyle(),
                              ),
                              duration: Duration(milliseconds: 4000),
                            ),
                          );
                        }

                        safeSetState(() {});
                      },
                      text: 'Entrar',
                      options: FFButtonOptions(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        iconPadding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        color: FlutterFlowTheme.of(context).primary,
                        textStyle: TextStyle(
                          color: Colors.white,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  if (_model.authenticated ?? true)
                    Text(
                      _model.staffName!,
                      style: FlutterFlowTheme.of(context).titleMedium.override(
                            font: GoogleFonts.montserrat(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .fontStyle,
                            ),
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .titleMedium
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .titleMedium
                                .fontStyle,
                          ),
                    ),
                  if (_model.authenticated ?? true)
                    FFButtonWidget(
                      onPressed: () async {
                        _model.teamLogoutResult =
                            await Studio59StaffLogoutTypedCall.call(
                          token: _model.staffToken,
                        );

                        if ((_model.teamLogoutResult?.succeeded ?? true)) {
                          _model.deleteStudio59StaffTokenResult2 =
                              await actions.deleteStudio59StaffToken();
                          _model.authenticated = false;
                          safeSetState(() {});
                          _model.staffToken = '';
                          safeSetState(() {});
                          _model.activeEventId = 0;
                          safeSetState(() {});
                          _model.selectedOrderId = 0;
                          safeSetState(() {});
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Não foi possível terminar a sessão no servidor.',
                                style: TextStyle(),
                              ),
                              duration: Duration(milliseconds: 4000),
                            ),
                          );
                        }

                        safeSetState(() {});
                      },
                      text: 'Terminar sessão',
                      options: FFButtonOptions(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        iconPadding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        color: FlutterFlowTheme.of(context).primary,
                        textStyle: TextStyle(
                          color: Colors.white,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  if (_model.authenticated ?? true)
                    Text(
                      'Eventos atribuídos',
                      style: TextStyle(),
                    ),
                  Container(
                    height: 260.0,
                    child: Visibility(
                      visible: _model.authenticated ?? true,
                      child: Builder(
                        builder: (context) {
                          final event = _model.events.toList();

                          return ListView.builder(
                            padding: EdgeInsets.zero,
                            primary: false,
                            scrollDirection: Axis.vertical,
                            itemCount: event.length,
                            itemBuilder: (context, eventIndex) {
                              final eventItem = event[eventIndex];
                              return FFButtonWidget(
                                onPressed: () async {
                                  _model.activeEventId = eventItem.id;
                                  safeSetState(() {});
                                  _model.selectedOrderId = 0;
                                  safeSetState(() {});
                                  _model.eventOrdersForPhotographer =
                                      await Studio59EventOrdersTypedCall.call(
                                    event: eventItem.id,
                                    token: _model.staffToken,
                                  );

                                  if ((_model.eventOrdersForPhotographer
                                          ?.succeeded ??
                                      true)) {
                                    _model.orders =
                                        Studio59StaffOrdersResponseStruct
                                                .maybeFromMap((_model
                                                        .eventOrdersForPhotographer
                                                        ?.jsonBody ??
                                                    ''))!
                                            .data
                                            .toList()
                                            .cast<Studio59StaffOrderStruct>();
                                    safeSetState(() {});
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Não tem acesso aos pedidos deste evento.',
                                          style: TextStyle(),
                                        ),
                                        duration: Duration(milliseconds: 4000),
                                      ),
                                    );
                                  }

                                  safeSetState(() {});
                                },
                                text: eventItem.name,
                                options: FFButtonOptions(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 0.0),
                                  iconPadding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 0.0),
                                  color: FlutterFlowTheme.of(context).primary,
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                  ),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  if (!(_model.activeEventId == 0))
                    Text(
                      'Tickets do evento selecionado',
                      style: TextStyle(),
                    ),
                  Container(
                    height: 260.0,
                    child: Visibility(
                      visible: _model.selectedOrderId == -1,
                      child: Builder(
                        builder: (context) {
                          final order = _model.orders.toList();

                          return ListView.builder(
                            padding: EdgeInsets.zero,
                            primary: false,
                            scrollDirection: Axis.vertical,
                            itemCount: order.length,
                            itemBuilder: (context, orderIndex) {
                              final orderItem = order[orderIndex];
                              return FFButtonWidget(
                                onPressed: () async {
                                  _model.selectedOrderId = orderItem.id;
                                  safeSetState(() {});
                                  _model.photographerOrderDetails =
                                      await Studio59OrderDetailsTypedCall.call(
                                    order: orderItem.id,
                                    token: _model.staffToken,
                                  );

                                  if ((_model.photographerOrderDetails
                                          ?.succeeded ??
                                      true)) {
                                    _model.orderDetails =
                                        Studio59StaffOrderDetailsResponseStruct
                                                .maybeFromMap((_model
                                                        .photographerOrderDetails
                                                        ?.jsonBody ??
                                                    ''))
                                            ?.data;
                                    safeSetState(() {});
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Não foi possível abrir este ticket.',
                                          style: TextStyle(),
                                        ),
                                        duration: Duration(milliseconds: 4000),
                                      ),
                                    );
                                  }

                                  safeSetState(() {});
                                },
                                text: orderItem.orderCode,
                                options: FFButtonOptions(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 0.0),
                                  iconPadding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 0.0),
                                  color: FlutterFlowTheme.of(context).primary,
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                  ),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  Container(
                    height: 300.0,
                    child: Visibility(
                      visible: !(_model.activeEventId == 0),
                      child: Builder(
                        builder: (context) {
                          final order = _model.orders.toList();

                          return ListView.builder(
                            padding: EdgeInsets.zero,
                            primary: false,
                            scrollDirection: Axis.vertical,
                            itemCount: order.length,
                            itemBuilder: (context, orderIndex) {
                              final orderItem = order[orderIndex];
                              return FFButtonWidget(
                                onPressed: () async {
                                  _model.selectedOrderId = orderItem.id;
                                  safeSetState(() {});
                                  _model.cashReceivedText = '';
                                  safeSetState(() {});
                                  _model.cashChangeGiven = false;
                                  safeSetState(() {});
                                  _model.paymentSubmitting = false;
                                  safeSetState(() {});
                                  _model.paymentUncertain = false;
                                  safeSetState(() {});
                                  _model.selectedPhotographerOrderDetails =
                                      await Studio59OrderDetailsRawCall.call(
                                    order: orderItem.id,
                                    token: _model.staffToken,
                                  );

                                  if ((_model.selectedPhotographerOrderDetails
                                          ?.succeeded ??
                                      true)) {
                                    _model.orderDetailsFull =
                                        Studio59StaffOrderDetailsStruct
                                            .maybeFromMap((_model
                                                    .selectedPhotographerOrderDetails
                                                    ?.jsonBody ??
                                                ''));
                                    safeSetState(() {});
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'NÃ£o foi possÃ­vel abrir este ticket.',
                                          style: TextStyle(),
                                        ),
                                        duration: Duration(milliseconds: 4000),
                                      ),
                                    );
                                  }

                                  safeSetState(() {});
                                },
                                text: orderItem.orderCode,
                                options: FFButtonOptions(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 0.0),
                                  iconPadding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 0.0),
                                  color: FlutterFlowTheme.of(context).primary,
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                  ),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  if (!(_model.activeEventId == 0))
                    Builder(
                      builder: (context) {
                        final order = _model.orders.toList();

                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          primary: false,
                          scrollDirection: Axis.vertical,
                          itemCount: order.length,
                          itemBuilder: (context, orderIndex) {
                            final orderItem = order[orderIndex];
                            return FFButtonWidget(
                              onPressed: () async {
                                _model.selectedOrderId = orderItem.id;
                                safeSetState(() {});
                                _model.cashReceivedText = '';
                                safeSetState(() {});
                                _model.cashChangeGiven = false;
                                safeSetState(() {});
                                _model.paymentSubmitting = false;
                                safeSetState(() {});
                                _model.paymentUncertain = false;
                                safeSetState(() {});
                                _model.selectedPhotographerOrderDetails2 =
                                    await Studio59OrderDetailsRawCall.call(
                                  order: orderItem.id,
                                  token: _model.staffToken,
                                );

                                if ((_model.selectedPhotographerOrderDetails2
                                        ?.succeeded ??
                                    true)) {
                                  _model.orderDetailsFull =
                                      Studio59StaffOrderDetailsStruct
                                          .maybeFromMap((_model
                                                  .selectedPhotographerOrderDetails2
                                                  ?.jsonBody ??
                                              ''));
                                  safeSetState(() {});
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'NÃ£o foi possÃ­vel abrir este ticket.',
                                        style: TextStyle(),
                                      ),
                                      duration: Duration(milliseconds: 4000),
                                    ),
                                  );
                                }

                                safeSetState(() {});
                              },
                              text: orderItem.orderCode,
                              options: FFButtonOptions(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 0.0, 0.0, 0.0),
                                iconPadding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 0.0, 0.0, 0.0),
                                color: FlutterFlowTheme.of(context).primary,
                                textStyle: TextStyle(
                                  color: Colors.white,
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  if (!(_model.selectedOrderId == 0))
                    Text(
                      _model.orderDetails!.orderCode,
                      style: FlutterFlowTheme.of(context).titleLarge.override(
                            font: GoogleFonts.montserrat(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .titleLarge
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .titleLarge
                                  .fontStyle,
                            ),
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .titleLarge
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .titleLarge
                                .fontStyle,
                          ),
                    ),
                  if (!(_model.selectedOrderId == 0))
                    Text(
                      functions.studio59CashResultStatus(
                          _model.orderDetailsFull?.status,
                          _model.orderDetailsFull?.cashDueAmount)!,
                      style: TextStyle(),
                    ),
                  if (_model.selectedOrderId == -1)
                    Text(
                      _model.orderDetails!.totalAmount!.toString(),
                      style: TextStyle(),
                    ),
                  if (_model.selectedOrderId == -1)
                    Text(
                      _model.orderDetails!.amountReceived!.toString(),
                      style: TextStyle(),
                    ),
                  if (_model.selectedOrderId == -1)
                    Text(
                      _model.orderDetails!.changeDue!.toString(),
                      style: TextStyle(),
                    ),
                  if (!(_model.selectedOrderId == 0))
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment:
                          (FFMainAxisAlignment.start).flutterValue,
                      crossAxisAlignment:
                          (FFCrossAxisAlignment.center).flutterValue,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Total (€)',
                          style: TextStyle(),
                        ),
                        Text(
                          functions.studio59CashAmountLabel(
                              _model.orderDetailsFull?.totalAmount)!,
                          style: TextStyle(),
                        ),
                        Text(
                          'Recebido registado (€)',
                          style: TextStyle(),
                        ),
                        Text(
                          functions.studio59CashAmountLabel(
                              _model.orderDetailsFull?.cashReceivedAmount)!,
                          style: TextStyle(),
                        ),
                        Text(
                          'Troco registado (€)',
                          style: TextStyle(),
                        ),
                        Text(
                          functions.studio59CashAmountLabel(
                              _model.orderDetailsFull?.cashChangeAmount)!,
                          style: TextStyle(),
                        ),
                        Text(
                          'Troco entregue',
                          style: TextStyle(),
                        ),
                        Text(
                          _model.orderDetailsFull!.cashChangeGiven.toString(),
                          style: TextStyle(),
                        ),
                        Text(
                          'Em dívida (€)',
                          style: TextStyle(),
                        ),
                        Text(
                          functions.studio59CashAmountLabel(
                              _model.orderDetailsFull?.cashDueAmount)!,
                          style: TextStyle(),
                        ),
                        if (_model.orderDetailsFull?.status == 'pending')
                          TextFormField(
                            controller:
                                _model.cashReceivedAmountTextController1,
                            focusNode: _model.cashReceivedAmountFocusNode1,
                            onChanged: (_) => EasyDebounce.debounce(
                              '_model.cashReceivedAmountTextController1',
                              Duration(milliseconds: 2000),
                              () async {
                                _model.cashReceivedText = _model
                                    .cashReceivedAmountTextController1.text;
                                safeSetState(() {});
                              },
                            ),
                            obscureText: false,
                            decoration: InputDecoration(
                              labelText: 'Montante recebido agora (€)',
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4.0),
                                  topRight: Radius.circular(4.0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4.0),
                                  topRight: Radius.circular(4.0),
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4.0),
                                  topRight: Radius.circular(4.0),
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4.0),
                                  topRight: Radius.circular(4.0),
                                ),
                              ),
                              filled: true,
                            ),
                            style: TextStyle(),
                            maxLines: null,
                            keyboardType: (FFKeyboardType.number).flutterValue,
                            validator: _model
                                .cashReceivedAmountTextController1Validator
                                .asValidator(context),
                          ),
                        Text(
                          functions.studio59CashPreview(_model.cashReceivedText,
                              _model.orderDetailsFull?.totalAmount)!,
                          style: TextStyle(),
                        ),
                        if (_model.orderDetailsFull?.status == 'pending')
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment:
                                (FFCrossAxisAlignment.center).flutterValue,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              if (_model.orderDetailsFull?.status == 'pending')
                                Theme(
                                  data: ThemeData(
                                    checkboxTheme: CheckboxThemeData(
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(4.0),
                                      ),
                                    ),
                                    unselectedWidgetColor:
                                        FlutterFlowTheme.of(context)
                                            .secondaryText,
                                  ),
                                  child: Checkbox(
                                    value: _model.checkboxValue1 ??=
                                        _model.cashChangeGiven!,
                                    onChanged: (newValue) async {
                                      safeSetState(() =>
                                          _model.checkboxValue1 = newValue!);
                                      if (newValue!) {
                                        _model.cashChangeGiven =
                                            _model.checkboxValue1;
                                        safeSetState(() {});
                                      } else {
                                        _model.cashChangeGiven =
                                            _model.checkboxValue1;
                                        safeSetState(() {});
                                      }
                                    },
                                    side: (FlutterFlowTheme.of(context)
                                                .secondaryText !=
                                            null)
                                        ? BorderSide(
                                            width: 2,
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText!,
                                          )
                                        : null,
                                    activeColor:
                                        FlutterFlowTheme.of(context).primary,
                                    checkColor: FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                  ),
                                ),
                              Container(
                                width: 8.0,
                              ),
                              Text(
                                'Troco já entregue',
                                style: TextStyle(),
                              ),
                            ],
                          ),
                        if (_model.paymentUncertain ?? true)
                          Text(
                            'Não foi possível confirmar a resposta do servidor. Reabra o ticket para consultar o estado antes de tentar novamente.',
                            style: TextStyle(
                              color: FlutterFlowTheme.of(context).error,
                            ),
                          ),
                      ].divide(SizedBox(height: 8.0)),
                    ),
                  if (_model.selectedOrderId == -1)
                    Text(
                      _model.orderDetails!.amountDue!.toString(),
                      style: TextStyle(),
                    ),
                  if (_model.selectedOrderId == -1)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment:
                          (FFMainAxisAlignment.start).flutterValue,
                      crossAxisAlignment:
                          (FFCrossAxisAlignment.center).flutterValue,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Total (€)',
                          style: TextStyle(),
                        ),
                        Text(
                          _model.orderDetailsFull!.totalAmount!.toString(),
                          style: TextStyle(),
                        ),
                        Text(
                          'Recebido registado (€)',
                          style: TextStyle(),
                        ),
                        Text(
                          _model.orderDetailsFull!.cashReceivedAmount!
                              .toString(),
                          style: TextStyle(),
                        ),
                        Text(
                          'Troco registado (€)',
                          style: TextStyle(),
                        ),
                        Text(
                          _model.orderDetailsFull!.cashChangeAmount!.toString(),
                          style: TextStyle(),
                        ),
                        Text(
                          'Troco entregue',
                          style: TextStyle(),
                        ),
                        Text(
                          _model.orderDetailsFull!.cashChangeGiven.toString(),
                          style: TextStyle(),
                        ),
                        Text(
                          'Em dívida (€)',
                          style: TextStyle(),
                        ),
                        Text(
                          _model.orderDetailsFull!.cashDueAmount!.toString(),
                          style: TextStyle(),
                        ),
                        if (_model.orderDetailsFull?.status == 'pending')
                          TextFormField(
                            controller:
                                _model.cashReceivedAmountTextController2,
                            focusNode: _model.cashReceivedAmountFocusNode2,
                            onChanged: (_) => EasyDebounce.debounce(
                              '_model.cashReceivedAmountTextController2',
                              Duration(milliseconds: 2000),
                              () async {
                                _model.cashReceivedText = _model
                                    .cashReceivedAmountTextController2.text;
                                safeSetState(() {});
                              },
                            ),
                            obscureText: false,
                            decoration: InputDecoration(
                              labelText: 'Montante recebido agora (€)',
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4.0),
                                  topRight: Radius.circular(4.0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4.0),
                                  topRight: Radius.circular(4.0),
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4.0),
                                  topRight: Radius.circular(4.0),
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4.0),
                                  topRight: Radius.circular(4.0),
                                ),
                              ),
                              filled: true,
                            ),
                            style: TextStyle(),
                            maxLines: null,
                            keyboardType: (FFKeyboardType.number).flutterValue,
                            validator: _model
                                .cashReceivedAmountTextController2Validator
                                .asValidator(context),
                          ),
                        Text(
                          functions.studio59CashPreview(_model.cashReceivedText,
                              _model.orderDetailsFull?.totalAmount)!,
                          style: TextStyle(),
                        ),
                        if (_model.orderDetailsFull?.status == 'pending')
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment:
                                (FFCrossAxisAlignment.center).flutterValue,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Theme(
                                data: ThemeData(
                                  checkboxTheme: CheckboxThemeData(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                  ),
                                  unselectedWidgetColor:
                                      FlutterFlowTheme.of(context)
                                          .secondaryText,
                                ),
                                child: Checkbox(
                                  value: _model.checkboxValue2 ??=
                                      _model.cashChangeGiven!,
                                  onChanged: (newValue) async {
                                    safeSetState(() =>
                                        _model.checkboxValue2 = newValue!);
                                    if (newValue!) {
                                      _model.cashChangeGiven =
                                          _model.checkboxValue2;
                                      safeSetState(() {});
                                    } else {
                                      _model.cashChangeGiven =
                                          _model.checkboxValue2;
                                      safeSetState(() {});
                                    }
                                  },
                                  side: (FlutterFlowTheme.of(context)
                                              .secondaryText !=
                                          null)
                                      ? BorderSide(
                                          width: 2,
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText!,
                                        )
                                      : null,
                                  activeColor:
                                      FlutterFlowTheme.of(context).primary,
                                  checkColor: FlutterFlowTheme.of(context)
                                      .primaryBackground,
                                ),
                              ),
                              Container(
                                width: 8.0,
                              ),
                              Text(
                                'Troco já entregue',
                                style: TextStyle(),
                              ),
                            ],
                          ),
                        if (_model.paymentUncertain ?? true)
                          Text(
                            'Não foi possível confirmar a resposta do servidor. Reabra o ticket para consultar o estado antes de tentar novamente.',
                            style: TextStyle(
                              color: FlutterFlowTheme.of(context).error,
                            ),
                          ),
                      ].divide(SizedBox(height: 8.0)),
                    ),
                  if (_model.selectedOrderId == 0
                      ? false
                      : (_model.orderDetailsFull?.status == 'pending'))
                    FFButtonWidget(
                      onPressed: () async {
                        if (!_model.paymentSubmitting!) {
                          if (!_model.paymentUncertain!) {
                            _model.paymentSubmitting = true;
                            safeSetState(() {});
                            _model.cashReceivedDecimal =
                                functions.studio59FormatReceivedEur(
                                    _model.cashReceivedText);
                            safeSetState(() {});
                            _model.cashChangeDecimal =
                                functions.studio59CashDifference(
                                    _model.cashReceivedText,
                                    _model.orderDetailsFull?.totalAmount,
                                    true);
                            safeSetState(() {});
                            _model.cashDueDecimal =
                                functions.studio59CashDifference(
                                    _model.cashReceivedText,
                                    _model.orderDetailsFull?.totalAmount,
                                    false);
                            safeSetState(() {});
                            _model.photographerMarkPaidResult = await actions
                                .postStudio59MarkPaidWithCashNullableSafe(
                              functions
                                  .studio59IntAsJson(_model.selectedOrderId),
                              functions.studio59StringAsJson(_model.staffToken),
                              functions.studio59StringAsJson(
                                  _model.cashReceivedDecimal),
                              functions.studio59StringAsJson(
                                  _model.cashChangeDecimal),
                              functions
                                  .studio59StringAsJson(_model.cashDueDecimal),
                              functions
                                  .studio59BoolAsJson(_model.cashChangeGiven),
                              functions.studio59StringAsJson(''),
                            );
                            if (_model.photographerMarkPaidResult?.success ==
                                true) {
                              _model.reloadedPhotographerOrderAfterPayment =
                                  await Studio59OrderDetailsRawCall.call(
                                order: _model.selectedOrderId,
                                token: _model.staffToken,
                              );

                              if ((_model.reloadedPhotographerOrderAfterPayment
                                      ?.succeeded ??
                                  true)) {
                                _model.orderDetailsFull =
                                    Studio59StaffOrderDetailsStruct.maybeFromMap(
                                        (_model.reloadedPhotographerOrderAfterPayment
                                                ?.jsonBody ??
                                            ''));
                                safeSetState(() {});
                                _model.paymentSubmitting = false;
                                safeSetState(() {});
                              } else {
                                _model.paymentSubmitting = false;
                                safeSetState(() {});
                                _model.paymentUncertain = true;
                                safeSetState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Pagamento enviado. NÃ£o foi possÃ­vel atualizar o estado do ticket; volte a abri-lo para confirmar.',
                                      style: TextStyle(),
                                    ),
                                    duration: Duration(milliseconds: 4000),
                                  ),
                                );
                              }
                            } else {
                              _model.paymentSubmitting = false;
                              safeSetState(() {});
                              if (_model
                                      .photographerMarkPaidResult?.statusCode ==
                                  401) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'A sessÃ£o expirou (401). Inicie sessÃ£o novamente.',
                                      style: TextStyle(),
                                    ),
                                    duration: Duration(milliseconds: 4000),
                                  ),
                                );
                              } else {
                                if (_model.photographerMarkPaidResult
                                        ?.statusCode ==
                                    403) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Sem permissÃ£o para registar este pagamento (403).',
                                        style: TextStyle(),
                                      ),
                                      duration: Duration(milliseconds: 4000),
                                    ),
                                  );
                                } else {
                                  if (_model.photographerMarkPaidResult
                                          ?.statusCode ==
                                      422) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Os valores ou dados do pagamento foram rejeitados (422).',
                                          style: TextStyle(),
                                        ),
                                        duration: Duration(milliseconds: 4000),
                                      ),
                                    );
                                  } else {
                                    _model.paymentUncertain = true;
                                    safeSetState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Falha de rede ou erro do servidor. Reabra o ticket para confirmar o estado antes de repetir.',
                                          style: TextStyle(),
                                        ),
                                        duration: Duration(milliseconds: 4000),
                                      ),
                                    );
                                  }
                                }
                              }
                            }
                          }
                        }

                        safeSetState(() {});
                      },
                      text: 'Registar pagamento recebido',
                      options: FFButtonOptions(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        iconPadding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        color: FlutterFlowTheme.of(context).primary,
                        textStyle: TextStyle(
                          color: Colors.white,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                ].divide(SizedBox(height: 12.0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
