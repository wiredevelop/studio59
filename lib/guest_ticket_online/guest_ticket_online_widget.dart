import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/ff_builtin_enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'guest_ticket_online_model.dart';
export 'guest_ticket_online_model.dart';

/// Confirmação do ticket presencial devolvido pela API.
class GuestTicketOnlineWidget extends StatefulWidget {
  const GuestTicketOnlineWidget({super.key});

  static String routeName = 'GuestTicketOnline';
  static String routePath = '/guest-ticket-online';

  @override
  State<GuestTicketOnlineWidget> createState() =>
      _GuestTicketOnlineWidgetState();
}

class _GuestTicketOnlineWidgetState extends State<GuestTicketOnlineWidget> {
  late GuestTicketOnlineModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GuestTicketOnlineModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (FFAppState().offlineApiBase == '') {
        _model.guestOrderDeliveryDetails =
            await Studio59PublicOrderByCodeCall.call(
          orderCode: FFAppState().lastGuestOrder.orderCode,
        );

        if ((_model.guestOrderDeliveryDetails?.succeeded ?? true)) {
          _model.serverDeliveryType =
              Studio59PublicOrderDetailsStruct.maybeFromMap(
                      (_model.guestOrderDeliveryDetails?.jsonBody ?? ''))
                  ?.deliveryType;
          safeSetState(() {});
          _model.serverShippingFee =
              Studio59PublicOrderDetailsStruct.maybeFromMap(
                      (_model.guestOrderDeliveryDetails?.jsonBody ?? ''))
                  ?.shippingFee;
          safeSetState(() {});
        } else {
          _model.shippingLookupFailed = true;
          safeSetState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

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
            'Ticket registado',
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
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: (FFMainAxisAlignment.start).flutterValue,
              crossAxisAlignment: (FFCrossAxisAlignment.center).flutterValue,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Código do ticket',
                  style: FlutterFlowTheme.of(context).titleLarge.override(
                        font: GoogleFonts.montserrat(
                          fontWeight: FlutterFlowTheme.of(context)
                              .titleLarge
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).titleLarge.fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).titleLarge.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).titleLarge.fontStyle,
                      ),
                ),
                Text(
                  FFAppState().lastGuestOrder.orderCode,
                  style: FlutterFlowTheme.of(context).headlineMedium.override(
                        font: GoogleFonts.playfairDisplay(
                          fontWeight: FlutterFlowTheme.of(context)
                              .headlineMedium
                              .fontWeight,
                          fontStyle: FlutterFlowTheme.of(context)
                              .headlineMedium
                              .fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontWeight,
                        fontStyle: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontStyle,
                      ),
                ),
                Text(
                  FFAppState().lastGuestOrder.status,
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
                        fontWeight:
                            FlutterFlowTheme.of(context).titleMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).titleMedium.fontStyle,
                      ),
                ),
                Text(
                  FFAppState().lastGuestOrder.totalAmount!.toString(),
                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                        font: GoogleFonts.playfairDisplay(
                          fontWeight: FlutterFlowTheme.of(context)
                              .headlineSmall
                              .fontWeight,
                          fontStyle: FlutterFlowTheme.of(context)
                              .headlineSmall
                              .fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight: FlutterFlowTheme.of(context)
                            .headlineSmall
                            .fontWeight,
                        fontStyle: FlutterFlowTheme.of(context)
                            .headlineSmall
                            .fontStyle,
                      ),
                ),
                Text(
                  'O seu ticket foi registado. Aguarde que um fotógrafo vá ter consigo ou dirija-se a um. Entregue o iPad à próxima pessoa para escolher.',
                  style: TextStyle(),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: (FFMainAxisAlignment.start).flutterValue,
                  crossAxisAlignment:
                      (FFCrossAxisAlignment.center).flutterValue,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (_model.serverDeliveryType == 'shipping')
                      Text(
                        'Custo de envio calculado pelo servidor (â‚¬)',
                        style: TextStyle(),
                      ),
                    if (_model.serverDeliveryType == 'shipping')
                      Text(
                        _model.serverShippingFee!.toString(),
                        style: TextStyle(),
                      ),
                    if (_model.shippingLookupFailed ?? true)
                      Text(
                        'NÃ£o foi possÃ­vel atualizar os detalhes de entrega do pedido.',
                        style: TextStyle(
                          color: FlutterFlowTheme.of(context).error,
                        ),
                      ),
                  ].divide(SizedBox(height: 8.0)),
                ),
                FFButtonWidget(
                  onPressed: () async {
                    FFAppState().guestCart = [];
                    safeSetState(() {});
                    FFAppState().lastGuestOrder = Studio59OrderReceiptStruct();
                    safeSetState(() {});

                    context.goNamed(GuestGalleryOnlineWidget.routeName);
                  },
                  text: 'Ver catálogo',
                  options: FFButtonOptions(
                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                    iconPadding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                    color: FlutterFlowTheme.of(context).primary,
                    textStyle: TextStyle(
                      color: Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ].divide(SizedBox(height: 16.0)),
            ),
          ),
        ),
      ),
    );
  }
}
