import '/backend/schema/structs/index.dart';
import '/components/button/button_widget.dart';
import '/components/keypad_button/keypad_button_widget.dart';
import '/components/pin_digit/pin_digit_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'welcome_screen_model.dart';
export 'welcome_screen_model.dart';

class WelcomeScreenWidget extends StatefulWidget {
  const WelcomeScreenWidget({super.key});

  static String routeName = 'WelcomeScreen';
  static String routePath = '/welcomeScreen';

  @override
  State<WelcomeScreenWidget> createState() => _WelcomeScreenWidgetState();
}

class _WelcomeScreenWidgetState extends State<WelcomeScreenWidget> {
  late WelcomeScreenModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => WelcomeScreenModel());
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
        backgroundColor: Colors.black,
        body: SingleChildScrollView(
          primary: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.all(32.0),
                child: Container(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16.0),
                              shape: BoxShape.rectangle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Container(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        if (_model.teamLogoTapCount == 4) {
                                          _model.teamLogoTapCount = 0;
                                          safeSetState(() {});
                                          _model.welcomeStaffTokenForDashboard =
                                              await actions
                                                  .readStudio59StaffToken();
                                          if (!(_model
                                                  .welcomeStaffTokenForDashboard ==
                                              '')) {
                                            context.pushNamed(
                                                Studio59DashboardOnlineWidget
                                                    .routeName);
                                          } else {
                                            context.pushNamed(
                                                TeamOperationsOnlineWidget
                                                    .routeName);
                                          }
                                        } else {
                                          _model.teamLogoTapCount =
                                              functions.nextGalleryPage(
                                                  _model.teamLogoTapCount);
                                          safeSetState(() {});
                                        }

                                        safeSetState(() {});
                                      },
                                      child: Image.asset(
                                        'assets/images/studio_59_logo.jpeg',
                                        width: 144.65,
                                        fit: BoxFit.contain,
                                        alignment: Alignment(0.0, 0.0),
                                      ),
                                    ),
                                  ].divide(SizedBox(height: 4.0)),
                                ),
                              ),
                            ),
                          ),
                        ].divide(SizedBox(height: 16.0)),
                      ),
                      Container(
                        child: custom_widgets.Studio59NetworkStatus(),
                      ),
                      Container(
                        height: 24.0,
                      ),
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: 400.0,
                        ),
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          borderRadius: BorderRadius.circular(24.0),
                          shape: BoxShape.rectangle,
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1.0,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Container(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 120.0,
                                  height: 120.0,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFFDF2F5),
                                    borderRadius: BorderRadius.circular(9999.0),
                                    shape: BoxShape.rectangle,
                                  ),
                                  alignment: AlignmentDirectional(0.0, 0.0),
                                  child: Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: FlutterFlowTheme.of(context).primary,
                                    size: 56.0,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Escanear QR Code',
                                      style: FlutterFlowTheme.of(context)
                                          .titleLarge
                                          .override(
                                            font: GoogleFonts.montserrat(
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleLarge
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleLarge
                                                    .fontStyle,
                                            lineHeight: 1.4,
                                          ),
                                    ),
                                    Text(
                                      'Aponte para o código no iPad do evento',
                                      textAlign: TextAlign.center,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.montserrat(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                            lineHeight: 1.5,
                                          ),
                                    ),
                                  ].divide(SizedBox(height: 4.0)),
                                ),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () async {
                                    _model.guestQrScan =
                                        await FlutterBarcodeScanner.scanBarcode(
                                      '#C62828', // scanning line color
                                      '', // cancel button text
                                      true, // whether to show the torch (camera LED) toggle icon
                                      ScanMode.QR,
                                    );

                                    if (!(_model.guestQrScan == '')) {
                                      if (!_model.qrRequestInFlight!) {
                                        _model.qrRequestInFlight = true;
                                        safeSetState(() {});
                                        _model.guestQrEntry = await actions
                                            .enterStudio59GuestSessionSafely(
                                          (String? credential) {
                                            return credential ?? "";
                                          }(functions.extractStudio59QrToken(
                                              _model.guestQrScan)),
                                          true,
                                        );
                                        if (_model.guestQrEntry?.success ==
                                            true) {
                                          FFAppState().guestSessionToken =
                                              _model.guestQrEntry!
                                                  .eventSessionToken;
                                          safeSetState(() {});
                                          FFAppState().guestEvent =
                                              _model.guestQrEntry!.event;
                                          safeSetState(() {});
                                          FFAppState().guestCart = [];
                                          safeSetState(() {});
                                          _model.qrRequestInFlight = false;
                                          safeSetState(() {});
                                          if (Navigator.of(context).canPop()) {
                                            context.pop();
                                          }
                                          context.pushNamed(
                                              GuestGalleryOnlineWidget
                                                  .routeName);
                                        } else {
                                          _model.qrRequestInFlight = false;
                                          safeSetState(() {});
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                _model.guestQrEntry!.message,
                                                style: TextStyle(),
                                              ),
                                              duration:
                                                  Duration(milliseconds: 4000),
                                            ),
                                          );
                                        }
                                      }
                                    }

                                    safeSetState(() {});
                                  },
                                  child: wrapWithModel(
                                    model: _model.buttonModel,
                                    updateCallback: () => safeSetState(() {}),
                                    child: ButtonWidget(
                                      icon: Icon(
                                        Icons.photo_camera_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        size: 24.0,
                                      ),
                                      iconPresent: true,
                                      iconEndPresent: false,
                                      content: 'Abrir Câmara',
                                      variant: 'primary',
                                      size: 'large',
                                      loading: false,
                                      disabled: false,
                                    ),
                                  ),
                                ),
                              ].divide(SizedBox(height: 24.0)),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            0.0, 24.0, 0.0, 24.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 1,
                              child: Divider(
                                height: 16.0,
                                thickness: 1.0,
                                indent: 0.0,
                                endIndent: 0.0,
                                color: FlutterFlowTheme.of(context).alternate,
                              ),
                            ),
                            Text(
                              'OU INTRODUZIR PIN',
                              style: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .override(
                                    font: GoogleFonts.montserrat(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                    ),
                                    color: Colors.white,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontStyle,
                                    lineHeight: 1.2,
                                  ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Divider(
                                height: 16.0,
                                thickness: 1.0,
                                indent: 0.0,
                                endIndent: 0.0,
                                color: FlutterFlowTheme.of(context).alternate,
                              ),
                            ),
                          ].divide(SizedBox(width: 16.0)),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Código do Evento',
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      color: Colors.white,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                      lineHeight: 1.45,
                                    ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      _model.showKeypad = true;
                                      safeSetState(() {});
                                    },
                                    child: wrapWithModel(
                                      model: _model.pinDigitModel1,
                                      updateCallback: () => safeSetState(() {}),
                                      child: PinDigitWidget(
                                        value: _model.pinDigit1,
                                        filled: !(_model.pinDigit1 == ''),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      _model.showKeypad = true;
                                      safeSetState(() {});
                                    },
                                    child: wrapWithModel(
                                      model: _model.pinDigitModel2,
                                      updateCallback: () => safeSetState(() {}),
                                      child: PinDigitWidget(
                                        value: _model.pinDigit2,
                                        filled: !(_model.pinDigit2 == ''),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      _model.showKeypad = true;
                                      safeSetState(() {});
                                    },
                                    child: wrapWithModel(
                                      model: _model.pinDigitModel3,
                                      updateCallback: () => safeSetState(() {}),
                                      child: PinDigitWidget(
                                        value: _model.pinDigit3,
                                        filled: !(_model.pinDigit3 == ''),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      _model.showKeypad = true;
                                      safeSetState(() {});
                                    },
                                    child: wrapWithModel(
                                      model: _model.pinDigitModel4,
                                      updateCallback: () => safeSetState(() {}),
                                      child: PinDigitWidget(
                                        value: _model.pinDigit4,
                                        filled: !(_model.pinDigit4 == ''),
                                      ),
                                    ),
                                  ),
                                ].divide(SizedBox(width: 16.0)),
                              ),
                            ].divide(SizedBox(height: 16.0)),
                          ),
                          if (_model.showKeypad ?? true)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        if (_model.selectedPinSlot == '4') {
                                          if (!_model.pinRequestInFlight!) {
                                            if (!(_model.pinDigit1 == '')) {
                                              if (!(_model.pinDigit2 == '')) {
                                                if (!(_model.pinDigit3 == '')) {
                                                  _model.pinRequestInFlight =
                                                      true;
                                                  safeSetState(() {});
                                                  _model.guestPinEntry1 =
                                                      await actions
                                                          .enterStudio59GuestSessionSafely(
                                                    (String? credential) {
                                                      return credential ?? "";
                                                    }(functions.joinPinDigits(
                                                        _model.pinDigit1,
                                                        _model.pinDigit2,
                                                        _model.pinDigit3,
                                                        '1')),
                                                    false,
                                                  );
                                                  if (_model.guestPinEntry1
                                                          ?.success ==
                                                      true) {
                                                    FFAppState()
                                                            .guestSessionToken =
                                                        _model.guestPinEntry1!
                                                            .eventSessionToken;
                                                    safeSetState(() {});
                                                    FFAppState().guestEvent =
                                                        _model.guestPinEntry1!
                                                            .event;
                                                    safeSetState(() {});
                                                    FFAppState().guestCart = [];
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    if (Navigator.of(context)
                                                        .canPop()) {
                                                      context.pop();
                                                    }
                                                    context.pushNamed(
                                                        GuestGalleryOnlineWidget
                                                            .routeName);
                                                  } else {
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.selectedPinSlot =
                                                        '1';
                                                    safeSetState(() {});
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          _model.guestPinEntry1!
                                                              .message,
                                                          style: TextStyle(),
                                                        ),
                                                        duration: Duration(
                                                            milliseconds: 4000),
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            }
                                          }
                                        }
                                        if (_model.pinDigit1 == '') {
                                          _model.pinDigit1 = '1';
                                          safeSetState(() {});
                                          _model.selectedPinSlot = '2';
                                          safeSetState(() {});
                                        } else {
                                          if (_model.pinDigit2 == '') {
                                            _model.pinDigit2 = '1';
                                            safeSetState(() {});
                                            _model.selectedPinSlot = '3';
                                            safeSetState(() {});
                                          } else {
                                            if (_model.pinDigit3 == '') {
                                              _model.pinDigit3 = '1';
                                              safeSetState(() {});
                                              _model.selectedPinSlot = '4';
                                              safeSetState(() {});
                                            } else {
                                              if (_model.pinDigit4 == '') {
                                                _model.pinDigit4 = '1';
                                                safeSetState(() {});
                                              }
                                            }
                                          }
                                        }

                                        safeSetState(() {});
                                      },
                                      child: wrapWithModel(
                                        model: _model.keypadButtonModel1,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: KeypadButtonWidget(
                                          digit: '1',
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        if (_model.selectedPinSlot == '4') {
                                          if (!_model.pinRequestInFlight!) {
                                            if (!(_model.pinDigit1 == '')) {
                                              if (!(_model.pinDigit2 == '')) {
                                                if (!(_model.pinDigit3 == '')) {
                                                  _model.pinRequestInFlight =
                                                      true;
                                                  safeSetState(() {});
                                                  _model.guestPinEntry2 =
                                                      await actions
                                                          .enterStudio59GuestSessionSafely(
                                                    (String? credential) {
                                                      return credential ?? "";
                                                    }(functions.joinPinDigits(
                                                        _model.pinDigit1,
                                                        _model.pinDigit2,
                                                        _model.pinDigit3,
                                                        '2')),
                                                    false,
                                                  );
                                                  if (_model.guestPinEntry2
                                                          ?.success ==
                                                      true) {
                                                    FFAppState()
                                                            .guestSessionToken =
                                                        _model.guestPinEntry2!
                                                            .eventSessionToken;
                                                    safeSetState(() {});
                                                    FFAppState().guestEvent =
                                                        _model.guestPinEntry2!
                                                            .event;
                                                    safeSetState(() {});
                                                    FFAppState().guestCart = [];
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    if (Navigator.of(context)
                                                        .canPop()) {
                                                      context.pop();
                                                    }
                                                    context.pushNamed(
                                                        GuestGalleryOnlineWidget
                                                            .routeName);
                                                  } else {
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.selectedPinSlot =
                                                        '1';
                                                    safeSetState(() {});
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          _model.guestPinEntry2!
                                                              .message,
                                                          style: TextStyle(),
                                                        ),
                                                        duration: Duration(
                                                            milliseconds: 4000),
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            }
                                          }
                                        }
                                        if (_model.pinDigit1 == '') {
                                          _model.pinDigit1 = '2';
                                          safeSetState(() {});
                                          _model.selectedPinSlot = '2';
                                          safeSetState(() {});
                                        } else {
                                          if (_model.pinDigit2 == '') {
                                            _model.pinDigit2 = '2';
                                            safeSetState(() {});
                                            _model.selectedPinSlot = '3';
                                            safeSetState(() {});
                                          } else {
                                            if (_model.pinDigit3 == '') {
                                              _model.pinDigit3 = '2';
                                              safeSetState(() {});
                                              _model.selectedPinSlot = '4';
                                              safeSetState(() {});
                                            } else {
                                              if (_model.pinDigit4 == '') {
                                                _model.pinDigit4 = '2';
                                                safeSetState(() {});
                                              }
                                            }
                                          }
                                        }

                                        safeSetState(() {});
                                      },
                                      child: wrapWithModel(
                                        model: _model.keypadButtonModel2,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: KeypadButtonWidget(
                                          digit: '2',
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        if (_model.selectedPinSlot == '4') {
                                          if (!_model.pinRequestInFlight!) {
                                            if (!(_model.pinDigit1 == '')) {
                                              if (!(_model.pinDigit2 == '')) {
                                                if (!(_model.pinDigit3 == '')) {
                                                  _model.pinRequestInFlight =
                                                      true;
                                                  safeSetState(() {});
                                                  _model.guestPinEntry3 =
                                                      await actions
                                                          .enterStudio59GuestSessionSafely(
                                                    (String? credential) {
                                                      return credential ?? "";
                                                    }(functions.joinPinDigits(
                                                        _model.pinDigit1,
                                                        _model.pinDigit2,
                                                        _model.pinDigit3,
                                                        '3')),
                                                    false,
                                                  );
                                                  if (_model.guestPinEntry3
                                                          ?.success ==
                                                      true) {
                                                    FFAppState()
                                                            .guestSessionToken =
                                                        _model.guestPinEntry3!
                                                            .eventSessionToken;
                                                    safeSetState(() {});
                                                    FFAppState().guestEvent =
                                                        _model.guestPinEntry3!
                                                            .event;
                                                    safeSetState(() {});
                                                    FFAppState().guestCart = [];
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    if (Navigator.of(context)
                                                        .canPop()) {
                                                      context.pop();
                                                    }
                                                    context.pushNamed(
                                                        GuestGalleryOnlineWidget
                                                            .routeName);
                                                  } else {
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.selectedPinSlot =
                                                        '1';
                                                    safeSetState(() {});
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          _model.guestPinEntry3!
                                                              .message,
                                                          style: TextStyle(),
                                                        ),
                                                        duration: Duration(
                                                            milliseconds: 4000),
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            }
                                          }
                                        }
                                        if (_model.pinDigit1 == '') {
                                          _model.pinDigit1 = '3';
                                          safeSetState(() {});
                                          _model.selectedPinSlot = '2';
                                          safeSetState(() {});
                                        } else {
                                          if (_model.pinDigit2 == '') {
                                            _model.pinDigit2 = '3';
                                            safeSetState(() {});
                                            _model.selectedPinSlot = '3';
                                            safeSetState(() {});
                                          } else {
                                            if (_model.pinDigit3 == '') {
                                              _model.pinDigit3 = '3';
                                              safeSetState(() {});
                                              _model.selectedPinSlot = '4';
                                              safeSetState(() {});
                                            } else {
                                              if (_model.pinDigit4 == '') {
                                                _model.pinDigit4 = '3';
                                                safeSetState(() {});
                                              }
                                            }
                                          }
                                        }

                                        safeSetState(() {});
                                      },
                                      child: wrapWithModel(
                                        model: _model.keypadButtonModel3,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: KeypadButtonWidget(
                                          digit: '3',
                                        ),
                                      ),
                                    ),
                                  ].divide(SizedBox(width: 24.0)),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        if (_model.selectedPinSlot == '4') {
                                          if (!_model.pinRequestInFlight!) {
                                            if (!(_model.pinDigit1 == '')) {
                                              if (!(_model.pinDigit2 == '')) {
                                                if (!(_model.pinDigit3 == '')) {
                                                  _model.pinRequestInFlight =
                                                      true;
                                                  safeSetState(() {});
                                                  _model.guestPinEntry4 =
                                                      await actions
                                                          .enterStudio59GuestSessionSafely(
                                                    (String? credential) {
                                                      return credential ?? "";
                                                    }(functions.joinPinDigits(
                                                        _model.pinDigit1,
                                                        _model.pinDigit2,
                                                        _model.pinDigit3,
                                                        '4')),
                                                    false,
                                                  );
                                                  if (_model.guestPinEntry4
                                                          ?.success ==
                                                      true) {
                                                    FFAppState()
                                                            .guestSessionToken =
                                                        _model.guestPinEntry4!
                                                            .eventSessionToken;
                                                    safeSetState(() {});
                                                    FFAppState().guestEvent =
                                                        _model.guestPinEntry4!
                                                            .event;
                                                    safeSetState(() {});
                                                    FFAppState().guestCart = [];
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    if (Navigator.of(context)
                                                        .canPop()) {
                                                      context.pop();
                                                    }
                                                    context.pushNamed(
                                                        GuestGalleryOnlineWidget
                                                            .routeName);
                                                  } else {
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.selectedPinSlot =
                                                        '1';
                                                    safeSetState(() {});
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          _model.guestPinEntry4!
                                                              .message,
                                                          style: TextStyle(),
                                                        ),
                                                        duration: Duration(
                                                            milliseconds: 4000),
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            }
                                          }
                                        }
                                        if (_model.pinDigit1 == '') {
                                          _model.pinDigit1 = '4';
                                          safeSetState(() {});
                                          _model.selectedPinSlot = '2';
                                          safeSetState(() {});
                                        } else {
                                          if (_model.pinDigit2 == '') {
                                            _model.pinDigit2 = '4';
                                            safeSetState(() {});
                                            _model.selectedPinSlot = '3';
                                            safeSetState(() {});
                                          } else {
                                            if (_model.pinDigit3 == '') {
                                              _model.pinDigit3 = '4';
                                              safeSetState(() {});
                                              _model.selectedPinSlot = '4';
                                              safeSetState(() {});
                                            } else {
                                              if (_model.pinDigit4 == '') {
                                                _model.pinDigit4 = '4';
                                                safeSetState(() {});
                                              }
                                            }
                                          }
                                        }

                                        safeSetState(() {});
                                      },
                                      child: wrapWithModel(
                                        model: _model.keypadButtonModel4,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: KeypadButtonWidget(
                                          digit: '4',
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        if (_model.selectedPinSlot == '4') {
                                          if (!_model.pinRequestInFlight!) {
                                            if (!(_model.pinDigit1 == '')) {
                                              if (!(_model.pinDigit2 == '')) {
                                                if (!(_model.pinDigit3 == '')) {
                                                  _model.pinRequestInFlight =
                                                      true;
                                                  safeSetState(() {});
                                                  _model.guestPinEntry5 =
                                                      await actions
                                                          .enterStudio59GuestSessionSafely(
                                                    (String? credential) {
                                                      return credential ?? "";
                                                    }(functions.joinPinDigits(
                                                        _model.pinDigit1,
                                                        _model.pinDigit2,
                                                        _model.pinDigit3,
                                                        '5')),
                                                    false,
                                                  );
                                                  if (_model.guestPinEntry5
                                                          ?.success ==
                                                      true) {
                                                    FFAppState()
                                                            .guestSessionToken =
                                                        _model.guestPinEntry5!
                                                            .eventSessionToken;
                                                    safeSetState(() {});
                                                    FFAppState().guestEvent =
                                                        _model.guestPinEntry5!
                                                            .event;
                                                    safeSetState(() {});
                                                    FFAppState().guestCart = [];
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    if (Navigator.of(context)
                                                        .canPop()) {
                                                      context.pop();
                                                    }
                                                    context.pushNamed(
                                                        GuestGalleryOnlineWidget
                                                            .routeName);
                                                  } else {
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.selectedPinSlot =
                                                        '1';
                                                    safeSetState(() {});
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          _model.guestPinEntry5!
                                                              .message,
                                                          style: TextStyle(),
                                                        ),
                                                        duration: Duration(
                                                            milliseconds: 4000),
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            }
                                          }
                                        }
                                        if (_model.pinDigit1 == '') {
                                          _model.pinDigit1 = '5';
                                          safeSetState(() {});
                                          _model.selectedPinSlot = '2';
                                          safeSetState(() {});
                                        } else {
                                          if (_model.pinDigit2 == '') {
                                            _model.pinDigit2 = '5';
                                            safeSetState(() {});
                                            _model.selectedPinSlot = '3';
                                            safeSetState(() {});
                                          } else {
                                            if (_model.pinDigit3 == '') {
                                              _model.pinDigit3 = '5';
                                              safeSetState(() {});
                                              _model.selectedPinSlot = '4';
                                              safeSetState(() {});
                                            } else {
                                              if (_model.pinDigit4 == '') {
                                                _model.pinDigit4 = '5';
                                                safeSetState(() {});
                                              }
                                            }
                                          }
                                        }

                                        safeSetState(() {});
                                      },
                                      child: wrapWithModel(
                                        model: _model.keypadButtonModel5,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: KeypadButtonWidget(
                                          digit: '5',
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        if (_model.selectedPinSlot == '4') {
                                          if (!_model.pinRequestInFlight!) {
                                            if (!(_model.pinDigit1 == '')) {
                                              if (!(_model.pinDigit2 == '')) {
                                                if (!(_model.pinDigit3 == '')) {
                                                  _model.pinRequestInFlight =
                                                      true;
                                                  safeSetState(() {});
                                                  _model.guestPinEntry6 =
                                                      await actions
                                                          .enterStudio59GuestSessionSafely(
                                                    (String? credential) {
                                                      return credential ?? "";
                                                    }(functions.joinPinDigits(
                                                        _model.pinDigit1,
                                                        _model.pinDigit2,
                                                        _model.pinDigit3,
                                                        '6')),
                                                    false,
                                                  );
                                                  if (_model.guestPinEntry6
                                                          ?.success ==
                                                      true) {
                                                    FFAppState()
                                                            .guestSessionToken =
                                                        _model.guestPinEntry6!
                                                            .eventSessionToken;
                                                    safeSetState(() {});
                                                    FFAppState().guestEvent =
                                                        _model.guestPinEntry6!
                                                            .event;
                                                    safeSetState(() {});
                                                    FFAppState().guestCart = [];
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    if (Navigator.of(context)
                                                        .canPop()) {
                                                      context.pop();
                                                    }
                                                    context.pushNamed(
                                                        GuestGalleryOnlineWidget
                                                            .routeName);
                                                  } else {
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.selectedPinSlot =
                                                        '1';
                                                    safeSetState(() {});
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          _model.guestPinEntry6!
                                                              .message,
                                                          style: TextStyle(),
                                                        ),
                                                        duration: Duration(
                                                            milliseconds: 4000),
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            }
                                          }
                                        }
                                        if (_model.pinDigit1 == '') {
                                          _model.pinDigit1 = '6';
                                          safeSetState(() {});
                                          _model.selectedPinSlot = '2';
                                          safeSetState(() {});
                                        } else {
                                          if (_model.pinDigit2 == '') {
                                            _model.pinDigit2 = '6';
                                            safeSetState(() {});
                                            _model.selectedPinSlot = '3';
                                            safeSetState(() {});
                                          } else {
                                            if (_model.pinDigit3 == '') {
                                              _model.pinDigit3 = '6';
                                              safeSetState(() {});
                                              _model.selectedPinSlot = '4';
                                              safeSetState(() {});
                                            } else {
                                              if (_model.pinDigit4 == '') {
                                                _model.pinDigit4 = '6';
                                                safeSetState(() {});
                                              }
                                            }
                                          }
                                        }

                                        safeSetState(() {});
                                      },
                                      child: wrapWithModel(
                                        model: _model.keypadButtonModel6,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: KeypadButtonWidget(
                                          digit: '6',
                                        ),
                                      ),
                                    ),
                                  ].divide(SizedBox(width: 24.0)),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        if (_model.selectedPinSlot == '4') {
                                          if (!_model.pinRequestInFlight!) {
                                            if (!(_model.pinDigit1 == '')) {
                                              if (!(_model.pinDigit2 == '')) {
                                                if (!(_model.pinDigit3 == '')) {
                                                  _model.pinRequestInFlight =
                                                      true;
                                                  safeSetState(() {});
                                                  _model.guestPinEntry7 =
                                                      await actions
                                                          .enterStudio59GuestSessionSafely(
                                                    (String? credential) {
                                                      return credential ?? "";
                                                    }(functions.joinPinDigits(
                                                        _model.pinDigit1,
                                                        _model.pinDigit2,
                                                        _model.pinDigit3,
                                                        '7')),
                                                    false,
                                                  );
                                                  if (_model.guestPinEntry7
                                                          ?.success ==
                                                      true) {
                                                    FFAppState()
                                                            .guestSessionToken =
                                                        _model.guestPinEntry7!
                                                            .eventSessionToken;
                                                    safeSetState(() {});
                                                    FFAppState().guestEvent =
                                                        _model.guestPinEntry7!
                                                            .event;
                                                    safeSetState(() {});
                                                    FFAppState().guestCart = [];
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    if (Navigator.of(context)
                                                        .canPop()) {
                                                      context.pop();
                                                    }
                                                    context.pushNamed(
                                                        GuestGalleryOnlineWidget
                                                            .routeName);
                                                  } else {
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.selectedPinSlot =
                                                        '1';
                                                    safeSetState(() {});
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          _model.guestPinEntry7!
                                                              .message,
                                                          style: TextStyle(),
                                                        ),
                                                        duration: Duration(
                                                            milliseconds: 4000),
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            }
                                          }
                                        }
                                        if (_model.pinDigit1 == '') {
                                          _model.pinDigit1 = '7';
                                          safeSetState(() {});
                                          _model.selectedPinSlot = '2';
                                          safeSetState(() {});
                                        } else {
                                          if (_model.pinDigit2 == '') {
                                            _model.pinDigit2 = '7';
                                            safeSetState(() {});
                                            _model.selectedPinSlot = '3';
                                            safeSetState(() {});
                                          } else {
                                            if (_model.pinDigit3 == '') {
                                              _model.pinDigit3 = '7';
                                              safeSetState(() {});
                                              _model.selectedPinSlot = '4';
                                              safeSetState(() {});
                                            } else {
                                              if (_model.pinDigit4 == '') {
                                                _model.pinDigit4 = '7';
                                                safeSetState(() {});
                                              }
                                            }
                                          }
                                        }

                                        safeSetState(() {});
                                      },
                                      child: wrapWithModel(
                                        model: _model.keypadButtonModel7,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: KeypadButtonWidget(
                                          digit: '7',
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        if (_model.selectedPinSlot == '4') {
                                          if (!_model.pinRequestInFlight!) {
                                            if (!(_model.pinDigit1 == '')) {
                                              if (!(_model.pinDigit2 == '')) {
                                                if (!(_model.pinDigit3 == '')) {
                                                  _model.pinRequestInFlight =
                                                      true;
                                                  safeSetState(() {});
                                                  _model.guestPinEntry8 =
                                                      await actions
                                                          .enterStudio59GuestSessionSafely(
                                                    (String? credential) {
                                                      return credential ?? "";
                                                    }(functions.joinPinDigits(
                                                        _model.pinDigit1,
                                                        _model.pinDigit2,
                                                        _model.pinDigit3,
                                                        '8')),
                                                    false,
                                                  );
                                                  if (_model.guestPinEntry8
                                                          ?.success ==
                                                      true) {
                                                    FFAppState()
                                                            .guestSessionToken =
                                                        _model.guestPinEntry8!
                                                            .eventSessionToken;
                                                    safeSetState(() {});
                                                    FFAppState().guestEvent =
                                                        _model.guestPinEntry8!
                                                            .event;
                                                    safeSetState(() {});
                                                    FFAppState().guestCart = [];
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    if (Navigator.of(context)
                                                        .canPop()) {
                                                      context.pop();
                                                    }
                                                    context.pushNamed(
                                                        GuestGalleryOnlineWidget
                                                            .routeName);
                                                  } else {
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.selectedPinSlot =
                                                        '1';
                                                    safeSetState(() {});
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          _model.guestPinEntry8!
                                                              .message,
                                                          style: TextStyle(),
                                                        ),
                                                        duration: Duration(
                                                            milliseconds: 4000),
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            }
                                          }
                                        }
                                        if (_model.pinDigit1 == '') {
                                          _model.pinDigit1 = '8';
                                          safeSetState(() {});
                                          _model.selectedPinSlot = '2';
                                          safeSetState(() {});
                                        } else {
                                          if (_model.pinDigit2 == '') {
                                            _model.pinDigit2 = '8';
                                            safeSetState(() {});
                                            _model.selectedPinSlot = '3';
                                            safeSetState(() {});
                                          } else {
                                            if (_model.pinDigit3 == '') {
                                              _model.pinDigit3 = '8';
                                              safeSetState(() {});
                                              _model.selectedPinSlot = '4';
                                              safeSetState(() {});
                                            } else {
                                              if (_model.pinDigit4 == '') {
                                                _model.pinDigit4 = '8';
                                                safeSetState(() {});
                                              }
                                            }
                                          }
                                        }

                                        safeSetState(() {});
                                      },
                                      child: wrapWithModel(
                                        model: _model.keypadButtonModel8,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: KeypadButtonWidget(
                                          digit: '8',
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        if (_model.selectedPinSlot == '4') {
                                          if (!_model.pinRequestInFlight!) {
                                            if (!(_model.pinDigit1 == '')) {
                                              if (!(_model.pinDigit2 == '')) {
                                                if (!(_model.pinDigit3 == '')) {
                                                  _model.pinRequestInFlight =
                                                      true;
                                                  safeSetState(() {});
                                                  _model.guestPinEntry9 =
                                                      await actions
                                                          .enterStudio59GuestSessionSafely(
                                                    (String? credential) {
                                                      return credential ?? "";
                                                    }(functions.joinPinDigits(
                                                        _model.pinDigit1,
                                                        _model.pinDigit2,
                                                        _model.pinDigit3,
                                                        '9')),
                                                    false,
                                                  );
                                                  if (_model.guestPinEntry9
                                                          ?.success ==
                                                      true) {
                                                    FFAppState()
                                                            .guestSessionToken =
                                                        _model.guestPinEntry9!
                                                            .eventSessionToken;
                                                    safeSetState(() {});
                                                    FFAppState().guestEvent =
                                                        _model.guestPinEntry9!
                                                            .event;
                                                    safeSetState(() {});
                                                    FFAppState().guestCart = [];
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    if (Navigator.of(context)
                                                        .canPop()) {
                                                      context.pop();
                                                    }
                                                    context.pushNamed(
                                                        GuestGalleryOnlineWidget
                                                            .routeName);
                                                  } else {
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.selectedPinSlot =
                                                        '1';
                                                    safeSetState(() {});
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          _model.guestPinEntry9!
                                                              .message,
                                                          style: TextStyle(),
                                                        ),
                                                        duration: Duration(
                                                            milliseconds: 4000),
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            }
                                          }
                                        }
                                        if (_model.pinDigit1 == '') {
                                          _model.pinDigit1 = '9';
                                          safeSetState(() {});
                                          _model.selectedPinSlot = '2';
                                          safeSetState(() {});
                                        } else {
                                          if (_model.pinDigit2 == '') {
                                            _model.pinDigit2 = '9';
                                            safeSetState(() {});
                                            _model.selectedPinSlot = '3';
                                            safeSetState(() {});
                                          } else {
                                            if (_model.pinDigit3 == '') {
                                              _model.pinDigit3 = '9';
                                              safeSetState(() {});
                                              _model.selectedPinSlot = '4';
                                              safeSetState(() {});
                                            } else {
                                              if (_model.pinDigit4 == '') {
                                                _model.pinDigit4 = '9';
                                                safeSetState(() {});
                                              }
                                            }
                                          }
                                        }

                                        safeSetState(() {});
                                      },
                                      child: wrapWithModel(
                                        model: _model.keypadButtonModel9,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: KeypadButtonWidget(
                                          digit: '9',
                                        ),
                                      ),
                                    ),
                                  ].divide(SizedBox(width: 24.0)),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 80.0,
                                      height: 80.0,
                                    ),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        if (_model.selectedPinSlot == '4') {
                                          if (!_model.pinRequestInFlight!) {
                                            if (!(_model.pinDigit1 == '')) {
                                              if (!(_model.pinDigit2 == '')) {
                                                if (!(_model.pinDigit3 == '')) {
                                                  _model.pinRequestInFlight =
                                                      true;
                                                  safeSetState(() {});
                                                  _model.guestPinEntry0 =
                                                      await actions
                                                          .enterStudio59GuestSessionSafely(
                                                    (String? credential) {
                                                      return credential ?? "";
                                                    }(functions.joinPinDigits(
                                                        _model.pinDigit1,
                                                        _model.pinDigit2,
                                                        _model.pinDigit3,
                                                        '0')),
                                                    false,
                                                  );
                                                  if (_model.guestPinEntry0
                                                          ?.success ==
                                                      true) {
                                                    FFAppState()
                                                            .guestSessionToken =
                                                        _model.guestPinEntry0!
                                                            .eventSessionToken;
                                                    safeSetState(() {});
                                                    FFAppState().guestEvent =
                                                        _model.guestPinEntry0!
                                                            .event;
                                                    safeSetState(() {});
                                                    FFAppState().guestCart = [];
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    if (Navigator.of(context)
                                                        .canPop()) {
                                                      context.pop();
                                                    }
                                                    context.pushNamed(
                                                        GuestGalleryOnlineWidget
                                                            .routeName);
                                                  } else {
                                                    _model.pinRequestInFlight =
                                                        false;
                                                    safeSetState(() {});
                                                    _model.pinDigit1 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit2 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit3 = '';
                                                    safeSetState(() {});
                                                    _model.pinDigit4 = '';
                                                    safeSetState(() {});
                                                    _model.selectedPinSlot =
                                                        '1';
                                                    safeSetState(() {});
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          _model.guestPinEntry0!
                                                              .message,
                                                          style: TextStyle(),
                                                        ),
                                                        duration: Duration(
                                                            milliseconds: 4000),
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            }
                                          }
                                        }
                                        if (_model.pinDigit1 == '') {
                                          _model.pinDigit1 = '0';
                                          safeSetState(() {});
                                          _model.selectedPinSlot = '2';
                                          safeSetState(() {});
                                        } else {
                                          if (_model.pinDigit2 == '') {
                                            _model.pinDigit2 = '0';
                                            safeSetState(() {});
                                            _model.selectedPinSlot = '3';
                                            safeSetState(() {});
                                          } else {
                                            if (_model.pinDigit3 == '') {
                                              _model.pinDigit3 = '0';
                                              safeSetState(() {});
                                              _model.selectedPinSlot = '4';
                                              safeSetState(() {});
                                            } else {
                                              if (_model.pinDigit4 == '') {
                                                _model.pinDigit4 = '0';
                                                safeSetState(() {});
                                              }
                                            }
                                          }
                                        }

                                        safeSetState(() {});
                                      },
                                      child: wrapWithModel(
                                        model: _model.keypadButtonModel10,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: KeypadButtonWidget(
                                          digit: '0',
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        if (!(_model.pinDigit4 == '')) {
                                          _model.pinDigit4 = '';
                                          safeSetState(() {});
                                        } else {
                                          if (!(_model.pinDigit3 == '')) {
                                            _model.pinDigit3 = '';
                                            safeSetState(() {});
                                            _model.selectedPinSlot = '3';
                                            safeSetState(() {});
                                          } else {
                                            if (!(_model.pinDigit2 == '')) {
                                              _model.pinDigit2 = '';
                                              safeSetState(() {});
                                              _model.selectedPinSlot = '2';
                                              safeSetState(() {});
                                            } else {
                                              if (!(_model.pinDigit1 == '')) {
                                                _model.pinDigit1 = '';
                                                safeSetState(() {});
                                                _model.selectedPinSlot = '1';
                                                safeSetState(() {});
                                              }
                                            }
                                          }
                                        }
                                      },
                                      child: Container(
                                        width: 80.0,
                                        height: 80.0,
                                        alignment:
                                            AlignmentDirectional(0.0, 0.0),
                                        child: Icon(
                                          Icons.backspace_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          size: 28.0,
                                        ),
                                      ),
                                    ),
                                  ].divide(SizedBox(width: 24.0)),
                                ),
                              ].divide(SizedBox(height: 16.0)),
                            ),
                        ].divide(SizedBox(height: 32.0)),
                      ),
                      Container(
                        height: 32.0,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Studio 59 - Fotografia de Eventos',
                            style: FlutterFlowTheme.of(context)
                                .labelMedium
                                .override(
                                  font: GoogleFonts.montserrat(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontStyle,
                                  ),
                                  color: Colors.white,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontStyle,
                                  lineHeight: 1.3,
                                ),
                          ),
                          Text(
                            'Casamentos, Batizados e Aniversários',
                            style: FlutterFlowTheme.of(context)
                                .labelSmall
                                .override(
                                  font: GoogleFonts.montserrat(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontStyle,
                                  ),
                                  color: Colors.white,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontStyle,
                                  lineHeight: 1.2,
                                ),
                          ),
                        ].divide(SizedBox(height: 4.0)),
                      ),
                    ].divide(SizedBox(height: 32.0)),
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
